// Parametric EQ — Multi-band fully parametric equalizer
// Each band has adjustable frequency, gain, and Q (bandwidth)
// Implemented as cascaded IIR biquad sections with runtime coefficient reload

module eq_parametric #(
    parameter DATA_WIDTH     = 24,
    parameter COEFF_WIDTH    = 18,
    parameter INTERNAL_WIDTH = 40,
    parameter FRAC_BITS      = 16,
    parameter NUM_BANDS      = 4   // Number of parametric EQ bands
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output
    output wire signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                          m_axis_tvalid,
    input  wire                          m_axis_tready,
    output wire                          m_axis_tlast,

    // Per-band controls (each band: freq, gain, Q)
    input  wire [8*NUM_BANDS-1:0]        band_freq,     // Packed: 8 bits per band
    input  wire [8*NUM_BANDS-1:0]        band_gain,     // Packed: 8 bits per band (128=unity)
    input  wire [8*NUM_BANDS-1:0]        band_q,        // Packed: 8 bits per band

    // Coefficient write interface (from external controller that computes biquad coefficients)
    input  wire                          coeff_we,
    input  wire [$clog2(NUM_BANDS)-1:0]  coeff_band,
    input  wire [2:0]                    coeff_addr,    // 0=b0, 1=b1, 2=b2, 3=a1, 4=a2
    input  wire signed [COEFF_WIDTH-1:0] coeff_data
);

    // Inter-stage signals
    wire signed [DATA_WIDTH-1:0] stage_data  [0:NUM_BANDS];
    wire                         stage_valid [0:NUM_BANDS];
    wire                         stage_ready [0:NUM_BANDS];
    wire                         stage_last  [0:NUM_BANDS];

    // Connect input to first stage
    assign stage_data[0]  = s_axis_tdata;
    assign stage_valid[0] = s_axis_tvalid;
    assign stage_last[0]  = s_axis_tlast;
    assign s_axis_tready  = stage_ready[0];

    // Connect last stage to output
    assign m_axis_tdata  = stage_data[NUM_BANDS];
    assign m_axis_tvalid = stage_valid[NUM_BANDS];
    assign m_axis_tlast  = stage_last[NUM_BANDS];
    assign stage_ready[NUM_BANDS] = m_axis_tready;

    // Generate cascaded biquad sections
    genvar i;
    generate
        for (i = 0; i < NUM_BANDS; i = i + 1) begin : eq_band
            wire band_coeff_we = coeff_we && (coeff_band == i);

            iir_biquad #(
                .DATA_WIDTH(DATA_WIDTH),
                .COEFF_WIDTH(COEFF_WIDTH),
                .INTERNAL_WIDTH(INTERNAL_WIDTH),
                .FRAC_BITS(FRAC_BITS),
                .NUM_SECTIONS(1),
                .COEFF_RELOAD(1)
            ) u_biquad (
                .clk(clk), .rst(rst),
                .s_axis_tdata(stage_data[i]),
                .s_axis_tvalid(stage_valid[i]),
                .s_axis_tready(stage_ready[i]),
                .s_axis_tlast(stage_last[i]),
                .m_axis_tdata(stage_data[i+1]),
                .m_axis_tvalid(stage_valid[i+1]),
                .m_axis_tready(stage_ready[i+1]),
                .m_axis_tlast(stage_last[i+1]),
                .coeff_we(band_coeff_we),
                .coeff_addr(coeff_addr),
                .coeff_data(coeff_data),
                .coeff_section(1'b0)
            );
        end
    endgenerate

endmodule
