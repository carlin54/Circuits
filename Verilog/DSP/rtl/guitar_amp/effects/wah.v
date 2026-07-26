// Wah Pedal — Sweepable resonant bandpass filter
// Controlled by expression pedal position or auto-wah (envelope-following)

module wah #(
    parameter DATA_WIDTH     = 24,
    parameter COEFF_WIDTH    = 18,
    parameter INTERNAL_WIDTH = 40,
    parameter FRAC_BITS      = 16,
    parameter MODE           = "MANUAL"  // "MANUAL" or "AUTO"
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output
    output reg  signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,
    output reg                           m_axis_tlast,

    // Controls
    input  wire [7:0]                    pedal_pos,    // 0=toe up (low freq), 255=toe down (high freq)
    input  wire [7:0]                    resonance,    // Q factor (0=mild, 255=sharp peak)
    input  wire [7:0]                    range_lo,     // Low frequency bound (mapped ~300-500Hz)
    input  wire [7:0]                    range_hi,     // High frequency bound (mapped ~1500-3000Hz)
    input  wire [7:0]                    sensitivity   // Auto-wah envelope sensitivity
);

    localparam signed [INTERNAL_WIDTH-1:0] ONE = (1 <<< FRAC_BITS);

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // State-variable filter (SVF) implementation
    // Provides simultaneous LP, BP, HP outputs
    // We output the bandpass for wah effect

    // Frequency control: map pedal position to filter cutoff
    // f_norm = 2*sin(pi*fc/fs) approximated as a linear sweep for simplicity
    // pedal_pos interpolates between range_lo and range_hi
    wire [15:0] freq_range = (range_hi - range_lo);
    wire [15:0] freq_scaled = range_lo + ((freq_range * pedal_pos) >> 8);

    // Auto-wah: envelope follower overrides pedal position
    reg [15:0] envelope;
    reg [15:0] freq_ctrl;

    always @(posedge clk) begin
        if (rst) begin
            envelope <= 0;
        end else if (s_axis_tvalid && s_axis_tready) begin
            // Peak envelope follower
            wire [DATA_WIDTH-1:0] abs_in = s_axis_tdata[DATA_WIDTH-1] ?
                                           -s_axis_tdata : s_axis_tdata;
            wire [15:0] scaled_abs = abs_in[DATA_WIDTH-1:DATA_WIDTH-16];

            if (scaled_abs > envelope)
                envelope <= envelope + ((scaled_abs - envelope) >> 2);  // Fast attack
            else
                envelope <= envelope - (envelope >> 6);  // Slow release
        end
    end

    // Select frequency source
    always @(*) begin
        if (MODE == "AUTO") begin
            // Map envelope to frequency range using sensitivity
            freq_ctrl = range_lo + (((envelope * sensitivity) >> 8) > freq_range ?
                        freq_range : (envelope * sensitivity) >> 8);
        end else begin
            freq_ctrl = freq_scaled;
        end
    end

    // SVF coefficients
    // f_coeff determines cutoff (higher = higher frequency)
    // q_coeff determines resonance (lower = more resonant)
    wire signed [INTERNAL_WIDTH-1:0] f_coeff = {{(INTERNAL_WIDTH-16){1'b0}}, freq_ctrl};
    wire signed [INTERNAL_WIDTH-1:0] q_coeff = ONE - ({{(INTERNAL_WIDTH-8){1'b0}}, resonance} <<< (FRAC_BITS - 9));

    // State variables
    reg signed [INTERNAL_WIDTH-1:0] bp_state;  // Bandpass
    reg signed [INTERNAL_WIDTH-1:0] lp_state;  // Lowpass

    // SVF computation
    wire signed [INTERNAL_WIDTH-1:0] input_ext = {{(INTERNAL_WIDTH-DATA_WIDTH){s_axis_tdata[DATA_WIDTH-1]}}, s_axis_tdata} <<< (FRAC_BITS - (DATA_WIDTH - 1));

    wire signed [INTERNAL_WIDTH-1:0] hp = input_ext - lp_state - ((bp_state * q_coeff) >>> FRAC_BITS);
    wire signed [INTERNAL_WIDTH-1:0] bp_new = bp_state + ((hp * f_coeff) >>> FRAC_BITS);
    wire signed [INTERNAL_WIDTH-1:0] lp_new = lp_state + ((bp_state * f_coeff) >>> FRAC_BITS);

    always @(posedge clk) begin
        if (rst) begin
            bp_state <= 0;
            lp_state <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                bp_state <= bp_new;
                lp_state <= lp_new;

                // Output bandpass (the wah sound)
                // Scale back to DATA_WIDTH with saturation
                reg signed [INTERNAL_WIDTH-1:0] out_scaled;
                out_scaled = bp_new >>> (FRAC_BITS - (DATA_WIDTH - 1));

                if (out_scaled > ((1 <<< (DATA_WIDTH-1)) - 1))
                    m_axis_tdata <= (1 <<< (DATA_WIDTH-1)) - 1;
                else if (out_scaled < -(1 <<< (DATA_WIDTH-1)))
                    m_axis_tdata <= -(1 <<< (DATA_WIDTH-1));
                else
                    m_axis_tdata <= out_scaled[DATA_WIDTH-1:0];

                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
