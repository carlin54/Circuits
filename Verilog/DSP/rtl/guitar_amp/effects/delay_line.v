// Digital Delay Line (Echo)
// RAM-based circular buffer with feedback, wet/dry mix, and optional modulation

module delay_line #(
    parameter DATA_WIDTH         = 24,
    parameter MAX_DELAY_SAMPLES  = 96000,  // 2 seconds at 48kHz
    parameter NUM_TAPS           = 1,
    parameter MODULATION         = 0,
    parameter MOD_DEPTH_BITS     = 8,
    parameter INTERPOLATION      = "LINEAR"  // "NONE", "LINEAR"
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
    input  wire [$clog2(MAX_DELAY_SAMPLES)-1:0] delay_time,  // Delay in samples
    input  wire [7:0]                    feedback,     // 0-255 (0.0 to ~1.0)
    input  wire [7:0]                    mix           // 0=dry, 255=wet
);

    localparam ADDR_WIDTH = $clog2(MAX_DELAY_SAMPLES);

    // Delay buffer (block RAM)
    reg signed [DATA_WIDTH-1:0] delay_buf [0:MAX_DELAY_SAMPLES-1];

    // Write pointer (circular)
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // Read pointer
    wire [ADDR_WIDTH-1:0] rd_ptr;
    assign rd_ptr = wr_ptr - delay_time;

    // Feedback sample
    reg signed [DATA_WIDTH-1:0] fb_sample;

    // Mix calculation
    localparam MIX_WIDTH = DATA_WIDTH + 8;

    // Working registers
    reg signed [DATA_WIDTH+8:0] fb_scaled;
    reg signed [DATA_WIDTH-1:0] write_val;
    reg signed [MIX_WIDTH-1:0] wet_scaled, dry_scaled;

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
            fb_sample <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                // Read delayed sample
                fb_sample <= delay_buf[rd_ptr];

                // Write input + feedback to buffer
                fb_scaled = fb_sample * $signed({1'b0, feedback});
                write_val = s_axis_tdata + (fb_scaled >>> 8);

                // Saturate
                if (write_val > ((1 << (DATA_WIDTH-1)) - 1))
                    delay_buf[wr_ptr] <= (1 << (DATA_WIDTH-1)) - 1;
                else if (write_val < -(1 << (DATA_WIDTH-1)))
                    delay_buf[wr_ptr] <= -(1 << (DATA_WIDTH-1));
                else
                    delay_buf[wr_ptr] <= write_val;

                wr_ptr <= wr_ptr + 1;

                // Wet/dry mix
                wet_scaled = fb_sample * $signed({1'b0, mix});
                dry_scaled = s_axis_tdata * $signed({1'b0, (8'd255 - mix)});

                m_axis_tdata <= (wet_scaled + dry_scaled) >>> 8;
                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
