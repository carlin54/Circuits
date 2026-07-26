// Pipelined Radix-2 Decimation-in-Time FFT
// N-point FFT with log2(N) stages of butterfly operations
// Block scaling: 1/2 per stage (1/N total)

module fft_top #(
    parameter N              = 1024,
    parameter DATA_WIDTH     = 24,
    parameter TWIDDLE_WIDTH  = 16,
    parameter TWIDDLE_FRAC_BITS = 14,
    parameter PIPELINE       = 1,
    parameter SCALING_MODE   = "BLOCK"  // "BLOCK", "NONE", "DYNAMIC"
)(
    input  wire                         clk,
    input  wire                         rst,

    // AXI-Stream input (real samples, imaginary assumed 0 for real FFT)
    input  wire signed [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tlast,

    // AXI-Stream output (complex: real in upper half, imag in lower half)
    output wire signed [DATA_WIDTH-1:0] m_axis_tdata_re,
    output wire signed [DATA_WIDTH-1:0] m_axis_tdata_im,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready,
    output wire                         m_axis_tlast
);

    localparam LOG2_N = $clog2(N);
    localparam NUM_STAGES = LOG2_N;

    // Internal data buses between stages
    wire signed [DATA_WIDTH-1:0] stage_re [0:NUM_STAGES];
    wire signed [DATA_WIDTH-1:0] stage_im [0:NUM_STAGES];
    wire stage_valid [0:NUM_STAGES];
    wire stage_last [0:NUM_STAGES];

    // Bit-reversal at input
    wire signed [DATA_WIDTH-1:0] br_re_out, br_im_out;
    wire br_valid_out, br_last_out, br_ready_out;

    bit_reversal #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    ) bit_rev_inst (
        .clk(clk),
        .rst(rst),
        .data_re_in(s_axis_tdata),
        .data_im_in({DATA_WIDTH{1'b0}}),
        .valid_in(s_axis_tvalid),
        .last_in(s_axis_tlast),
        .ready_in(s_axis_tready),
        .data_re_out(br_re_out),
        .data_im_out(br_im_out),
        .valid_out(br_valid_out),
        .last_out(br_last_out),
        .ready_out(1'b1)
    );

    assign stage_re[0] = br_re_out;
    assign stage_im[0] = br_im_out;
    assign stage_valid[0] = br_valid_out;
    assign stage_last[0] = br_last_out;

    // Generate butterfly stages
    // Each stage processes N/2 butterfly pairs
    // Stage s operates on pairs separated by 2^s positions

    genvar s;
    generate
        for (s = 0; s < NUM_STAGES; s = s + 1) begin : fft_stage

            localparam BUTTERFLIES_PER_GROUP = 1 << s;
            localparam NUM_GROUPS = N >> (s + 1);

            // Stage buffer: collect N samples, perform butterflies, output N samples
            reg signed [DATA_WIDTH-1:0] stage_buf_re [0:N-1];
            reg signed [DATA_WIDTH-1:0] stage_buf_im [0:N-1];
            reg [$clog2(N)-1:0] wr_cnt;
            reg [$clog2(N)-1:0] rd_cnt;
            reg buffering;  // 1 = writing input, 0 = reading output
            reg stage_out_valid;
            reg stage_out_last;

            // Twiddle factor for this stage
            wire signed [TWIDDLE_WIDTH-1:0] tw_re, tw_im;
            reg [$clog2(N)-1:0] tw_index;

            twiddle_rom #(
                .N(N),
                .STAGE(s),
                .TWIDDLE_WIDTH(TWIDDLE_WIDTH),
                .SYMMETRY("QUARTER")
            ) tw_rom (
                .clk(clk),
                .index(tw_index),
                .tw_real(tw_re),
                .tw_imag(tw_im)
            );

            always @(posedge clk) begin
                if (rst) begin
                    wr_cnt <= 0;
                    rd_cnt <= 0;
                    buffering <= 1;
                    stage_out_valid <= 0;
                    stage_out_last <= 0;
                    tw_index <= 0;
                end else begin
                    if (buffering) begin
                        stage_out_valid <= 0;
                        if (stage_valid[s]) begin
                            stage_buf_re[wr_cnt] <= stage_re[s];
                            stage_buf_im[wr_cnt] <= stage_im[s];
                            if (wr_cnt == N - 1) begin
                                wr_cnt <= 0;
                                buffering <= 0;
                                rd_cnt <= 0;
                            end else begin
                                wr_cnt <= wr_cnt + 1;
                            end
                        end
                    end else begin
                        // Perform butterfly and output
                        // Pair: (rd_cnt, rd_cnt + N/2) within each group
                        reg [$clog2(N)-1:0] idx_a, idx_b;
                        reg signed [DATA_WIDTH-1:0] a_re, a_im, b_re, b_im;
                        reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] prod_re, prod_im;
                        reg signed [DATA_WIDTH-1:0] wb_re, wb_im;

                        idx_a = rd_cnt;
                        // Compute butterfly partner index
                        // In stage s: pairs are separated by 2^s
                        idx_b = rd_cnt ^ (1 << s);

                        a_re = stage_buf_re[idx_a < idx_b ? idx_a : idx_b];
                        a_im = stage_buf_im[idx_a < idx_b ? idx_a : idx_b];
                        b_re = stage_buf_re[idx_a < idx_b ? idx_b : idx_a];
                        b_im = stage_buf_im[idx_a < idx_b ? idx_b : idx_a];

                        // Compute twiddle index for this butterfly
                        tw_index <= (rd_cnt % (1 << s)) * NUM_GROUPS;

                        // Complex multiply: W * B
                        prod_re = b_re * tw_re - b_im * tw_im;
                        prod_im = b_re * tw_im + b_im * tw_re;
                        wb_re = prod_re >>> (TWIDDLE_WIDTH - 1);
                        wb_im = prod_im >>> (TWIDDLE_WIDTH - 1);

                        // Butterfly output
                        if (idx_a < idx_b) begin
                            // Output A' = A + W*B (with block scaling: >>1)
                            if (SCALING_MODE == "BLOCK") begin
                                stage_buf_re[rd_cnt] <= (a_re + wb_re) >>> 1;
                                stage_buf_im[rd_cnt] <= (a_im + wb_im) >>> 1;
                            end else begin
                                stage_buf_re[rd_cnt] <= a_re + wb_re;
                                stage_buf_im[rd_cnt] <= a_im + wb_im;
                            end
                        end else begin
                            // Output B' = A - W*B
                            if (SCALING_MODE == "BLOCK") begin
                                stage_buf_re[rd_cnt] <= (a_re - wb_re) >>> 1;
                                stage_buf_im[rd_cnt] <= (a_im - wb_im) >>> 1;
                            end else begin
                                stage_buf_re[rd_cnt] <= a_re - wb_re;
                                stage_buf_im[rd_cnt] <= a_im - wb_im;
                            end
                        end

                        if (rd_cnt == N - 1) begin
                            rd_cnt <= 0;
                            buffering <= 1;
                            // Now output the results
                        end else begin
                            rd_cnt <= rd_cnt + 1;
                        end

                        stage_out_valid <= 1;
                        stage_out_last <= (rd_cnt == N - 1);
                    end
                end
            end

            assign stage_re[s+1] = stage_buf_re[rd_cnt];
            assign stage_im[s+1] = stage_buf_im[rd_cnt];
            assign stage_valid[s+1] = stage_out_valid;
            assign stage_last[s+1] = stage_out_last;

        end
    endgenerate

    // Output assignment
    assign m_axis_tdata_re = stage_re[NUM_STAGES];
    assign m_axis_tdata_im = stage_im[NUM_STAGES];
    assign m_axis_tvalid = stage_valid[NUM_STAGES];
    assign m_axis_tlast = stage_last[NUM_STAGES];

endmodule
