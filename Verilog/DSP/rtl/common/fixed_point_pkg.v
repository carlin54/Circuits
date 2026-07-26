// Fixed-point arithmetic package
// Defines Q-format parameters and provides saturation/rounding functions
// Convention: DATA_WIDTH = 1 (sign) + INT_BITS + FRAC_BITS (Q1.22 default = 24 bits)

module fixed_point_pkg;

    // Default parameters (used as reference; actual blocks parameterize independently)
    localparam DEFAULT_DATA_WIDTH = 24;
    localparam DEFAULT_FRAC_BITS  = 22;
    localparam DEFAULT_INT_BITS   = 1;  // DATA_WIDTH - 1 - FRAC_BITS

endmodule

// Saturation module: clamps a wider result to fit in a narrower output
module saturate #(
    parameter INPUT_WIDTH  = 48,
    parameter OUTPUT_WIDTH = 24
)(
    input  wire signed [INPUT_WIDTH-1:0]  data_in,
    output wire signed [OUTPUT_WIDTH-1:0] data_out,
    output wire                           overflow
);

    localparam EXTRA_BITS = INPUT_WIDTH - OUTPUT_WIDTH;

    wire all_sign_bits_same;
    assign all_sign_bits_same = (data_in[INPUT_WIDTH-1:OUTPUT_WIDTH-1] == {(EXTRA_BITS+1){data_in[INPUT_WIDTH-1]}});

    wire signed [OUTPUT_WIDTH-1:0] max_pos;
    wire signed [OUTPUT_WIDTH-1:0] max_neg;
    assign max_pos = {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
    assign max_neg = {1'b1, {(OUTPUT_WIDTH-1){1'b0}}};

    assign overflow  = ~all_sign_bits_same;
    assign data_out  = all_sign_bits_same ? data_in[OUTPUT_WIDTH-1:0] :
                       (data_in[INPUT_WIDTH-1] ? max_neg : max_pos);

endmodule

// Rounding module: reduces fractional precision with configurable rounding mode
module round #(
    parameter INPUT_WIDTH  = 48,
    parameter OUTPUT_WIDTH = 24,
    parameter INPUT_FRAC   = 30,
    parameter OUTPUT_FRAC  = 22,
    parameter ROUND_MODE   = 0   // 0 = truncate, 1 = round-half-up, 2 = round-half-to-even
)(
    input  wire signed [INPUT_WIDTH-1:0]  data_in,
    output wire signed [OUTPUT_WIDTH-1:0] data_out
);

    localparam FRAC_DROP = INPUT_FRAC - OUTPUT_FRAC;

    generate
        if (FRAC_DROP <= 0) begin : gen_no_round
            assign data_out = data_in[OUTPUT_WIDTH-1:0];
        end else if (ROUND_MODE == 0) begin : gen_truncate
            assign data_out = data_in[INPUT_WIDTH-1 -: OUTPUT_WIDTH];
        end else if (ROUND_MODE == 1) begin : gen_round_half_up
            wire signed [INPUT_WIDTH-1:0] rounded;
            assign rounded = data_in + (1 << (FRAC_DROP - 1));
            assign data_out = rounded[INPUT_WIDTH-1 -: OUTPUT_WIDTH];
        end else begin : gen_round_half_even
            wire guard_bit;
            wire round_bit;
            wire sticky;
            assign guard_bit = data_in[FRAC_DROP-1];
            assign round_bit = (FRAC_DROP >= 2) ? |data_in[FRAC_DROP-2:0] : 1'b0;
            assign sticky    = guard_bit & (round_bit | data_in[FRAC_DROP]);

            wire signed [INPUT_WIDTH-1:0] rounded;
            assign rounded = data_in + {{(INPUT_WIDTH-FRAC_DROP){1'b0}}, sticky, {(FRAC_DROP-1){1'b0}}};
            assign data_out = rounded[INPUT_WIDTH-1 -: OUTPUT_WIDTH];
        end
    endgenerate

endmodule
