// Numerically Controlled Oscillator (NCO)
// Phase accumulator + LUT/CORDIC sine/cosine generation
// Outputs simultaneous sine and cosine

module nco #(
    parameter PHASE_WIDTH  = 32,
    parameter OUTPUT_WIDTH = 16,
    parameter LUT_DEPTH    = 10,    // 2^10 = 1024-entry quarter-wave LUT
    parameter METHOD       = "LUT", // "LUT", "CORDIC"
    parameter DITHER       = 0      // Phase dither for spur reduction
)(
    input  wire                           clk,
    input  wire                           rst,

    // Frequency control
    input  wire [PHASE_WIDTH-1:0]         freq_word,    // Phase increment per clock
    input  wire [PHASE_WIDTH-1:0]         phase_offset, // Static phase offset

    // Output
    output reg  signed [OUTPUT_WIDTH-1:0] sin_out,
    output reg  signed [OUTPUT_WIDTH-1:0] cos_out,
    output reg                            valid
);

    // Phase accumulator
    reg [PHASE_WIDTH-1:0] phase_acc;
    wire [PHASE_WIDTH-1:0] phase_total = phase_acc + phase_offset;

    // Phase accumulator update
    always @(posedge clk) begin
        if (rst)
            phase_acc <= 0;
        else
            phase_acc <= phase_acc + freq_word;
    end

    // =========================================================================
    // LUT METHOD: Quarter-wave symmetry lookup table
    // =========================================================================
    generate
        if (METHOD == "LUT") begin : gen_lut

            localparam LUT_SIZE = 1 << LUT_DEPTH;

            // Quarter-wave sine LUT (only stores 0 to pi/2)
            reg signed [OUTPUT_WIDTH-1:0] sin_lut [0:LUT_SIZE-1];

            // Initialize LUT with quarter-wave sine
            integer li;
            initial begin
                for (li = 0; li < LUT_SIZE; li = li + 1) begin
                    // sin(i * pi/2 / LUT_SIZE) scaled to OUTPUT_WIDTH
                    // Use integer approximation
                    sin_lut[li] = ((li * ((1 << (OUTPUT_WIDTH-1)) - 1)) / LUT_SIZE);
                end
            end

            // Extract quadrant and LUT address from phase
            wire [1:0] quadrant = phase_total[PHASE_WIDTH-1:PHASE_WIDTH-2];
            wire [LUT_DEPTH-1:0] lut_addr_raw = phase_total[PHASE_WIDTH-3:PHASE_WIDTH-2-LUT_DEPTH];

            // Mirror address for quadrants 1 and 3
            wire [LUT_DEPTH-1:0] lut_addr = (quadrant[0]) ?
                                             ~lut_addr_raw : lut_addr_raw;

            reg signed [OUTPUT_WIDTH-1:0] sin_raw, cos_raw;
            reg [1:0] quadrant_d;
            reg [1:0] cos_quadrant;
            reg [LUT_DEPTH-1:0] cos_lut_addr;

            always @(posedge clk) begin
                if (rst) begin
                    sin_out <= 0;
                    cos_out <= 0;
                    valid <= 0;
                    sin_raw <= 0;
                    cos_raw <= 0;
                    quadrant_d <= 0;
                end else begin
                    valid <= 1;
                    quadrant_d <= quadrant;

                    // LUT read
                    sin_raw <= sin_lut[lut_addr];

                    // Cosine = sine with 90° offset
                    // cos quadrant = sin quadrant + 1
                    cos_quadrant = quadrant + 2'd1;
                    cos_lut_addr = (cos_quadrant[0]) ?
                                    ~lut_addr_raw : lut_addr_raw;
                    cos_raw <= sin_lut[cos_lut_addr];

                    // Apply sign based on quadrant
                    // Sine: positive in Q0,Q1 (quadrant[1]=0), negative in Q2,Q3
                    sin_out <= quadrant_d[1] ? -sin_raw : sin_raw;
                    // Cosine: positive in Q0,Q3, negative in Q1,Q2
                    cos_out <= (quadrant_d == 2'd1 || quadrant_d == 2'd2) ? -cos_raw : cos_raw;
                end
            end

        end
    endgenerate

    // =========================================================================
    // CORDIC METHOD: Use CORDIC rotation mode
    // =========================================================================
    generate
        if (METHOD == "CORDIC") begin : gen_cordic

            wire signed [OUTPUT_WIDTH-1:0] cordic_x, cordic_y;
            wire cordic_valid;

            // Initialize with unit vector on x-axis, rotate by phase
            // Pre-scale by 1/K (CORDIC gain compensation)
            localparam signed [OUTPUT_WIDTH-1:0] INIT_X = ((1 << (OUTPUT_WIDTH-2)) * 607) / 1000;  // ~0.6073 * scale

            cordic #(
                .DATA_WIDTH(OUTPUT_WIDTH),
                .NUM_ITERATIONS(OUTPUT_WIDTH),
                .MODE("ROTATION"),
                .PIPELINE(1),
                .COMPENSATION(0)
            ) cordic_inst (
                .clk(clk),
                .rst(rst),
                .x_in(INIT_X),
                .y_in({OUTPUT_WIDTH{1'b0}}),
                .z_in(phase_total[PHASE_WIDTH-1:PHASE_WIDTH-OUTPUT_WIDTH]),
                .valid_in(1'b1),
                .ready_in(),
                .x_out(cordic_x),
                .y_out(cordic_y),
                .z_out(),
                .valid_out(cordic_valid)
            );

            always @(posedge clk) begin
                if (rst) begin
                    cos_out <= 0;
                    sin_out <= 0;
                    valid <= 0;
                end else begin
                    cos_out <= cordic_x;
                    sin_out <= cordic_y;
                    valid <= cordic_valid;
                end
            end

        end
    endgenerate

endmodule
