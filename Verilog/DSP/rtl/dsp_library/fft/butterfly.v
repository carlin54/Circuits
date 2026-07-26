// Radix-2 Butterfly Unit for FFT
// Computes: A_out = A_in + W * B_in
//           B_out = A_in - W * B_in
// Where W is the twiddle factor (complex)

module butterfly #(
    parameter DATA_WIDTH    = 24,
    parameter TWIDDLE_WIDTH = 16,
    parameter MULT_METHOD   = "3MULT"  // "3MULT" (Gauss) or "4MULT" (standard)
)(
    input  wire                              clk,
    input  wire                              rst,

    // Input pair (complex: real + imag, each DATA_WIDTH bits)
    input  wire signed [DATA_WIDTH-1:0]      ar_in,   // A real
    input  wire signed [DATA_WIDTH-1:0]      ai_in,   // A imaginary
    input  wire signed [DATA_WIDTH-1:0]      br_in,   // B real
    input  wire signed [DATA_WIDTH-1:0]      bi_in,   // B imaginary
    input  wire                              valid_in,

    // Twiddle factor (complex)
    input  wire signed [TWIDDLE_WIDTH-1:0]   wr,      // W real (cosine)
    input  wire signed [TWIDDLE_WIDTH-1:0]   wi,      // W imaginary (-sine)

    // Output pair
    output reg  signed [DATA_WIDTH-1:0]      ar_out,  // A' real
    output reg  signed [DATA_WIDTH-1:0]      ai_out,  // A' imaginary
    output reg  signed [DATA_WIDTH-1:0]      br_out,  // B' real
    output reg  signed [DATA_WIDTH-1:0]      bi_out,  // B' imaginary
    output reg                               valid_out
);

    localparam PROD_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH;
    localparam FRAC_BITS = TWIDDLE_WIDTH - 1;  // Twiddle is Q1.(TW-1)

    // Complex multiplication: W * B = (wr + j*wi) * (br + j*bi)
    // Standard: real = wr*br - wi*bi, imag = wr*bi + wi*br (4 multiplies)
    // Gauss:    k1 = wr*(br+bi), k2 = bi*(wr+wi), k3 = br*(wi-wr)
    //           real = k1 - k2, imag = k1 + k3 (3 multiplies)

    generate
        if (MULT_METHOD == "4MULT") begin : gen_4mult

            reg signed [PROD_WIDTH-1:0] wb_real, wb_imag;
            reg signed [DATA_WIDTH-1:0] ar_d, ai_d;
            reg valid_d;

            // Stage 1: Multiply
            always @(posedge clk) begin
                if (rst) begin
                    wb_real <= 0;
                    wb_imag <= 0;
                    ar_d <= 0;
                    ai_d <= 0;
                    valid_d <= 0;
                end else begin
                    wb_real <= (br_in * wr) - (bi_in * wi);
                    wb_imag <= (br_in * wi) + (bi_in * wr);
                    ar_d <= ar_in;
                    ai_d <= ai_in;
                    valid_d <= valid_in;
                end
            end

            // Stage 2: Add/subtract with scaling
            wire signed [DATA_WIDTH-1:0] wb_r_scaled = wb_real[PROD_WIDTH-1:FRAC_BITS];
            wire signed [DATA_WIDTH-1:0] wb_i_scaled = wb_imag[PROD_WIDTH-1:FRAC_BITS];

            always @(posedge clk) begin
                if (rst) begin
                    ar_out <= 0;
                    ai_out <= 0;
                    br_out <= 0;
                    bi_out <= 0;
                    valid_out <= 0;
                end else begin
                    ar_out <= ar_d + wb_r_scaled;
                    ai_out <= ai_d + wb_i_scaled;
                    br_out <= ar_d - wb_r_scaled;
                    bi_out <= ai_d - wb_i_scaled;
                    valid_out <= valid_d;
                end
            end

        end else begin : gen_3mult
            // Gauss method: 3 multiplies for complex mult
            reg signed [PROD_WIDTH-1:0] k1, k2, k3;
            reg signed [DATA_WIDTH-1:0] ar_d, ai_d;
            reg valid_d;

            wire signed [DATA_WIDTH:0] br_plus_bi = br_in + bi_in;
            wire signed [TWIDDLE_WIDTH:0] wr_plus_wi = wr + wi;
            wire signed [TWIDDLE_WIDTH:0] wi_minus_wr = wi - wr;

            // Stage 1: Three multiplies
            always @(posedge clk) begin
                if (rst) begin
                    k1 <= 0;
                    k2 <= 0;
                    k3 <= 0;
                    ar_d <= 0;
                    ai_d <= 0;
                    valid_d <= 0;
                end else begin
                    k1 <= wr * br_plus_bi;
                    k2 <= bi_in * wr_plus_wi;
                    k3 <= br_in * wi_minus_wr;
                    ar_d <= ar_in;
                    ai_d <= ai_in;
                    valid_d <= valid_in;
                end
            end

            // Stage 2: Combine and add/subtract
            wire signed [DATA_WIDTH-1:0] wb_r_scaled = (k1 - k2) >>> FRAC_BITS;
            wire signed [DATA_WIDTH-1:0] wb_i_scaled = (k1 + k3) >>> FRAC_BITS;

            always @(posedge clk) begin
                if (rst) begin
                    ar_out <= 0;
                    ai_out <= 0;
                    br_out <= 0;
                    bi_out <= 0;
                    valid_out <= 0;
                end else begin
                    ar_out <= ar_d + wb_r_scaled;
                    ai_out <= ai_d + wb_i_scaled;
                    br_out <= ar_d - wb_r_scaled;
                    bi_out <= ai_d - wb_i_scaled;
                    valid_out <= valid_d;
                end
            end

        end
    endgenerate

endmodule
