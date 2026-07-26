// Cross-Correlator
// Modes: STREAMING (fixed lag, like FIR), BLOCK (full correlation), MATCHED_FILTER
// R_xy[lag] = sum(x[n] * y[n-lag])

module correlator #(
    parameter DATA_WIDTH   = 24,
    parameter OUTPUT_WIDTH = 48,
    parameter MAX_LAG      = 256,
    parameter MODE         = "STREAMING",  // "STREAMING", "BLOCK", "MATCHED_FILTER"
    parameter NORMALIZE    = 0
)(
    input  wire                          clk,
    input  wire                          rst,

    // Signal A input
    input  wire signed [DATA_WIDTH-1:0]  a_data,
    input  wire                          a_valid,

    // Signal B input (reference for MATCHED_FILTER, second signal for STREAMING/BLOCK)
    input  wire signed [DATA_WIDTH-1:0]  b_data,
    input  wire                          b_valid,

    // Reference pattern load (for MATCHED_FILTER mode)
    input  wire                          ref_we,
    input  wire [$clog2(MAX_LAG)-1:0]    ref_addr,
    input  wire signed [DATA_WIDTH-1:0]  ref_data,

    // Lag selection (for STREAMING mode)
    input  wire [$clog2(MAX_LAG)-1:0]    lag_select,

    // Output
    output reg  signed [OUTPUT_WIDTH-1:0] corr_out,
    output reg                            corr_valid,

    // Block mode control
    input  wire                          frame_start,
    output reg                           frame_done
);

    localparam ADDR_WIDTH = $clog2(MAX_LAG);

    // =========================================================================
    // STREAMING MODE: Continuously compute correlation at a single lag value
    // Like a FIR where coefficients are signal B samples
    // =========================================================================
    generate
        if (MODE == "STREAMING") begin : gen_streaming

            reg signed [DATA_WIDTH-1:0] a_delay [0:MAX_LAG-1];
            reg signed [DATA_WIDTH-1:0] b_delay [0:MAX_LAG-1];
            reg signed [OUTPUT_WIDTH-1:0] accumulator;
            reg [$clog2(MAX_LAG)-1:0] sample_count;
            reg running;

            integer si;
            always @(posedge clk) begin
                if (rst) begin
                    for (si = 0; si < MAX_LAG; si = si + 1) begin
                        a_delay[si] <= 0;
                        b_delay[si] <= 0;
                    end
                    accumulator <= 0;
                    sample_count <= 0;
                    corr_out <= 0;
                    corr_valid <= 0;
                    running <= 0;
                end else begin
                    corr_valid <= 0;

                    if (a_valid && b_valid) begin
                        // Shift delay lines
                        for (si = MAX_LAG-1; si > 0; si = si - 1) begin
                            a_delay[si] <= a_delay[si-1];
                            b_delay[si] <= b_delay[si-1];
                        end
                        a_delay[0] <= a_data;
                        b_delay[0] <= b_data;

                        // Compute: R[lag] = a[n] * b[n - lag]
                        // Accumulated over MAX_LAG samples
                        if (!running) begin
                            accumulator <= a_data * b_delay[lag_select];
                            sample_count <= 1;
                            running <= 1;
                        end else begin
                            accumulator <= accumulator + a_data * b_delay[lag_select];
                            sample_count <= sample_count + 1;

                            if (sample_count == MAX_LAG - 1) begin
                                corr_out <= accumulator + a_data * b_delay[lag_select];
                                corr_valid <= 1;
                                running <= 0;
                            end
                        end
                    end
                end
            end

            assign frame_done = 0;

        end
    endgenerate

    // =========================================================================
    // MATCHED FILTER MODE: Correlate streaming input against stored reference
    // =========================================================================
    generate
        if (MODE == "MATCHED_FILTER") begin : gen_matched

            reg signed [DATA_WIDTH-1:0] reference [0:MAX_LAG-1];
            reg signed [DATA_WIDTH-1:0] delay_line [0:MAX_LAG-1];
            reg signed [OUTPUT_WIDTH-1:0] accumulator;
            reg [$clog2(MAX_LAG):0] tap_count;
            reg processing;

            // Load reference pattern
            always @(posedge clk) begin
                if (ref_we)
                    reference[ref_addr] <= ref_data;
            end

            integer mi;
            always @(posedge clk) begin
                if (rst) begin
                    for (mi = 0; mi < MAX_LAG; mi = mi + 1) begin
                        delay_line[mi] <= 0;
                    end
                    accumulator <= 0;
                    tap_count <= 0;
                    processing <= 0;
                    corr_out <= 0;
                    corr_valid <= 0;
                end else begin
                    corr_valid <= 0;

                    if (!processing && a_valid) begin
                        // Shift in new sample
                        for (mi = MAX_LAG-1; mi > 0; mi = mi - 1)
                            delay_line[mi] <= delay_line[mi-1];
                        delay_line[0] <= a_data;

                        // Start MAC computation
                        accumulator <= 0;
                        tap_count <= 0;
                        processing <= 1;
                    end else if (processing) begin
                        // MAC: one tap per clock
                        accumulator <= accumulator + delay_line[tap_count] * reference[MAX_LAG-1-tap_count];
                        tap_count <= tap_count + 1;

                        if (tap_count == MAX_LAG - 1) begin
                            corr_out <= accumulator + delay_line[tap_count] * reference[MAX_LAG-1-tap_count];
                            corr_valid <= 1;
                            processing <= 0;
                        end
                    end
                end
            end

            assign frame_done = 0;

        end
    endgenerate

    // =========================================================================
    // BLOCK MODE: Full cross-correlation over a block of samples
    // =========================================================================
    generate
        if (MODE == "BLOCK") begin : gen_block

            reg signed [DATA_WIDTH-1:0] buf_a [0:MAX_LAG-1];
            reg signed [DATA_WIDTH-1:0] buf_b [0:MAX_LAG-1];
            reg [ADDR_WIDTH-1:0] load_count;
            reg loading_a, loading_b;
            reg computing;
            reg [ADDR_WIDTH-1:0] lag_count;
            reg [ADDR_WIDTH-1:0] sum_count;
            reg signed [OUTPUT_WIDTH-1:0] accumulator;

            integer bi;
            always @(posedge clk) begin
                if (rst) begin
                    for (bi = 0; bi < MAX_LAG; bi = bi + 1) begin
                        buf_a[bi] <= 0;
                        buf_b[bi] <= 0;
                    end
                    load_count <= 0;
                    loading_a <= 0;
                    loading_b <= 0;
                    computing <= 0;
                    lag_count <= 0;
                    sum_count <= 0;
                    accumulator <= 0;
                    corr_out <= 0;
                    corr_valid <= 0;
                    frame_done <= 0;
                end else begin
                    corr_valid <= 0;
                    frame_done <= 0;

                    if (frame_start && !computing) begin
                        loading_a <= 1;
                        loading_b <= 0;
                        load_count <= 0;
                    end

                    // Load signal A
                    if (loading_a && a_valid) begin
                        buf_a[load_count] <= a_data;
                        if (load_count == MAX_LAG - 1) begin
                            loading_a <= 0;
                            loading_b <= 1;
                            load_count <= 0;
                        end else begin
                            load_count <= load_count + 1;
                        end
                    end

                    // Load signal B
                    if (loading_b && b_valid) begin
                        buf_b[load_count] <= b_data;
                        if (load_count == MAX_LAG - 1) begin
                            loading_b <= 0;
                            computing <= 1;
                            lag_count <= 0;
                            sum_count <= 0;
                            accumulator <= 0;
                        end else begin
                            load_count <= load_count + 1;
                        end
                    end

                    // Compute correlation for each lag
                    if (computing) begin
                        // R[lag] = sum(a[n] * b[n - lag]) for valid indices
                        if (sum_count + lag_count < MAX_LAG) begin
                            accumulator <= accumulator + buf_a[sum_count] * buf_b[sum_count + lag_count];
                        end
                        sum_count <= sum_count + 1;

                        if (sum_count == MAX_LAG - 1) begin
                            // Output correlation for this lag
                            corr_out <= accumulator;
                            corr_valid <= 1;
                            accumulator <= 0;
                            sum_count <= 0;

                            if (lag_count == MAX_LAG - 1) begin
                                computing <= 0;
                                frame_done <= 1;
                            end else begin
                                lag_count <= lag_count + 1;
                            end
                        end
                    end
                end
            end

        end
    endgenerate

endmodule
