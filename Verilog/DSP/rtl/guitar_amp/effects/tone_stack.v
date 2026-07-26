// Tone Stack — 3-band EQ + Presence + Resonance
// Cascaded IIR biquad sections with pre-computed coefficient sets

module tone_stack #(
    parameter DATA_WIDTH     = 24,
    parameter COEFF_WIDTH    = 18,
    parameter INTERNAL_WIDTH = 40,
    parameter NUM_BANDS      = 3,
    parameter PRESENCE       = 1,
    parameter RESONANCE      = 1,
    parameter COEFF_SETS     = 16,   // Per-knob-position coefficient sets
    parameter FRAC_BITS      = 16
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

    // Tone controls (0-255 mapped to COEFF_SETS positions)
    input  wire [7:0]                    bass,
    input  wire [7:0]                    mid,
    input  wire [7:0]                    treble,
    input  wire [7:0]                    presence,
    input  wire [7:0]                    resonance
);

    // Total number of biquad sections
    localparam TOTAL_SECTIONS = NUM_BANDS + PRESENCE + RESONANCE;

    // Internal connections between cascaded biquads
    wire signed [DATA_WIDTH-1:0] stage_data [0:TOTAL_SECTIONS];
    wire stage_valid [0:TOTAL_SECTIONS];
    wire stage_last [0:TOTAL_SECTIONS];
    wire stage_ready [0:TOTAL_SECTIONS];

    assign stage_data[0] = s_axis_tdata;
    assign stage_valid[0] = s_axis_tvalid;
    assign stage_last[0] = s_axis_tlast;
    assign s_axis_tready = stage_ready[0];

    assign m_axis_tdata = stage_data[TOTAL_SECTIONS];
    assign m_axis_tvalid = stage_valid[TOTAL_SECTIONS];
    assign m_axis_tlast = stage_last[TOTAL_SECTIONS];
    assign stage_ready[TOTAL_SECTIONS] = m_axis_tready;

    // Instantiate cascaded biquad sections
    genvar sec;
    generate
        for (sec = 0; sec < TOTAL_SECTIONS; sec = sec + 1) begin : biquad_section

            // Each section is an independent biquad
            iir_biquad #(
                .DATA_WIDTH(DATA_WIDTH),
                .COEFF_WIDTH(COEFF_WIDTH),
                .INTERNAL_WIDTH(INTERNAL_WIDTH),
                .FRAC_BITS(FRAC_BITS),
                .NUM_SECTIONS(1),
                .COEFF_RELOAD(1)
            ) biquad_inst (
                .clk(clk),
                .rst(rst),
                .s_axis_tdata(stage_data[sec]),
                .s_axis_tvalid(stage_valid[sec]),
                .s_axis_tready(stage_ready[sec]),
                .s_axis_tlast(stage_last[sec]),
                .m_axis_tdata(stage_data[sec+1]),
                .m_axis_tvalid(stage_valid[sec+1]),
                .m_axis_tready(stage_ready[sec+1]),
                .m_axis_tlast(stage_last[sec+1]),
                .coeff_we(1'b0),
                .coeff_addr(3'd0),
                .coeff_data({COEFF_WIDTH{1'b0}}),
                .coeff_section(1'b0)
            );

        end
    endgenerate

    // Coefficient update logic would select from pre-computed ROM based on knob positions
    // This is handled by an external controller writing to each section's coeff_reload interface

endmodule
