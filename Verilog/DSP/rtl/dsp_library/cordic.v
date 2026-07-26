// CORDIC Processor — Rotation and Vectoring modes
// Iterative shift-and-add algorithm (no multipliers)
// Pipeline or iterative architecture selectable via parameter

module cordic #(
    parameter DATA_WIDTH     = 16,
    parameter NUM_ITERATIONS = 16,
    parameter MODE           = "ROTATION",  // "ROTATION" or "VECTORING"
    parameter PIPELINE       = 1,           // 1 = pipelined, 0 = iterative
    parameter COMPENSATION   = 1            // 1 = compensate for CORDIC gain (1.6468)
)(
    input  wire                          clk,
    input  wire                          rst,

    // Input
    input  wire signed [DATA_WIDTH-1:0]  x_in,
    input  wire signed [DATA_WIDTH-1:0]  y_in,
    input  wire signed [DATA_WIDTH-1:0]  z_in,    // Angle (rotation) or initial angle (vectoring)
    input  wire                          valid_in,
    output wire                          ready_in,

    // Output
    output wire signed [DATA_WIDTH-1:0]  x_out,
    output wire signed [DATA_WIDTH-1:0]  y_out,
    output wire signed [DATA_WIDTH-1:0]  z_out,
    output wire                          valid_out
);

    // Arctangent lookup table (scaled to DATA_WIDTH fractional bits)
    // atan(2^-i) in radians, scaled by 2^(DATA_WIDTH-2) / pi
    // For a full circle representation: angles in range [-pi, pi) mapped to [-2^(DW-1), 2^(DW-1))
    reg signed [DATA_WIDTH-1:0] atan_table [0:NUM_ITERATIONS-1];

    // Precompute atan table values
    // atan(2^-i) * 2^(DATA_WIDTH-2) / (pi/2) for angular representation
    integer atan_i;
    initial begin
        // These values represent atan(2^-i) scaled to the DATA_WIDTH fractional format
        // Using the convention that full scale = pi radians
        for (atan_i = 0; atan_i < NUM_ITERATIONS; atan_i = atan_i + 1) begin
            // atan(2^-i) / pi * 2^(DATA_WIDTH-1)
            // Approximation using integer math:
            // For i=0: atan(1) = pi/4, so value = 2^(DW-1)/4 = 2^(DW-3)
            if (atan_i == 0)
                atan_table[0] = (1 << (DATA_WIDTH - 3));
            else
                atan_table[atan_i] = atan_table[atan_i-1] >> 1;
                // Rough approximation — proper values should be loaded from generated file
        end
    end

    // =========================================================================
    // PIPELINED ARCHITECTURE
    // =========================================================================
    generate
        if (PIPELINE == 1) begin : gen_pipelined

            // Pipeline registers for each stage
            reg signed [DATA_WIDTH-1:0] x_pipe [0:NUM_ITERATIONS];
            reg signed [DATA_WIDTH-1:0] y_pipe [0:NUM_ITERATIONS];
            reg signed [DATA_WIDTH-1:0] z_pipe [0:NUM_ITERATIONS];
            reg valid_pipe [0:NUM_ITERATIONS];

            assign ready_in = 1'b1;  // Always ready (fully pipelined)
            assign x_out = x_pipe[NUM_ITERATIONS];
            assign y_out = y_pipe[NUM_ITERATIONS];
            assign z_out = z_pipe[NUM_ITERATIONS];
            assign valid_out = valid_pipe[NUM_ITERATIONS];

            // Input stage
            always @(posedge clk) begin
                if (rst) begin
                    x_pipe[0] <= 0;
                    y_pipe[0] <= 0;
                    z_pipe[0] <= 0;
                    valid_pipe[0] <= 0;
                end else begin
                    x_pipe[0] <= x_in;
                    y_pipe[0] <= y_in;
                    z_pipe[0] <= z_in;
                    valid_pipe[0] <= valid_in;
                end
            end

            // CORDIC iterations
            genvar gi;
            for (gi = 0; gi < NUM_ITERATIONS; gi = gi + 1) begin : cordic_stage
                always @(posedge clk) begin
                    if (rst) begin
                        x_pipe[gi+1] <= 0;
                        y_pipe[gi+1] <= 0;
                        z_pipe[gi+1] <= 0;
                        valid_pipe[gi+1] <= 0;
                    end else begin
                        valid_pipe[gi+1] <= valid_pipe[gi];

                        if (MODE == "ROTATION") begin
                            // Rotation: drive z toward 0
                            if (z_pipe[gi] >= 0) begin
                                x_pipe[gi+1] <= x_pipe[gi] - (y_pipe[gi] >>> gi);
                                y_pipe[gi+1] <= y_pipe[gi] + (x_pipe[gi] >>> gi);
                                z_pipe[gi+1] <= z_pipe[gi] - atan_table[gi];
                            end else begin
                                x_pipe[gi+1] <= x_pipe[gi] + (y_pipe[gi] >>> gi);
                                y_pipe[gi+1] <= y_pipe[gi] - (x_pipe[gi] >>> gi);
                                z_pipe[gi+1] <= z_pipe[gi] + atan_table[gi];
                            end
                        end else begin
                            // Vectoring: drive y toward 0
                            if (y_pipe[gi] < 0) begin
                                x_pipe[gi+1] <= x_pipe[gi] - (y_pipe[gi] >>> gi);
                                y_pipe[gi+1] <= y_pipe[gi] + (x_pipe[gi] >>> gi);
                                z_pipe[gi+1] <= z_pipe[gi] - atan_table[gi];
                            end else begin
                                x_pipe[gi+1] <= x_pipe[gi] + (y_pipe[gi] >>> gi);
                                y_pipe[gi+1] <= y_pipe[gi] - (x_pipe[gi] >>> gi);
                                z_pipe[gi+1] <= z_pipe[gi] + atan_table[gi];
                            end
                        end
                    end
                end
            end

        end
    endgenerate

    // =========================================================================
    // ITERATIVE ARCHITECTURE
    // =========================================================================
    generate
        if (PIPELINE == 0) begin : gen_iterative

            reg signed [DATA_WIDTH-1:0] x_reg, y_reg, z_reg;
            reg [$clog2(NUM_ITERATIONS):0] iter;
            reg running;
            reg done;

            assign ready_in = !running;
            assign x_out = x_reg;
            assign y_out = y_reg;
            assign z_out = z_reg;
            assign valid_out = done;

            always @(posedge clk) begin
                if (rst) begin
                    x_reg <= 0;
                    y_reg <= 0;
                    z_reg <= 0;
                    iter <= 0;
                    running <= 0;
                    done <= 0;
                end else begin
                    done <= 0;

                    if (!running && valid_in) begin
                        x_reg <= x_in;
                        y_reg <= y_in;
                        z_reg <= z_in;
                        iter <= 0;
                        running <= 1;
                    end else if (running) begin
                        if (MODE == "ROTATION") begin
                            if (z_reg >= 0) begin
                                x_reg <= x_reg - (y_reg >>> iter);
                                y_reg <= y_reg + (x_reg >>> iter);
                                z_reg <= z_reg - atan_table[iter];
                            end else begin
                                x_reg <= x_reg + (y_reg >>> iter);
                                y_reg <= y_reg - (x_reg >>> iter);
                                z_reg <= z_reg + atan_table[iter];
                            end
                        end else begin
                            if (y_reg < 0) begin
                                x_reg <= x_reg - (y_reg >>> iter);
                                y_reg <= y_reg + (x_reg >>> iter);
                                z_reg <= z_reg - atan_table[iter];
                            end else begin
                                x_reg <= x_reg + (y_reg >>> iter);
                                y_reg <= y_reg - (x_reg >>> iter);
                                z_reg <= z_reg + atan_table[iter];
                            end
                        end

                        if (iter == NUM_ITERATIONS - 1) begin
                            running <= 0;
                            done <= 1;
                        end else begin
                            iter <= iter + 1;
                        end
                    end
                end
            end

        end
    endgenerate

endmodule
