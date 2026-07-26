// Twiddle Factor ROM for FFT
// Stores quarter-wave sine values and derives full complex twiddle factors
// W_N^k = cos(2*pi*k/N) - j*sin(2*pi*k/N)

module twiddle_rom #(
    parameter N             = 1024,
    parameter STAGE         = 0,
    parameter TWIDDLE_WIDTH = 16,
    parameter SYMMETRY      = "QUARTER"  // "QUARTER", "HALF", "FULL"
)(
    input  wire                                clk,
    input  wire [$clog2(N)-1:0]               index,   // Twiddle index k
    output reg  signed [TWIDDLE_WIDTH-1:0]    tw_real, // cos(2*pi*k/N)
    output reg  signed [TWIDDLE_WIDTH-1:0]    tw_imag  // -sin(2*pi*k/N)
);

    // Number of unique twiddle factors for this stage
    localparam NUM_TWIDDLES = N >> (STAGE + 1);
    localparam QUARTER_SIZE = N / 4;

    // Quarter-wave sine table
    localparam QW_DEPTH = (SYMMETRY == "QUARTER") ? QUARTER_SIZE :
                          (SYMMETRY == "HALF") ? N/2 : N;

    reg signed [TWIDDLE_WIDTH-1:0] sin_table [0:QW_DEPTH-1];

    // Initialize sine table
    // In synthesis, this would be loaded from a generated hex file
    // For simulation, use initial block with computed values
    integer tw_i;
    initial begin
        for (tw_i = 0; tw_i < QW_DEPTH; tw_i = tw_i + 1) begin
            // sin(2*pi*i/N) scaled to TWIDDLE_WIDTH fixed point
            // Q1.(TWIDDLE_WIDTH-1) format: range [-1, 1)
            // Approximation for init — proper values from gen_twiddle.py
            sin_table[tw_i] = 0;  // Placeholder — load from INIT_FILE in real use
        end
    end

    // Address mapping with quarter-wave symmetry
    generate
        if (SYMMETRY == "QUARTER") begin : gen_quarter

            wire [$clog2(N)-1:0] phase = index;  // Phase in [0, N)
            wire [1:0] quadrant = phase[$clog2(N)-1:$clog2(N)-2];
            wire [$clog2(QUARTER_SIZE)-1:0] qw_addr_raw = phase[$clog2(N)-3:0];

            // Mirror in odd quadrants
            wire [$clog2(QUARTER_SIZE)-1:0] qw_addr = quadrant[0] ?
                (QUARTER_SIZE - 1 - qw_addr_raw) : qw_addr_raw;

            always @(posedge clk) begin
                // Sine lookup
                reg signed [TWIDDLE_WIDTH-1:0] sin_val;
                sin_val = sin_table[qw_addr];

                // Apply quadrant signs for sin
                // sin: positive in Q0,Q1; negative in Q2,Q3
                reg signed [TWIDDLE_WIDTH-1:0] full_sin;
                full_sin = quadrant[1] ? -sin_val : sin_val;

                // cos(x) = sin(x + pi/2), so shift quadrant by 1
                reg [1:0] cos_quadrant;
                cos_quadrant = quadrant + 2'd1;
                reg [$clog2(QUARTER_SIZE)-1:0] cos_addr;
                cos_addr = cos_quadrant[0] ? (QUARTER_SIZE - 1 - qw_addr_raw) : qw_addr_raw;
                reg signed [TWIDDLE_WIDTH-1:0] cos_sin_val;
                cos_sin_val = sin_table[cos_addr];
                reg signed [TWIDDLE_WIDTH-1:0] full_cos;
                full_cos = cos_quadrant[1] ? -cos_sin_val : cos_sin_val;

                // Twiddle: W = cos - j*sin
                tw_real <= full_cos;
                tw_imag <= -full_sin;
            end

        end else begin : gen_full

            // Simple direct lookup (less area-efficient)
            reg signed [TWIDDLE_WIDTH-1:0] cos_table [0:QW_DEPTH-1];

            initial begin
                for (tw_i = 0; tw_i < QW_DEPTH; tw_i = tw_i + 1)
                    cos_table[tw_i] = 0;  // Placeholder
            end

            always @(posedge clk) begin
                tw_real <= cos_table[index];
                tw_imag <= -sin_table[index];
            end

        end
    endgenerate

endmodule
