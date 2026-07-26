// Combined rounding and saturation module
// Reduces a wide internal result to a narrower output with configurable behavior

module round_saturate #(
    parameter INPUT_WIDTH  = 48,
    parameter OUTPUT_WIDTH = 24,
    parameter INPUT_FRAC   = 30,
    parameter OUTPUT_FRAC  = 22,
    parameter ROUND_MODE   = 0,   // 0 = truncate, 1 = round-half-up, 2 = round-half-to-even
    parameter SAT_MODE     = 1    // 0 = wrap, 1 = saturate
)(
    input  wire signed [INPUT_WIDTH-1:0]  data_in,
    output wire signed [OUTPUT_WIDTH-1:0] data_out,
    output wire                           overflow
);

    localparam FRAC_DROP = INPUT_FRAC - OUTPUT_FRAC;
    localparam ROUNDED_WIDTH = INPUT_WIDTH - FRAC_DROP;

    // Step 1: Round (reduce fractional bits)
    wire signed [INPUT_WIDTH-1:0] rounded_full;

    generate
        if (FRAC_DROP <= 0) begin : gen_no_round
            assign rounded_full = data_in;
        end else if (ROUND_MODE == 0) begin : gen_truncate
            assign rounded_full = data_in;
        end else if (ROUND_MODE == 1) begin : gen_round_half_up
            assign rounded_full = data_in + (1 << (FRAC_DROP - 1));
        end else begin : gen_round_half_even
            wire guard = data_in[FRAC_DROP-1];
            wire sticky_bit = (FRAC_DROP >= 2) ? |data_in[FRAC_DROP-2:0] : 1'b0;
            wire lsb = data_in[FRAC_DROP];
            wire round_up = guard & (sticky_bit | lsb);
            assign rounded_full = data_in + {{(INPUT_WIDTH-FRAC_DROP){1'b0}}, round_up, {(FRAC_DROP-1){1'b0}}};
        end
    endgenerate

    // Extract the integer + output fractional portion
    wire signed [ROUNDED_WIDTH-1:0] rounded_trimmed;
    assign rounded_trimmed = rounded_full[INPUT_WIDTH-1:FRAC_DROP];

    // Step 2: Saturate or wrap to output width
    generate
        if (ROUNDED_WIDTH <= OUTPUT_WIDTH) begin : gen_no_sat
            assign data_out = rounded_trimmed;
            assign overflow = 1'b0;
        end else if (SAT_MODE == 0) begin : gen_wrap
            assign data_out = rounded_trimmed[OUTPUT_WIDTH-1:0];
            assign overflow = (rounded_trimmed[ROUNDED_WIDTH-1:OUTPUT_WIDTH-1] !=
                              {(ROUNDED_WIDTH-OUTPUT_WIDTH+1){rounded_trimmed[ROUNDED_WIDTH-1]}});
        end else begin : gen_saturate
            localparam EXTRA = ROUNDED_WIDTH - OUTPUT_WIDTH;
            wire all_same = (rounded_trimmed[ROUNDED_WIDTH-1:OUTPUT_WIDTH-1] ==
                            {(EXTRA+1){rounded_trimmed[ROUNDED_WIDTH-1]}});

            wire signed [OUTPUT_WIDTH-1:0] max_pos = {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
            wire signed [OUTPUT_WIDTH-1:0] max_neg = {1'b1, {(OUTPUT_WIDTH-1){1'b0}}};

            assign overflow = ~all_same;
            assign data_out = all_same ? rounded_trimmed[OUTPUT_WIDTH-1:0] :
                             (rounded_trimmed[ROUNDED_WIDTH-1] ? max_neg : max_pos);
        end
    endgenerate

endmodule
