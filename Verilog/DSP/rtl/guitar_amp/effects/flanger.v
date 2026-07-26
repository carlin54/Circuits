// Flanger Effect — Short modulated delay with feedback
// Similar to chorus but shorter delays and feedback creates comb-filter sweep

module flanger #(
    parameter DATA_WIDTH     = 24,
    parameter BASE_DELAY     = 100,   // ~2ms
    parameter MAX_DEPTH      = 200,   // ~4ms max sweep
    parameter LFO_WIDTH      = 32,
    parameter FEEDBACK_WIDTH = 16,
    parameter NEGATIVE_FB    = 1      // Allow negative feedback
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
    input  wire [7:0]                    rate,      // LFO rate
    input  wire [7:0]                    depth,     // Modulation depth
    input  wire signed [7:0]             feedback,  // Feedback amount (signed for negative FB)
    input  wire [7:0]                    mix        // Wet/dry
);

    localparam BUF_SIZE = BASE_DELAY + MAX_DEPTH + 1;
    localparam ADDR_WIDTH = $clog2(BUF_SIZE);

    // Delay buffer
    reg signed [DATA_WIDTH-1:0] delay_buf [0:BUF_SIZE-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // LFO
    reg [LFO_WIDTH-1:0] lfo_phase;
    wire [LFO_WIDTH-1:0] lfo_increment = {{(LFO_WIDTH-8){1'b0}}, rate} << 6;

    // Triangle LFO
    wire [LFO_WIDTH-1:0] lfo_abs = lfo_phase[LFO_WIDTH-1] ? ~lfo_phase : lfo_phase;
    wire [15:0] lfo_out = lfo_abs[LFO_WIDTH-1:LFO_WIDTH-16];

    // Modulated delay — clamp to MAX_DEPTH range
    wire [23:0] depth_product = (lfo_out * depth) >> 8;
    wire [ADDR_WIDTH-1:0] depth_clamped = (depth_product[23:ADDR_WIDTH] != 0 || depth_product[ADDR_WIDTH-1:0] > MAX_DEPTH) ?
                                           MAX_DEPTH[ADDR_WIDTH-1:0] :
                                           depth_product[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] mod_delay = BASE_DELAY[ADDR_WIDTH-1:0] + depth_clamped;

    // Read address — circular buffer wrap within BUF_SIZE
    wire [ADDR_WIDTH:0] rd_sum = {1'b0, wr_ptr} + BUF_SIZE - mod_delay;
    wire [ADDR_WIDTH-1:0] rd_ptr = (rd_sum >= BUF_SIZE) ?
                                    (rd_sum - BUF_SIZE) :
                                    rd_sum[ADDR_WIDTH-1:0];

    // Feedback sample
    reg signed [DATA_WIDTH-1:0] fb_sample;

    // Working registers
    reg signed [DATA_WIDTH+8:0] fb_scaled;
    reg signed [DATA_WIDTH-1:0] write_val;
    reg signed [DATA_WIDTH+8:0] wet, dry;

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // Initialize delay buffer to zero
    integer i;
    initial begin
        for (i = 0; i < BUF_SIZE; i = i + 1)
            delay_buf[i] = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            lfo_phase <= 0;
            fb_sample <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                // Read delayed sample
                fb_sample <= delay_buf[rd_ptr];

                // Compute input + feedback
                fb_scaled = fb_sample * feedback;
                write_val = s_axis_tdata + (fb_scaled >>> 7);

                // Write to buffer (saturate)
                delay_buf[wr_ptr] <= write_val;
                wr_ptr <= (wr_ptr == BUF_SIZE - 1) ? 0 : wr_ptr + 1;

                // Update LFO
                lfo_phase <= lfo_phase + lfo_increment;

                // Mix
                wet = fb_sample * $signed({1'b0, mix});
                dry = s_axis_tdata * $signed({1'b0, (8'd255 - mix)});
                m_axis_tdata <= (wet + dry) >>> 8;
                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
