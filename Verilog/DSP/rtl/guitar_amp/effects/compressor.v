// Dynamic Range Compressor
// Envelope detection -> Gain computation -> Gain smoothing -> Apply gain

module compressor #(
    parameter DATA_WIDTH    = 24,
    parameter ENV_WIDTH     = 32,
    parameter ATTACK_WIDTH  = 16,
    parameter RELEASE_WIDTH = 16,
    parameter DETECTION     = "PEAK",   // "PEAK", "RMS"
    parameter KNEE          = "HARD",   // "HARD", "SOFT"
    parameter KNEE_WIDTH    = 6,
    parameter LOOKAHEAD     = 0,
    parameter SIDECHAIN_EXT = 0
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

    // Control
    input  wire [7:0]                    threshold,  // 0-255 -> dB scale
    input  wire [7:0]                    ratio,      // Compression ratio (2=2:1, 4=4:1, etc)
    input  wire [ATTACK_WIDTH-1:0]       attack,     // Attack coefficient
    input  wire [RELEASE_WIDTH-1:0]      release_coeff, // Release coefficient
    input  wire [7:0]                    makeup      // Makeup gain
);

    // Envelope follower
    reg [ENV_WIDTH-1:0] envelope;
    wire [DATA_WIDTH-1:0] abs_input;

    // Absolute value of input
    assign abs_input = s_axis_tdata[DATA_WIDTH-1] ? -s_axis_tdata : s_axis_tdata;

    // Gain reduction (in linear domain, 8-bit fractional)
    reg [7:0] gain_reduction;

    // Working registers
    reg [ENV_WIDTH-1:0] input_level;
    reg [ENV_WIDTH-1:0] diff;
    reg [ENV_WIDTH-1:0] thresh_level;
    reg [ENV_WIDTH-1:0] over;
    reg [7:0] reduction;
    reg signed [DATA_WIDTH+7:0] compressed;
    reg signed [DATA_WIDTH+7:0] made_up;
    reg signed [DATA_WIDTH-1:0] final_out;

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    always @(posedge clk) begin
        if (rst) begin
            envelope <= 0;
            gain_reduction <= 8'd255;  // Unity gain
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                // === Envelope Detection (Peak) ===
                input_level = {{(ENV_WIDTH-DATA_WIDTH){1'b0}}, abs_input};

                if (input_level > envelope) begin
                    // Attack: fast rise
                    diff = input_level - envelope;
                    envelope <= envelope + (diff >> (16 - attack[3:0]));
                end else begin
                    // Release: slow fall
                    diff = envelope - input_level;
                    envelope <= envelope - (diff >> (16 - release_coeff[3:0]));
                end

                // === Gain Computation ===
                // Simple threshold comparison (linear domain approximation)
                thresh_level = {{(ENV_WIDTH-8){1'b0}}, threshold} << (DATA_WIDTH - 8);

                if (envelope > thresh_level && ratio > 1) begin
                    // Amount over threshold
                    over = envelope - thresh_level;
                    // Reduce gain: gain = threshold + (over / ratio)
                    // Simplified: gain_reduction proportional to overshoot
                    reduction = (over[DATA_WIDTH-1:DATA_WIDTH-8] > 8'd0) ?
                                8'd255 - (over[DATA_WIDTH-1:DATA_WIDTH-8] / ratio) :
                                8'd255;
                    gain_reduction <= reduction;
                end else begin
                    gain_reduction <= 8'd255;  // No compression
                end

                // === Apply Gain ===
                compressed = s_axis_tdata * $signed({1'b0, gain_reduction});

                // Apply makeup gain
                made_up = (compressed >>> 8) * $signed({1'b0, makeup});

                // Saturate output
                final_out = made_up >>> 7;  // Makeup is 0-255, center at 128=unity

                m_axis_tdata <= final_out;
                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
