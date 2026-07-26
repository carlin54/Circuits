// Limiter — Brickwall output limiter with lookahead
// Prevents clipping on the output stage with very fast attack

module limiter #(
    parameter DATA_WIDTH     = 24,
    parameter LOOKAHEAD      = 32,    // Lookahead delay in samples
    parameter ATTACK_COEFF   = 1,     // Attack speed (lower = faster, 0=instant)
    parameter RELEASE_COEFF  = 12     // Release speed (higher = slower)
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
    input  wire [7:0]                    threshold,    // Limiting threshold (255=0dBFS, lower=more limiting)
    input  wire [7:0]                    release_ctrl  // Release time (0=fast, 255=slow)
);

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // Lookahead delay line
    reg signed [DATA_WIDTH-1:0] delay_buf [0:LOOKAHEAD-1];
    reg [$clog2(LOOKAHEAD)-1:0] delay_wr_ptr;
    reg [$clog2(LOOKAHEAD)-1:0] delay_rd_ptr;
    reg [5:0] fill_count;  // Track how full the delay is
    reg delay_full;

    // Delayed signal and last flag
    reg delay_last_buf [0:LOOKAHEAD-1];
    wire signed [DATA_WIDTH-1:0] delayed_sample = delay_buf[delay_rd_ptr];
    wire delayed_last = delay_last_buf[delay_rd_ptr];

    // Envelope follower on input (pre-delay)
    reg [DATA_WIDTH-1:0] envelope;

    // Gain reduction
    reg [7:0] gain;  // 255 = unity, lower = more reduction

    // Threshold scaled to data width
    wire [DATA_WIDTH-1:0] thresh_scaled = {threshold, {(DATA_WIDTH-8){1'b0}}};

    always @(posedge clk) begin
        if (rst) begin
            delay_wr_ptr <= 0;
            delay_rd_ptr <= LOOKAHEAD > 1 ? 1 : 0;
            fill_count <= 0;
            delay_full <= 0;
            envelope <= 0;
            gain <= 8'd255;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                // Write input to lookahead buffer
                delay_buf[delay_wr_ptr] <= s_axis_tdata;
                delay_last_buf[delay_wr_ptr] <= s_axis_tlast;
                delay_wr_ptr <= (delay_wr_ptr == LOOKAHEAD-1) ? 0 : delay_wr_ptr + 1;

                if (!delay_full) begin
                    fill_count <= fill_count + 1;
                    if (fill_count == LOOKAHEAD-1)
                        delay_full <= 1;
                end

                // Envelope: track peak of input
                reg [DATA_WIDTH-1:0] abs_in;
                abs_in = s_axis_tdata[DATA_WIDTH-1] ? -s_axis_tdata : s_axis_tdata;

                if (abs_in > envelope)
                    envelope <= envelope + ((abs_in - envelope) >> ATTACK_COEFF);
                else
                    envelope <= envelope - (envelope >> (4 + release_ctrl[7:5]));

                // Compute gain reduction
                if (envelope > thresh_scaled && envelope != 0) begin
                    // gain = threshold / envelope (fixed-point division approximation)
                    reg [DATA_WIDTH+7:0] div_num;
                    div_num = {thresh_scaled, 8'd0};
                    gain <= div_num[DATA_WIDTH+7:DATA_WIDTH];  // Simple shift-based approximation
                    if (gain < 8'd16)
                        gain <= 8'd16;  // Minimum gain floor (-24dB)
                end else begin
                    // Release: ramp gain back toward unity
                    if (gain < 8'd255)
                        gain <= gain + (8'd1);
                end

                // Apply gain to delayed signal (only when delay is full)
                if (delay_full) begin
                    reg signed [DATA_WIDTH+7:0] limited;
                    limited = delayed_sample * $signed({1'b0, gain});
                    m_axis_tdata <= limited >>> 8;
                    m_axis_tvalid <= 1;
                    m_axis_tlast <= delayed_last;
                    delay_rd_ptr <= (delay_rd_ptr == LOOKAHEAD-1) ? 0 : delay_rd_ptr + 1;
                end
            end
        end
    end

endmodule
