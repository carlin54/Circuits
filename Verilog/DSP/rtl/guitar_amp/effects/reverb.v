// Schroeder Reverb — Parallel comb filters + series allpass filters
// Comb filters create the basic reverb density
// Allpass filters smooth the echo density without changing frequency response

module reverb #(
    parameter DATA_WIDTH     = 24,
    parameter MAX_COMB_DELAY = 2048,
    parameter MAX_AP_DELAY   = 1024,
    parameter NUM_COMBS      = 4,
    parameter NUM_ALLPASS    = 2,
    parameter PREDELAY_MAX   = 4800,
    parameter DAMPING        = 1,
    parameter EARLY_REF      = 1
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
    input  wire [7:0]                    decay,     // Feedback gain (0-255)
    input  wire [7:0]                    damping_ctrl, // LP filter in feedback
    input  wire [7:0]                    mix        // Wet/dry
);

    localparam COMB_ADDR_W = $clog2(MAX_COMB_DELAY);
    localparam AP_ADDR_W = $clog2(MAX_AP_DELAY);

    // Comb filter delays (mutually prime for natural sound)
    localparam [COMB_ADDR_W-1:0] COMB_DELAY_0 = 1557;
    localparam [COMB_ADDR_W-1:0] COMB_DELAY_1 = 1617;
    localparam [COMB_ADDR_W-1:0] COMB_DELAY_2 = 1491;
    localparam [COMB_ADDR_W-1:0] COMB_DELAY_3 = 1422;

    // Allpass filter delays
    localparam [AP_ADDR_W-1:0] AP_DELAY_0 = 225;
    localparam [AP_ADDR_W-1:0] AP_DELAY_1 = 556;

    // Functions to look up delay values by index
    function [COMB_ADDR_W-1:0] comb_delay_val;
        input integer idx;
        case (idx)
            0: comb_delay_val = COMB_DELAY_0;
            1: comb_delay_val = COMB_DELAY_1;
            2: comb_delay_val = COMB_DELAY_2;
            3: comb_delay_val = COMB_DELAY_3;
            default: comb_delay_val = COMB_DELAY_0;
        endcase
    endfunction

    function [AP_ADDR_W-1:0] ap_delay_val;
        input integer idx;
        case (idx)
            0: ap_delay_val = AP_DELAY_0;
            1: ap_delay_val = AP_DELAY_1;
            default: ap_delay_val = AP_DELAY_0;
        endcase
    endfunction

    // Comb filter buffers
    reg signed [DATA_WIDTH-1:0] comb_buf [0:NUM_COMBS-1][0:MAX_COMB_DELAY-1];
    reg [COMB_ADDR_W-1:0] comb_ptr [0:NUM_COMBS-1];
    reg signed [DATA_WIDTH-1:0] comb_out [0:NUM_COMBS-1];

    // Allpass filter buffers
    reg signed [DATA_WIDTH-1:0] ap_buf [0:NUM_ALLPASS-1][0:MAX_AP_DELAY-1];
    reg [AP_ADDR_W-1:0] ap_ptr [0:NUM_ALLPASS-1];

    // Damping filter state (simple 1-pole LP in each comb feedback)
    reg signed [DATA_WIDTH-1:0] damp_state [0:NUM_COMBS-1];

    // Working registers
    reg signed [DATA_WIDTH+2:0] comb_sum;
    reg signed [DATA_WIDTH-1:0] delayed;
    reg signed [DATA_WIDTH-1:0] damped;
    reg signed [DATA_WIDTH+8:0] lp;
    reg signed [DATA_WIDTH+8:0] fb;
    reg signed [DATA_WIDTH-1:0] comb_mixed;
    reg signed [DATA_WIDTH-1:0] ap_input;
    reg signed [DATA_WIDTH-1:0] buf_out;
    reg signed [DATA_WIDTH+8:0] gx;
    reg signed [DATA_WIDTH-1:0] ap_out;
    reg signed [DATA_WIDTH+8:0] g_buf;
    reg signed [DATA_WIDTH+8:0] wet, dry;

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    integer ci, ai;

    always @(posedge clk) begin
        if (rst) begin
            for (ci = 0; ci < NUM_COMBS; ci = ci + 1) begin
                comb_ptr[ci] <= 0;
                comb_out[ci] <= 0;
                damp_state[ci] <= 0;
            end
            for (ai = 0; ai < NUM_ALLPASS; ai = ai + 1)
                ap_ptr[ai] <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin

                // === Parallel Comb Filters ===
                comb_sum = 0;

                for (ci = 0; ci < NUM_COMBS; ci = ci + 1) begin
                    // Read from delay buffer
                    delayed = comb_buf[ci][comb_ptr[ci]];

                    // Damping LP filter: y = (1-d)*delayed + d*prev
                    if (DAMPING) begin
                        lp = delayed * $signed({1'b0, (8'd255 - damping_ctrl)}) +
                             damp_state[ci] * $signed({1'b0, damping_ctrl});
                        damped = lp >>> 8;
                        damp_state[ci] <= damped;
                    end else begin
                        damped = delayed;
                    end

                    comb_out[ci] <= damped;
                    comb_sum = comb_sum + damped;

                    // Write: input + feedback * delayed
                    fb = damped * $signed({1'b0, decay});
                    comb_buf[ci][comb_ptr[ci]] <= s_axis_tdata + (fb >>> 8);

                    // Advance pointer with wrap
                    if (comb_ptr[ci] >= comb_delay_val(ci) - 1)
                        comb_ptr[ci] <= 0;
                    else
                        comb_ptr[ci] <= comb_ptr[ci] + 1;
                end

                // Average comb outputs
                comb_mixed = comb_sum >>> $clog2(NUM_COMBS);

                // === Series Allpass Filters ===
                ap_input = comb_mixed;

                for (ai = 0; ai < NUM_ALLPASS; ai = ai + 1) begin
                    buf_out = ap_buf[ai][ap_ptr[ai]];

                    // Allpass: y = -g*x + buf + g*y_prev
                    // Simplified: y = buf - g*x; buf_new = x + g*buf
                    gx = ap_input * $signed(8'sd80);  // g ~= 0.3
                    ap_out = buf_out - (gx >>> 8);

                    g_buf = buf_out * $signed(8'sd80);
                    ap_buf[ai][ap_ptr[ai]] <= ap_input + (g_buf >>> 8);

                    ap_input = ap_out;

                    if (ap_ptr[ai] >= ap_delay_val(ai) - 1)
                        ap_ptr[ai] <= 0;
                    else
                        ap_ptr[ai] <= ap_ptr[ai] + 1;
                end

                // === Wet/Dry Mix ===
                wet = ap_input * $signed({1'b0, mix});
                dry = s_axis_tdata * $signed({1'b0, (8'd255 - mix)});

                m_axis_tdata <= (wet + dry) >>> 8;
                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
