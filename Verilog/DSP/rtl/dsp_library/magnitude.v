// Magnitude Calculator: |I + jQ| = sqrt(I^2 + Q^2)
// Three methods: CORDIC (exact, no mults), ALPHA_BETA (fast approx), SQUARED (I^2+Q^2)

module magnitude #(
    parameter DATA_WIDTH   = 24,
    parameter OUTPUT_WIDTH = 24,
    parameter METHOD       = "CORDIC",  // "CORDIC", "ALPHA_BETA", "SQUARED"
    parameter CORDIC_ITERS = 16
)(
    input  wire                          clk,
    input  wire                          rst,

    // Input (complex)
    input  wire signed [DATA_WIDTH-1:0]  i_in,  // In-phase (real)
    input  wire signed [DATA_WIDTH-1:0]  q_in,  // Quadrature (imaginary)
    input  wire                          valid_in,

    // Output
    output reg  signed [OUTPUT_WIDTH-1:0] mag_out,
    output reg                            valid_out
);

    // =========================================================================
    // CORDIC VECTORING MODE: drives y toward 0, x converges to magnitude
    // =========================================================================
    generate
        if (METHOD == "CORDIC") begin : gen_cordic

            wire signed [DATA_WIDTH-1:0] cordic_x_out;
            wire cordic_valid;

            // Pre-condition: ensure x >= 0 (rotate to first quadrant)
            reg signed [DATA_WIDTH-1:0] x_init, y_init;
            reg valid_d;

            always @(posedge clk) begin
                if (rst) begin
                    x_init <= 0;
                    y_init <= 0;
                    valid_d <= 0;
                end else begin
                    valid_d <= valid_in;
                    // Take absolute values and put in first quadrant
                    x_init <= (i_in[DATA_WIDTH-1]) ? -i_in : i_in;
                    y_init <= (q_in[DATA_WIDTH-1]) ? -q_in : q_in;
                end
            end

            cordic #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_ITERATIONS(CORDIC_ITERS),
                .MODE("VECTORING"),
                .PIPELINE(1),
                .COMPENSATION(1)
            ) cordic_mag (
                .clk(clk),
                .rst(rst),
                .x_in(x_init),
                .y_in(y_init),
                .z_in({DATA_WIDTH{1'b0}}),
                .valid_in(valid_d),
                .ready_in(),
                .x_out(cordic_x_out),
                .y_out(),
                .z_out(),
                .valid_out(cordic_valid)
            );

            always @(posedge clk) begin
                if (rst) begin
                    mag_out <= 0;
                    valid_out <= 0;
                end else begin
                    mag_out <= cordic_x_out[DATA_WIDTH-1:DATA_WIDTH-OUTPUT_WIDTH];
                    valid_out <= cordic_valid;
                end
            end

        end
    endgenerate

    // =========================================================================
    // ALPHA-BETA: max(|I|,|Q|) + 0.4*min(|I|,|Q|) — ~3% max error
    // =========================================================================
    generate
        if (METHOD == "ALPHA_BETA") begin : gen_alpha_beta

            // Constants for alpha-beta: alpha=1, beta=0.4 ≈ 102/256
            localparam BETA_NUM = 102;
            localparam BETA_DEN_SHIFT = 8;  // divide by 256

            reg [DATA_WIDTH-1:0] abs_i, abs_q;
            reg [DATA_WIDTH-1:0] max_val, min_val;
            reg [DATA_WIDTH+7:0] beta_term;

            always @(posedge clk) begin
                if (rst) begin
                    mag_out <= 0;
                    valid_out <= 0;
                end else begin
                    valid_out <= valid_in;

                    if (valid_in) begin
                        abs_i = (i_in[DATA_WIDTH-1]) ? -i_in : i_in;
                        abs_q = (q_in[DATA_WIDTH-1]) ? -q_in : q_in;

                        if (abs_i >= abs_q) begin
                            max_val = abs_i;
                            min_val = abs_q;
                        end else begin
                            max_val = abs_q;
                            min_val = abs_i;
                        end

                        beta_term = min_val * BETA_NUM;
                        mag_out <= max_val + (beta_term >> BETA_DEN_SHIFT);
                    end
                end
            end

        end
    endgenerate

    // =========================================================================
    // SQUARED: I^2 + Q^2 (no square root — useful for relative comparisons)
    // =========================================================================
    generate
        if (METHOD == "SQUARED") begin : gen_squared

            reg signed [2*DATA_WIDTH-1:0] i_sq, q_sq, sum_sq;

            always @(posedge clk) begin
                if (rst) begin
                    mag_out <= 0;
                    valid_out <= 0;
                end else begin
                    valid_out <= valid_in;
                    if (valid_in) begin
                        i_sq = i_in * i_in;
                        q_sq = q_in * q_in;
                        sum_sq = i_sq + q_sq;
                        // Truncate to output width (MSBs)
                        mag_out <= sum_sq[2*DATA_WIDTH-1:2*DATA_WIDTH-OUTPUT_WIDTH];
                    end
                end
            end

        end
    endgenerate

endmodule
