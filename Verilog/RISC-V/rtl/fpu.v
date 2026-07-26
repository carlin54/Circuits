module fpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] c,
    input  wire [4:0]  op,
    input  wire        single,
    input  wire [2:0]  rm,
    output reg  [63:0] result,
    output reg  [4:0]  fflags,
    output reg         done,
    output wire        busy
);

assign busy = 0;

// FPU op encodings
localparam FADD   = 5'b00000;
localparam FSUB   = 5'b00001;
localparam FMUL   = 5'b00010;
localparam FDIV   = 5'b00011;
localparam FSQRT  = 5'b00100;
localparam FMADD  = 5'b00101;
localparam FMSUB  = 5'b00110;
localparam FNMADD = 5'b00111;
localparam FNMSUB = 5'b01000;
localparam FSGNJ  = 5'b01001;
localparam FSGNJN = 5'b01010;
localparam FSGNJX = 5'b01011;
localparam FMIN   = 5'b01100;
localparam FMAX   = 5'b01101;
localparam FCVT_W  = 5'b01110;
localparam FCVT_WU = 5'b01111;
localparam FCVT_L  = 5'b10000;
localparam FCVT_LU = 5'b10001;
localparam FCVT_FROM_W  = 5'b10010;
localparam FCVT_FROM_WU = 5'b10011;
localparam FCVT_FROM_L  = 5'b10100;
localparam FCVT_FROM_LU = 5'b10101;
localparam FCVT_SD = 5'b10110;
localparam FMV_X  = 5'b10111;
localparam FMV_WX = 5'b11000;
localparam FEQ    = 5'b11001;
localparam FLT    = 5'b11010;
localparam FLE    = 5'b11011;
localparam FCLASS = 5'b11100;

// NaN-boxing check for single precision
wire [31:0] a_s = (a[63:32] == 32'hFFFFFFFF) ? a[31:0] : 32'h7FC00000;
wire [31:0] b_s = (b[63:32] == 32'hFFFFFFFF) ? b[31:0] : 32'h7FC00000;
wire [31:0] c_s = (c[63:32] == 32'hFFFFFFFF) ? c[31:0] : 32'h7FC00000;

// IEEE 754 field extraction - single
wire        a_s_sign = a_s[31];
wire [7:0]  a_s_exp  = a_s[30:23];
wire [22:0] a_s_frac = a_s[22:0];
wire        b_s_sign = b_s[31];
wire [7:0]  b_s_exp  = b_s[30:23];
wire [22:0] b_s_frac = b_s[22:0];
wire        c_s_sign = c_s[31];
wire [7:0]  c_s_exp  = c_s[30:23];
wire [22:0] c_s_frac = c_s[22:0];

wire a_s_is_nan   = (a_s_exp == 8'hFF) && (a_s_frac != 0);
wire a_s_is_snan  = a_s_is_nan && !a_s_frac[22];
wire a_s_is_qnan  = a_s_is_nan && a_s_frac[22];
wire a_s_is_inf   = (a_s_exp == 8'hFF) && (a_s_frac == 0);
wire a_s_is_zero  = (a_s_exp == 0) && (a_s_frac == 0);
wire a_s_is_sub   = (a_s_exp == 0) && (a_s_frac != 0);

wire b_s_is_nan   = (b_s_exp == 8'hFF) && (b_s_frac != 0);
wire b_s_is_snan  = b_s_is_nan && !b_s_frac[22];
wire b_s_is_inf   = (b_s_exp == 8'hFF) && (b_s_frac == 0);
wire b_s_is_zero  = (b_s_exp == 0) && (b_s_frac == 0);
wire b_s_is_sub   = (b_s_exp == 0) && (b_s_frac != 0);

wire c_s_is_nan   = (c_s_exp == 8'hFF) && (c_s_frac != 0);
wire c_s_is_snan  = c_s_is_nan && !c_s_frac[22];
wire c_s_is_inf   = (c_s_exp == 8'hFF) && (c_s_frac == 0);
wire c_s_is_zero  = (c_s_exp == 0) && (c_s_frac == 0);
wire c_s_is_sub   = (c_s_exp == 0) && (c_s_frac != 0);

// IEEE 754 field extraction - double
wire        a_d_sign = a[63];
wire [10:0] a_d_exp  = a[62:52];
wire [51:0] a_d_frac = a[51:0];
wire        b_d_sign = b[63];
wire [10:0] b_d_exp  = b[62:52];
wire [51:0] b_d_frac = b[51:0];
wire        c_d_sign = c[63];
wire [10:0] c_d_exp  = c[62:52];
wire [51:0] c_d_frac = c[51:0];

wire a_d_is_nan   = (a_d_exp == 11'h7FF) && (a_d_frac != 0);
wire a_d_is_snan  = a_d_is_nan && !a_d_frac[51];
wire a_d_is_qnan  = a_d_is_nan && a_d_frac[51];
wire a_d_is_inf   = (a_d_exp == 11'h7FF) && (a_d_frac == 0);
wire a_d_is_zero  = (a_d_exp == 0) && (a_d_frac == 0);
wire a_d_is_sub   = (a_d_exp == 0) && (a_d_frac != 0);

wire b_d_is_nan   = (b_d_exp == 11'h7FF) && (b_d_frac != 0);
wire b_d_is_snan  = b_d_is_nan && !b_d_frac[51];
wire b_d_is_inf   = (b_d_exp == 11'h7FF) && (b_d_frac == 0);
wire b_d_is_zero  = (b_d_exp == 0) && (b_d_frac == 0);
wire b_d_is_sub   = (b_d_exp == 0) && (b_d_frac != 0);

wire c_d_is_nan   = (c_d_exp == 11'h7FF) && (c_d_frac != 0);
wire c_d_is_snan  = c_d_is_nan && !c_d_frac[51];
wire c_d_is_inf   = (c_d_exp == 11'h7FF) && (c_d_frac == 0);
wire c_d_is_zero  = (c_d_exp == 0) && (c_d_frac == 0);
wire c_d_is_sub   = (c_d_exp == 0) && (c_d_frac != 0);

// NaN-box a single result
function [63:0] nanbox;
    input [31:0] val;
    begin
        nanbox = {32'hFFFFFFFF, val};
    end
endfunction

// Canonical NaN constants
wire [31:0] QNAN_S = 32'h7FC00000;
wire [63:0] QNAN_D = 64'h7FF8000000000000;

// FCLASS implementation for single
function [63:0] classify_s;
    input [31:0] v;
    reg [9:0] cls;
    begin
        cls = 10'b0;
        if (v[30:23] == 8'hFF && v[22:0] != 0 && !v[22]) cls[8] = 1;
        else if (v[30:23] == 8'hFF && v[22:0] != 0 && v[22]) cls[9] = 1;
        else if (v == 32'hFF800000) cls[0] = 1;
        else if (v == 32'h7F800000) cls[7] = 1;
        else if (v[31] && v[30:23] != 0 && v[30:23] != 8'hFF) cls[1] = 1;
        else if (!v[31] && v[30:23] != 0 && v[30:23] != 8'hFF) cls[6] = 1;
        else if (v[31] && v[30:23] == 0 && v[22:0] != 0) cls[2] = 1;
        else if (!v[31] && v[30:23] == 0 && v[22:0] != 0) cls[5] = 1;
        else if (v == 32'h80000000) cls[3] = 1;
        else cls[4] = 1;
        classify_s = {54'b0, cls};
    end
endfunction

// FCLASS implementation for double
function [63:0] classify_d;
    input [63:0] v;
    reg [9:0] cls;
    begin
        cls = 10'b0;
        if (v[62:52] == 11'h7FF && v[51:0] != 0 && !v[51]) cls[8] = 1;
        else if (v[62:52] == 11'h7FF && v[51:0] != 0 && v[51]) cls[9] = 1;
        else if (v == 64'hFFF0000000000000) cls[0] = 1;
        else if (v == 64'h7FF0000000000000) cls[7] = 1;
        else if (v[63] && v[62:52] != 0 && v[62:52] != 11'h7FF) cls[1] = 1;
        else if (!v[63] && v[62:52] != 0 && v[62:52] != 11'h7FF) cls[6] = 1;
        else if (v[63] && v[62:52] == 0 && v[51:0] != 0) cls[2] = 1;
        else if (!v[63] && v[62:52] == 0 && v[51:0] != 0) cls[5] = 1;
        else if (v == 64'h8000000000000000) cls[3] = 1;
        else cls[4] = 1;
        classify_d = {54'b0, cls};
    end
endfunction

// Float less-than comparison (handles -0 == +0)
function fp_lt_s;
    input [31:0] x, y;
    begin
        if (x[31] != y[31])
            fp_lt_s = x[31] && (x[30:0] != 0 || y[30:0] != 0);
        else if (x[31])
            fp_lt_s = ({x[30:23], x[22:0]} > {y[30:23], y[22:0]});
        else
            fp_lt_s = ({x[30:23], x[22:0]} < {y[30:23], y[22:0]});
    end
endfunction

function fp_lt_d;
    input [63:0] x, y;
    begin
        if (x[63] != y[63])
            fp_lt_d = x[63] && (x[62:0] != 0 || y[62:0] != 0);
        else if (x[63])
            fp_lt_d = ({x[62:52], x[51:0]} > {y[62:52], y[51:0]});
        else
            fp_lt_d = ({x[62:52], x[51:0]} < {y[62:52], y[51:0]});
    end
endfunction

function fp_eq_s;
    input [31:0] x, y;
    begin
        fp_eq_s = (x == y) || (x[30:0] == 0 && y[30:0] == 0);
    end
endfunction

function fp_eq_d;
    input [63:0] x, y;
    begin
        fp_eq_d = (x == y) || (x[62:0] == 0 && y[62:0] == 0);
    end
endfunction

// ========== Integer-based IEEE 754 arithmetic ==========
// Working registers
reg        res_sign;
reg signed [12:0] res_exp;
reg [54:0] res_frac;

reg        op_a_sign, op_b_sign, op_c_sign;
reg signed [12:0] op_a_exp, op_b_exp, op_c_exp;
reg [52:0] op_a_frac, op_b_frac, op_c_frac;
reg signed [12:0] exp_diff;
reg [107:0] mul_prod;
reg [63:0] temp_result;
reg [4:0]  temp_flags;

// For normalization shift counting
reg [6:0] lz_count;
integer k;

// Division working registers
reg [54:0] div_rem;
reg [54:0] div_quot;
reg [52:0] div_divisor;
integer div_i;

// Square root working registers
reg [56:0] sqrt_rem;
reg [54:0] sqrt_root;
reg [56:0] sqrt_trial;
integer sqrt_i;

// Rounding working registers
reg        rnd_guard, rnd_round, rnd_sticky, rnd_up;
reg [23:0] rnd_frac_s;
reg [52:0] rnd_frac_d;
reg        rnd_overflow;

// Main computation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done   <= 0;
        result <= 64'b0;
        fflags <= 5'b0;
    end else if (start) begin
        done   <= 1;
        fflags <= 5'b0;
        result <= 64'b0;

        case (op)
            FSGNJ: begin
                if (single)
                    result <= nanbox({b_s[31], a_s[30:0]});
                else
                    result <= {b[63], a[62:0]};
            end
            FSGNJN: begin
                if (single)
                    result <= nanbox({~b_s[31], a_s[30:0]});
                else
                    result <= {~b[63], a[62:0]};
            end
            FSGNJX: begin
                if (single)
                    result <= nanbox({a_s[31] ^ b_s[31], a_s[30:0]});
                else
                    result <= {a[63] ^ b[63], a[62:0]};
            end

            FMV_X: begin
                if (single)
                    result <= {{32{a[31]}}, a[31:0]};
                else
                    result <= a;
            end
            FMV_WX: begin
                if (single)
                    result <= nanbox(a[31:0]);
                else
                    result <= a;
            end

            FCLASS: begin
                if (single)
                    result <= classify_s(a_s);
                else
                    result <= classify_d(a);
            end

            FEQ: begin
                if (single) begin
                    if (a_s_is_nan || b_s_is_nan) begin
                        result <= 64'd0;
                        if (a_s_is_snan || b_s_is_snan) fflags <= 5'b10000;
                    end else
                        result <= fp_eq_s(a_s, b_s) ? 64'd1 : 64'd0;
                end else begin
                    if (a_d_is_nan || b_d_is_nan) begin
                        result <= 64'd0;
                        if (a_d_is_snan || b_d_is_snan) fflags <= 5'b10000;
                    end else
                        result <= fp_eq_d(a, b) ? 64'd1 : 64'd0;
                end
            end
            FLT: begin
                if (single) begin
                    if (a_s_is_nan || b_s_is_nan) begin
                        result <= 64'd0;
                        fflags <= 5'b10000;
                    end else
                        result <= fp_lt_s(a_s, b_s) ? 64'd1 : 64'd0;
                end else begin
                    if (a_d_is_nan || b_d_is_nan) begin
                        result <= 64'd0;
                        fflags <= 5'b10000;
                    end else
                        result <= fp_lt_d(a, b) ? 64'd1 : 64'd0;
                end
            end
            FLE: begin
                if (single) begin
                    if (a_s_is_nan || b_s_is_nan) begin
                        result <= 64'd0;
                        fflags <= 5'b10000;
                    end else
                        result <= (fp_lt_s(a_s, b_s) || fp_eq_s(a_s, b_s)) ? 64'd1 : 64'd0;
                end else begin
                    if (a_d_is_nan || b_d_is_nan) begin
                        result <= 64'd0;
                        fflags <= 5'b10000;
                    end else
                        result <= (fp_lt_d(a, b) || fp_eq_d(a, b)) ? 64'd1 : 64'd0;
                end
            end

            FMIN: begin
                if (single) begin
                    if (a_s_is_nan && b_s_is_nan) result <= nanbox(QNAN_S);
                    else if (a_s_is_nan) result <= nanbox(b_s);
                    else if (b_s_is_nan) result <= nanbox(a_s);
                    else if (a_s_is_zero && b_s_is_zero && (a_s_sign != b_s_sign))
                        result <= nanbox({1'b1, 31'b0});
                    else result <= nanbox(fp_lt_s(a_s, b_s) ? a_s : b_s);
                    if (a_s_is_snan || b_s_is_snan) fflags <= 5'b10000;
                end else begin
                    if (a_d_is_nan && b_d_is_nan) result <= QNAN_D;
                    else if (a_d_is_nan) result <= b;
                    else if (b_d_is_nan) result <= a;
                    else if (a_d_is_zero && b_d_is_zero && (a_d_sign != b_d_sign))
                        result <= 64'h8000000000000000;
                    else result <= fp_lt_d(a, b) ? a : b;
                    if (a_d_is_snan || b_d_is_snan) fflags <= 5'b10000;
                end
            end
            FMAX: begin
                if (single) begin
                    if (a_s_is_nan && b_s_is_nan) result <= nanbox(QNAN_S);
                    else if (a_s_is_nan) result <= nanbox(b_s);
                    else if (b_s_is_nan) result <= nanbox(a_s);
                    else if (a_s_is_zero && b_s_is_zero && (a_s_sign != b_s_sign))
                        result <= nanbox(32'b0);
                    else result <= nanbox(fp_lt_s(b_s, a_s) ? a_s : b_s);
                    if (a_s_is_snan || b_s_is_snan) fflags <= 5'b10000;
                end else begin
                    if (a_d_is_nan && b_d_is_nan) result <= QNAN_D;
                    else if (a_d_is_nan) result <= b;
                    else if (b_d_is_nan) result <= a;
                    else if (a_d_is_zero && b_d_is_zero && (a_d_sign != b_d_sign))
                        result <= 64'b0;
                    else result <= fp_lt_d(b, a) ? a : b;
                    if (a_d_is_snan || b_d_is_snan) fflags <= 5'b10000;
                end
            end

            // ===================== FADD / FSUB =====================
            FADD, FSUB: begin
                if (single) begin
                    if (a_s_is_nan || b_s_is_nan) begin
                        result <= nanbox(QNAN_S);
                        if (a_s_is_snan || b_s_is_snan) fflags <= 5'b10000;
                    end else begin
                        op_a_sign = a_s_sign;
                        op_b_sign = (op == FSUB) ? ~b_s_sign : b_s_sign;
                        op_a_exp = a_s_is_sub ? 13'd1 : {5'b0, a_s_exp};
                        op_b_exp = b_s_is_sub ? 13'd1 : {5'b0, b_s_exp};
                        op_a_frac = {a_s_is_sub ? 1'b0 : 1'b1, a_s_frac, 29'b0};
                        op_b_frac = {b_s_is_sub ? 1'b0 : 1'b1, b_s_frac, 29'b0};

                        if (a_s_is_inf && b_s_is_inf) begin
                            if (op_a_sign != op_b_sign) begin
                                result <= nanbox(QNAN_S); fflags <= 5'b10000;
                            end else
                                result <= nanbox({op_a_sign, 8'hFF, 23'b0});
                        end else if (a_s_is_inf)
                            result <= nanbox({op_a_sign, 8'hFF, 23'b0});
                        else if (b_s_is_inf)
                            result <= nanbox({op_b_sign, 8'hFF, 23'b0});
                        else if (a_s_is_zero && b_s_is_zero) begin
                            result <= nanbox({op_a_sign & op_b_sign, 31'b0});
                        end else begin
                            // Align exponents
                            rnd_sticky = 0;
                            if (op_a_exp < op_b_exp) begin
                                exp_diff = op_b_exp - op_a_exp;
                                if (exp_diff > 53) begin
                                    rnd_sticky = (op_a_frac != 0);
                                    exp_diff = 53;
                                end else if (exp_diff > 0) begin
                                    // Capture bits that will be shifted out
                                    for (k = 0; k < 53; k = k + 1)
                                        if (k < exp_diff)
                                            rnd_sticky = rnd_sticky | op_a_frac[k];
                                end
                                op_a_frac = op_a_frac >> exp_diff;
                                op_a_exp = op_b_exp;
                            end else if (op_b_exp < op_a_exp) begin
                                exp_diff = op_a_exp - op_b_exp;
                                if (exp_diff > 53) begin
                                    rnd_sticky = (op_b_frac != 0);
                                    exp_diff = 53;
                                end else if (exp_diff > 0) begin
                                    for (k = 0; k < 53; k = k + 1)
                                        if (k < exp_diff)
                                            rnd_sticky = rnd_sticky | op_b_frac[k];
                                end
                                op_b_frac = op_b_frac >> exp_diff;
                                op_b_exp = op_a_exp;
                            end

                            // Add or subtract mantissas
                            if (op_a_sign == op_b_sign) begin
                                res_sign = op_a_sign;
                                res_frac = {1'b0, op_a_frac} + {1'b0, op_b_frac};
                                res_exp = op_a_exp;
                                if (res_frac[53]) begin
                                    rnd_sticky = rnd_sticky | res_frac[0];
                                    res_frac = res_frac >> 1;
                                    res_exp = res_exp + 1;
                                end
                            end else begin
                                if (op_a_frac > op_b_frac) begin
                                    res_sign = op_a_sign;
                                    res_frac = op_a_frac - op_b_frac;
                                end else if (op_b_frac > op_a_frac) begin
                                    res_sign = op_b_sign;
                                    res_frac = op_b_frac - op_a_frac;
                                end else begin
                                    res_sign = op_a_sign & op_b_sign;
                                    res_frac = 0;
                                end
                                res_exp = op_a_exp;
                                // Normalize left
                                if (res_frac == 0 && !rnd_sticky) begin
                                    res_exp = 0;
                                end else if (res_frac != 0) begin
                                    lz_count = 0;
                                    for (k = 52; k >= 0; k = k - 1)
                                        if (!res_frac[k] && lz_count == (52 - k))
                                            lz_count = lz_count + 1;
                                    if (lz_count > 0 && res_exp > lz_count) begin
                                        res_frac = res_frac << lz_count;
                                        res_exp = res_exp - lz_count;
                                    end else if (lz_count > 0 && res_exp >= 1) begin
                                        res_frac = res_frac << (res_exp - 1);
                                        res_exp = 0;
                                    end
                                end
                            end

                            // Round and pack (single precision)
                            // Hidden bit at [52], fraction at [51:29], guard=[28], round=[27], sticky=|[26:0]|rnd_sticky
                            if (res_exp >= 255) begin
                                result <= nanbox({res_sign, 8'hFF, 23'b0});
                                fflags <= 5'b00101;
                            end else if (res_exp == 0 && res_frac == 0 && !rnd_sticky) begin
                                result <= nanbox({res_sign, 31'b0});
                            end else begin
                                rnd_guard = res_frac[28];
                                rnd_round = res_frac[27];
                                rnd_sticky = rnd_sticky | (|res_frac[26:0]);
                                rnd_up = rnd_guard & (rnd_round | rnd_sticky | res_frac[29]);
                                rnd_frac_s = {1'b0, res_frac[51:29]} + rnd_up;
                                if (rnd_frac_s[23]) begin
                                    // Rounding overflow
                                    res_exp = res_exp + 1;
                                    if (res_exp >= 255) begin
                                        result <= nanbox({res_sign, 8'hFF, 23'b0});
                                        fflags <= 5'b00101;
                                    end else begin
                                        result <= nanbox({res_sign, res_exp[7:0], 23'b0});
                                    end
                                end else begin
                                    result <= nanbox({res_sign, res_exp[7:0], rnd_frac_s[22:0]});
                                end
                                if (rnd_guard | rnd_round | rnd_sticky) fflags <= fflags | 5'b00001;
                            end
                        end
                    end
                end else begin
                    // Double precision add/sub
                    if (a_d_is_nan || b_d_is_nan) begin
                        result <= QNAN_D;
                        if (a_d_is_snan || b_d_is_snan) fflags <= 5'b10000;
                    end else begin
                        op_a_sign = a_d_sign;
                        op_b_sign = (op == FSUB) ? ~b_d_sign : b_d_sign;
                        op_a_exp = a_d_is_sub ? 13'd1 : {2'b0, a_d_exp};
                        op_b_exp = b_d_is_sub ? 13'd1 : {2'b0, b_d_exp};
                        op_a_frac = {a_d_is_sub ? 1'b0 : 1'b1, a_d_frac};
                        op_b_frac = {b_d_is_sub ? 1'b0 : 1'b1, b_d_frac};

                        if (a_d_is_inf && b_d_is_inf) begin
                            if (op_a_sign != op_b_sign) begin
                                result <= QNAN_D; fflags <= 5'b10000;
                            end else
                                result <= {op_a_sign, 11'h7FF, 52'b0};
                        end else if (a_d_is_inf)
                            result <= {op_a_sign, 11'h7FF, 52'b0};
                        else if (b_d_is_inf)
                            result <= {op_b_sign, 11'h7FF, 52'b0};
                        else if (a_d_is_zero && b_d_is_zero) begin
                            result <= {op_a_sign & op_b_sign, 63'b0};
                        end else begin
                            // Use res_frac[54:0] with 2 extra bits: [54]=carry, [53]=hidden, [52:1]=fraction, [0]=guard
                            // Shift mantissas left by 1 to make room for round position in sticky
                            rnd_sticky = 0;
                            res_frac = {1'b0, op_a_frac, 1'b0};  // 55 bits: [53]=hidden, [52:1]=frac, [0]=0
                            mul_prod[54:0] = {1'b0, op_b_frac, 1'b0};
                            if (op_a_exp < op_b_exp) begin
                                exp_diff = op_b_exp - op_a_exp;
                                if (exp_diff > 54) begin
                                    rnd_sticky = (op_a_frac != 0);
                                    res_frac = 0;
                                end else begin
                                    for (k = 0; k < 54; k = k + 1)
                                        if (k < exp_diff)
                                            rnd_sticky = rnd_sticky | res_frac[k];
                                    res_frac = res_frac >> exp_diff;
                                end
                                res_exp = op_b_exp;
                            end else if (op_b_exp < op_a_exp) begin
                                exp_diff = op_a_exp - op_b_exp;
                                if (exp_diff > 54) begin
                                    rnd_sticky = (op_b_frac != 0);
                                    mul_prod[54:0] = 0;
                                end else begin
                                    for (k = 0; k < 54; k = k + 1)
                                        if (k < exp_diff)
                                            rnd_sticky = rnd_sticky | mul_prod[k];
                                    mul_prod[54:0] = mul_prod[54:0] >> exp_diff;
                                end
                                res_exp = op_a_exp;
                            end else begin
                                res_exp = op_a_exp;
                            end

                            if (op_a_sign == op_b_sign) begin
                                res_sign = op_a_sign;
                                res_frac = res_frac + mul_prod[54:0];
                                if (res_frac[54]) begin
                                    rnd_sticky = rnd_sticky | res_frac[0];
                                    res_frac = res_frac >> 1;
                                    res_exp = res_exp + 1;
                                end
                            end else begin
                                if (res_frac > mul_prod[54:0]) begin
                                    res_sign = op_a_sign;
                                    res_frac = res_frac - mul_prod[54:0];
                                end else if (mul_prod[54:0] > res_frac) begin
                                    res_sign = op_b_sign;
                                    res_frac = mul_prod[54:0] - res_frac;
                                end else begin
                                    res_sign = op_a_sign & op_b_sign;
                                    res_frac = 0;
                                end
                                // Normalize left
                                if (res_frac == 0 && !rnd_sticky) begin
                                    res_exp = 0;
                                end else if (res_frac != 0) begin
                                    lz_count = 0;
                                    for (k = 54; k >= 0; k = k - 1)
                                        if (!res_frac[k] && lz_count == (54 - k))
                                            lz_count = lz_count + 1;
                                    // We want hidden bit at position 53
                                    if (lz_count > 1) begin
                                        lz_count = lz_count - 1;
                                        if (res_exp > lz_count) begin
                                            res_frac = res_frac << lz_count;
                                            res_exp = res_exp - {6'b0, lz_count};
                                        end else if (res_exp >= 1) begin
                                            res_frac = res_frac << (res_exp - 1);
                                            res_exp = 0;
                                        end
                                    end
                                end
                            end

                            // Round: hidden at [53], fraction at [52:1], guard at [0], sticky from rnd_sticky
                            if (res_exp >= 2047) begin
                                result <= {res_sign, 11'h7FF, 52'b0};
                                fflags <= 5'b00101;
                            end else if (res_exp == 0 && res_frac == 0 && !rnd_sticky) begin
                                result <= {res_sign, 63'b0};
                            end else begin
                                rnd_guard = res_frac[0];
                                rnd_round = rnd_sticky;
                                rnd_sticky = 0;
                                rnd_up = rnd_guard & (rnd_round | res_frac[1]);
                                rnd_frac_d = {1'b0, res_frac[52:1]} + rnd_up;
                                if (rnd_frac_d[52]) begin
                                    res_exp = res_exp + 1;
                                    if (res_exp >= 2047) begin
                                        result <= {res_sign, 11'h7FF, 52'b0};
                                        fflags <= 5'b00101;
                                    end else begin
                                        result <= {res_sign, res_exp[10:0], 52'b0};
                                    end
                                end else begin
                                    result <= {res_sign, res_exp[10:0], rnd_frac_d[51:0]};
                                end
                                if (rnd_guard | rnd_round) fflags <= fflags | 5'b00001;
                            end
                        end
                    end
                end
            end

            // ===================== FMUL =====================
            FMUL: begin
                if (single) begin
                    if (a_s_is_nan || b_s_is_nan) begin
                        result <= nanbox(QNAN_S);
                        if (a_s_is_snan || b_s_is_snan) fflags <= 5'b10000;
                    end else if (a_s_is_inf || b_s_is_inf) begin
                        if (a_s_is_zero || b_s_is_zero) begin
                            result <= nanbox(QNAN_S); fflags <= 5'b10000;
                        end else
                            result <= nanbox({a_s_sign ^ b_s_sign, 8'hFF, 23'b0});
                    end else if (a_s_is_zero || b_s_is_zero) begin
                        result <= nanbox({a_s_sign ^ b_s_sign, 31'b0});
                    end else begin
                        res_sign = a_s_sign ^ b_s_sign;
                        op_a_exp = a_s_is_sub ? 13'd1 : {5'b0, a_s_exp};
                        op_b_exp = b_s_is_sub ? 13'd1 : {5'b0, b_s_exp};
                        res_exp = op_a_exp + op_b_exp - 13'd127;
                        // 24x24 = 48-bit product (handle subnormal hidden bit = 0)
                        mul_prod = {~a_s_is_sub, a_s_frac} * {~b_s_is_sub, b_s_frac};
                        // Normalize: find leading 1 in product
                        lz_count = 0;
                        for (k = 47; k >= 0; k = k - 1)
                            if (!mul_prod[k] && lz_count == (47 - k))
                                lz_count = lz_count + 1;
                        if (lz_count >= 47) begin
                            // Product is zero or nearly zero
                            result <= nanbox({res_sign, 31'b0});
                        end else begin
                            mul_prod = mul_prod << lz_count;
                            res_exp = res_exp - {6'b0, lz_count} + 1;
                            // Now bit 47 is the hidden bit
                            rnd_guard = mul_prod[23];
                            rnd_round = mul_prod[22];
                            rnd_sticky = |mul_prod[21:0];
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | mul_prod[24]);
                            rnd_frac_s = {1'b0, mul_prod[46:24]} + rnd_up;
                            if (rnd_frac_s[23]) begin
                                res_exp = res_exp + 1;
                                rnd_frac_s = 0;
                            end
                            if (res_exp >= 255) begin
                                result <= nanbox({res_sign, 8'hFF, 23'b0});
                                fflags <= 5'b00101;
                            end else if (res_exp <= 0) begin
                                result <= nanbox({res_sign, 31'b0});
                                if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                            end else begin
                                result <= nanbox({res_sign, res_exp[7:0], rnd_frac_s[22:0]});
                            end
                            if (res_exp > 0 && res_exp < 255)
                                if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                        end
                    end
                end else begin
                    // Double FMUL
                    if (a_d_is_nan || b_d_is_nan) begin
                        result <= QNAN_D;
                        if (a_d_is_snan || b_d_is_snan) fflags <= 5'b10000;
                    end else if (a_d_is_inf || b_d_is_inf) begin
                        if (a_d_is_zero || b_d_is_zero) begin
                            result <= QNAN_D; fflags <= 5'b10000;
                        end else
                            result <= {a_d_sign ^ b_d_sign, 11'h7FF, 52'b0};
                    end else if (a_d_is_zero || b_d_is_zero) begin
                        result <= {a_d_sign ^ b_d_sign, 63'b0};
                    end else begin
                        res_sign = a_d_sign ^ b_d_sign;
                        op_a_exp = a_d_is_sub ? 13'd1 : {2'b0, a_d_exp};
                        op_b_exp = b_d_is_sub ? 13'd1 : {2'b0, b_d_exp};
                        res_exp = op_a_exp + op_b_exp - 13'd1023;
                        // 53x53 = 106-bit product
                        mul_prod = {1'b1, a_d_frac} * {1'b1, b_d_frac};
                        if (mul_prod[105]) begin
                            // Hidden at 105, fraction = [104:53], guard=[52], round=[51], sticky=|[50:0]
                            rnd_guard = mul_prod[52];
                            rnd_round = mul_prod[51];
                            rnd_sticky = |mul_prod[50:0];
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | mul_prod[53]);
                            rnd_frac_d = {1'b0, mul_prod[104:53]} + rnd_up;
                            res_exp = res_exp + 1;
                        end else begin
                            // Hidden at 104, fraction = [103:52], guard=[51], round=[50], sticky=|[49:0]
                            rnd_guard = mul_prod[51];
                            rnd_round = mul_prod[50];
                            rnd_sticky = |mul_prod[49:0];
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | mul_prod[52]);
                            rnd_frac_d = {1'b0, mul_prod[103:52]} + rnd_up;
                        end
                        if (rnd_frac_d[52]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_d = 0;
                        end
                        if (res_exp >= 2047) begin
                            result <= {res_sign, 11'h7FF, 52'b0};
                            fflags <= 5'b00101;
                        end else if (res_exp <= 0) begin
                            result <= {res_sign, 63'b0};
                        end else begin
                            result <= {res_sign, res_exp[10:0], rnd_frac_d[51:0]};
                        end
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= fflags | 5'b00001;
                    end
                end
            end

            // ===================== FDIV =====================
            FDIV: begin
                if (single) begin
                    if (a_s_is_nan || b_s_is_nan) begin
                        result <= nanbox(QNAN_S);
                        if (a_s_is_snan || b_s_is_snan) fflags <= 5'b10000;
                    end else if (a_s_is_inf && b_s_is_inf) begin
                        result <= nanbox(QNAN_S); fflags <= 5'b10000;
                    end else if (a_s_is_inf) begin
                        result <= nanbox({a_s_sign ^ b_s_sign, 8'hFF, 23'b0});
                    end else if (b_s_is_inf) begin
                        result <= nanbox({a_s_sign ^ b_s_sign, 31'b0});
                    end else if (b_s_is_zero) begin
                        if (a_s_is_zero) begin
                            result <= nanbox(QNAN_S); fflags <= 5'b10000;
                        end else begin
                            result <= nanbox({a_s_sign ^ b_s_sign, 8'hFF, 23'b0});
                            fflags <= 5'b01000;
                        end
                    end else if (a_s_is_zero) begin
                        result <= nanbox({a_s_sign ^ b_s_sign, 31'b0});
                    end else begin
                        res_sign = a_s_sign ^ b_s_sign;
                        op_a_exp = a_s_is_sub ? 13'd1 : {5'b0, a_s_exp};
                        op_b_exp = b_s_is_sub ? 13'd1 : {5'b0, b_s_exp};
                        res_exp = op_a_exp - op_b_exp + 13'd127;
                        // Compute 26 quotient bits for 23-bit fraction + guard + round
                        div_rem = {2'b0, 1'b1, a_s_frac, 29'b0};
                        div_divisor = {1'b1, b_s_frac, 29'b0};
                        div_quot = 0;
                        for (div_i = 25; div_i >= 0; div_i = div_i - 1) begin
                            if (div_rem >= {2'b0, div_divisor}) begin
                                div_rem = div_rem - {2'b0, div_divisor};
                                div_quot[div_i] = 1;
                            end
                            div_rem = div_rem << 1;
                        end
                        // Normalize: if div_quot[25], mantissa>=divisor so Q in [1,2)
                        // If !div_quot[25], Q in [0.5,1) so decrement exponent
                        if (div_quot[25]) begin
                            // Hidden at 25, fraction=[24:2], guard=[1], round=[0], sticky=(rem!=0)
                            rnd_guard = div_quot[1];
                            rnd_round = div_quot[0];
                            rnd_sticky = (div_rem != 0);
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | div_quot[2]);
                            rnd_frac_s = {1'b0, div_quot[24:2]} + rnd_up;
                        end else begin
                            // Hidden at 24, fraction=[23:1], guard=[0], round=0, sticky=(rem!=0)
                            rnd_guard = div_quot[0];
                            rnd_round = 0;
                            rnd_sticky = (div_rem != 0);
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | div_quot[1]);
                            rnd_frac_s = {1'b0, div_quot[23:1]} + rnd_up;
                            res_exp = res_exp - 1;
                        end
                        if (rnd_frac_s[23]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_s = 0;
                        end
                        if (res_exp >= 255) begin
                            result <= nanbox({res_sign, 8'hFF, 23'b0});
                            fflags <= 5'b00101;
                        end else if (res_exp <= 0) begin
                            result <= nanbox({res_sign, 31'b0});
                        end else begin
                            result <= nanbox({res_sign, res_exp[7:0], rnd_frac_s[22:0]});
                        end
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= fflags | 5'b00001;
                    end
                end else begin
                    // Double FDIV
                    if (a_d_is_nan || b_d_is_nan) begin
                        result <= QNAN_D;
                        if (a_d_is_snan || b_d_is_snan) fflags <= 5'b10000;
                    end else if (a_d_is_inf && b_d_is_inf) begin
                        result <= QNAN_D; fflags <= 5'b10000;
                    end else if (a_d_is_inf) begin
                        result <= {a_d_sign ^ b_d_sign, 11'h7FF, 52'b0};
                    end else if (b_d_is_inf) begin
                        result <= {a_d_sign ^ b_d_sign, 63'b0};
                    end else if (b_d_is_zero) begin
                        if (a_d_is_zero) begin
                            result <= QNAN_D; fflags <= 5'b10000;
                        end else begin
                            result <= {a_d_sign ^ b_d_sign, 11'h7FF, 52'b0};
                            fflags <= 5'b01000;
                        end
                    end else if (a_d_is_zero) begin
                        result <= {a_d_sign ^ b_d_sign, 63'b0};
                    end else begin
                        res_sign = a_d_sign ^ b_d_sign;
                        op_a_exp = a_d_is_sub ? 13'd1 : {2'b0, a_d_exp};
                        op_b_exp = b_d_is_sub ? 13'd1 : {2'b0, b_d_exp};
                        res_exp = op_a_exp - op_b_exp + 13'd1023;
                        // 55 quotient bits for 52-bit fraction + guard + round
                        div_rem = {2'b0, 1'b1, a_d_frac};
                        div_divisor = {1'b1, b_d_frac};
                        div_quot = 0;
                        for (div_i = 54; div_i >= 0; div_i = div_i - 1) begin
                            if (div_rem >= {2'b0, div_divisor}) begin
                                div_rem = div_rem - {2'b0, div_divisor};
                                div_quot[div_i] = 1;
                            end
                            div_rem = div_rem << 1;
                        end
                        if (div_quot[54]) begin
                            // Hidden at 54, fraction=[53:2], guard=[1], round=[0], sticky=(rem!=0)
                            rnd_guard = div_quot[1];
                            rnd_round = div_quot[0];
                            rnd_sticky = (div_rem != 0);
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | div_quot[2]);
                            rnd_frac_d = {1'b0, div_quot[53:2]} + rnd_up;
                        end else begin
                            // Hidden at 53, fraction=[52:1], guard=[0], round=0, sticky=(rem!=0)
                            rnd_guard = div_quot[0];
                            rnd_round = 0;
                            rnd_sticky = (div_rem != 0);
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | div_quot[1]);
                            rnd_frac_d = {1'b0, div_quot[52:1]} + rnd_up;
                            res_exp = res_exp - 1;
                        end
                        if (rnd_frac_d[52]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_d = 0;
                        end
                        if (res_exp >= 2047) begin
                            result <= {res_sign, 11'h7FF, 52'b0};
                            fflags <= 5'b00101;
                        end else if (res_exp <= 0) begin
                            result <= {res_sign, 63'b0};
                        end else begin
                            result <= {res_sign, res_exp[10:0], rnd_frac_d[51:0]};
                        end
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= fflags | 5'b00001;
                    end
                end
            end

            // ===================== FSQRT =====================
            FSQRT: begin
                if (single) begin
                    if (a_s_is_nan || (a_s_sign && !a_s_is_zero)) begin
                        result <= nanbox(QNAN_S);
                        fflags <= 5'b10000;
                    end else if (a_s_is_inf) begin
                        result <= nanbox(a_s);
                    end else if (a_s_is_zero) begin
                        result <= nanbox(a_s);
                    end else begin
                        op_a_exp = {5'b0, a_s_exp};
                        // Result exponent: (exp - bias) / 2 + bias
                        // For even biased (odd true): res_exp = (exp-1)/2 + bias = (exp + 2*bias - 1) / 2
                        // For odd biased (even true): res_exp = exp/2 + bias - bias/2...
                        // Simplified: res_exp = (op_a_exp + 127) / 2 for odd biased
                        //             res_exp = (op_a_exp + 126) / 2 for even biased
                        if (op_a_exp[0]) begin
                            // Odd biased exp → even true exp → sqrt(m), result exp = (biased+127)/2
                            res_exp = (op_a_exp + 13'd127) >> 1;
                            // Radicand: 0,1, frac[22], frac[21], ..., frac[0], zeros (52 bits = 26 pairs)
                            // Pair 0: {0,1}, Pair 1: {f22,f21}, ...
                            res_frac = {2'b01, a_s_frac, 28'b0}; // 53 bits used as radicand
                        end else begin
                            // Even biased exp → odd true exp → sqrt(2m), result exp = (biased+126)/2
                            res_exp = (op_a_exp + 13'd126) >> 1;
                            // Radicand: 1, frac[22], frac[21], ..., frac[0], 0, zeros (52 bits = 26 pairs)
                            // Pair 0: {1, f22}, Pair 1: {f21, f20}, ...
                            res_frac = {1'b1, a_s_frac, 29'b0}; // 53 bits
                        end
                        sqrt_rem = 0;
                        sqrt_root = 0;
                        for (sqrt_i = 25; sqrt_i >= 0; sqrt_i = sqrt_i - 1) begin
                            sqrt_rem = {sqrt_rem[54:0], res_frac[52:51]};
                            res_frac = res_frac << 2;
                            sqrt_trial = {sqrt_root[54:0], 2'b01};
                            if (sqrt_rem >= sqrt_trial) begin
                                sqrt_rem = sqrt_rem - sqrt_trial;
                                sqrt_root = {sqrt_root[53:0], 1'b1};
                            end else begin
                                sqrt_root = {sqrt_root[53:0], 1'b0};
                            end
                        end
                        // sqrt_root has 26 bits: hidden at [25], fraction=[24:2], guard=[1], round=[0]
                        rnd_guard = sqrt_root[1];
                        rnd_round = sqrt_root[0];
                        rnd_sticky = (sqrt_rem != 0);
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | sqrt_root[2]);
                        rnd_frac_s = {1'b0, sqrt_root[24:2]} + rnd_up;
                        if (rnd_frac_s[23]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_s = 0;
                        end
                        result <= nanbox({1'b0, res_exp[7:0], rnd_frac_s[22:0]});
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end
                end else begin
                    if (a_d_is_nan || (a_d_sign && !a_d_is_zero)) begin
                        result <= QNAN_D;
                        fflags <= 5'b10000;
                    end else if (a_d_is_inf) begin
                        result <= a;
                    end else if (a_d_is_zero) begin
                        result <= a;
                    end else begin
                        op_a_exp = {2'b0, a_d_exp};
                        if (op_a_exp[0]) begin
                            res_exp = (op_a_exp + 13'd1023) >> 1;
                            // Radicand needs 108 bits for 54 iterations (54 pairs)
                            // Use mul_prod as radicand: {01, frac[51:0], 54'b0} = 108 bits
                            mul_prod = {2'b01, a_d_frac, 54'b0};
                        end else begin
                            res_exp = (op_a_exp + 13'd1022) >> 1;
                            mul_prod = {1'b1, a_d_frac, 55'b0};
                        end
                        sqrt_rem = 0;
                        sqrt_root = 0;
                        for (sqrt_i = 54; sqrt_i >= 0; sqrt_i = sqrt_i - 1) begin
                            sqrt_rem = {sqrt_rem[54:0], mul_prod[107:106]};
                            mul_prod = mul_prod << 2;
                            sqrt_trial = {sqrt_root[54:0], 2'b01};
                            if (sqrt_rem >= sqrt_trial) begin
                                sqrt_rem = sqrt_rem - sqrt_trial;
                                sqrt_root = {sqrt_root[53:0], 1'b1};
                            end else begin
                                sqrt_root = {sqrt_root[53:0], 1'b0};
                            end
                        end
                        // 55 bits: hidden at [54], fraction=[53:2], guard=[1], round=[0]
                        rnd_guard = sqrt_root[1];
                        rnd_round = sqrt_root[0];
                        rnd_sticky = (sqrt_rem != 0);
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | sqrt_root[2]);
                        rnd_frac_d = {1'b0, sqrt_root[53:2]} + rnd_up;
                        if (rnd_frac_d[52]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_d = 0;
                        end
                        result <= {1'b0, res_exp[10:0], rnd_frac_d[51:0]};
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end
                end
            end

            // ===================== FMADD / FMSUB / FNMADD / FNMSUB =====================
            FMADD, FMSUB, FNMADD, FNMSUB: begin
                if (single) begin
                    if (a_s_is_nan || b_s_is_nan || c_s_is_nan) begin
                        result <= nanbox(QNAN_S);
                        if (a_s_is_snan || b_s_is_snan || c_s_is_snan) fflags <= 5'b10000;
                    end else if ((a_s_is_inf || b_s_is_inf) && (a_s_is_zero || b_s_is_zero)) begin
                        result <= nanbox(QNAN_S); fflags <= 5'b10000;
                    end else if (a_s_is_inf || b_s_is_inf) begin
                        res_sign = a_s_sign ^ b_s_sign;
                        if (op == FNMADD || op == FNMSUB) res_sign = ~res_sign;
                        if (c_s_is_inf) begin
                            op_c_sign = c_s_sign;
                            if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                            if (res_sign != op_c_sign) begin
                                result <= nanbox(QNAN_S); fflags <= 5'b10000;
                            end else
                                result <= nanbox({res_sign, 8'hFF, 23'b0});
                        end else
                            result <= nanbox({res_sign, 8'hFF, 23'b0});
                    end else if (c_s_is_inf) begin
                        op_c_sign = c_s_sign;
                        if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                        result <= nanbox({op_c_sign, 8'hFF, 23'b0});
                    end else begin
                        // Multiply a*b
                        res_sign = a_s_sign ^ b_s_sign;
                        if (op == FNMADD || op == FNMSUB) res_sign = ~res_sign;
                        if (a_s_is_zero || b_s_is_zero) begin
                            op_c_sign = c_s_sign;
                            if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                            if (c_s_is_zero)
                                result <= nanbox({res_sign & op_c_sign, 31'b0});
                            else
                                result <= nanbox({op_c_sign, c_s_exp, c_s_frac});
                        end else begin
                            op_a_exp = a_s_is_sub ? 13'd1 : {5'b0, a_s_exp};
                            op_b_exp = b_s_is_sub ? 13'd1 : {5'b0, b_s_exp};
                            res_exp = op_a_exp + op_b_exp - 13'd127;
                            // 24x24 = 48-bit product
                            mul_prod = {1'b1, a_s_frac} * {1'b1, b_s_frac};
                            // Normalize product into res_frac[52:0] format (hidden at 52)
                            if (mul_prod[47]) begin
                                res_frac = {mul_prod[47:0], 5'b0};
                                res_exp = res_exp + 1;
                            end else begin
                                res_frac = {mul_prod[46:0], 6'b0};
                            end
                            // res_frac now has hidden bit at 52, fraction at [51:29], tail at [28:0]

                            // Add/subtract c
                            op_c_sign = c_s_sign;
                            if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                            rnd_sticky = 0;

                            if (!c_s_is_zero) begin
                                op_c_exp = c_s_is_sub ? 13'd1 : {5'b0, c_s_exp};
                                op_c_frac = {c_s_is_sub ? 1'b0 : 1'b1, c_s_frac, 29'b0};
                                // Align exponents
                                if (res_exp < op_c_exp) begin
                                    exp_diff = op_c_exp - res_exp;
                                    if (exp_diff > 53) begin
                                        rnd_sticky = (res_frac != 0);
                                        res_frac = 0;
                                    end else begin
                                        for (k = 0; k < 53; k = k + 1)
                                            if (k < exp_diff) rnd_sticky = rnd_sticky | res_frac[k];
                                        res_frac = res_frac >> exp_diff;
                                    end
                                    res_exp = op_c_exp;
                                end else if (res_exp > op_c_exp) begin
                                    exp_diff = res_exp - op_c_exp;
                                    if (exp_diff > 53) begin
                                        rnd_sticky = (op_c_frac != 0);
                                        op_c_frac = 0;
                                    end else begin
                                        for (k = 0; k < 53; k = k + 1)
                                            if (k < exp_diff) rnd_sticky = rnd_sticky | op_c_frac[k];
                                        op_c_frac = op_c_frac >> exp_diff;
                                    end
                                end

                                if (res_sign == op_c_sign) begin
                                    res_frac = {1'b0, res_frac[52:0]} + {1'b0, op_c_frac};
                                    if (res_frac[53]) begin
                                        rnd_sticky = rnd_sticky | res_frac[0];
                                        res_frac = res_frac >> 1;
                                        res_exp = res_exp + 1;
                                    end
                                end else begin
                                    if ({1'b0, res_frac[52:0]} > {1'b0, op_c_frac}) begin
                                        res_frac = res_frac[52:0] - op_c_frac;
                                    end else if (op_c_frac > res_frac[52:0]) begin
                                        res_frac = op_c_frac - res_frac[52:0];
                                        res_sign = op_c_sign;
                                    end else begin
                                        res_frac = 0;
                                        res_sign = res_sign & op_c_sign;
                                    end
                                    // Normalize
                                    if (res_frac != 0) begin
                                        lz_count = 0;
                                        for (k = 52; k >= 0; k = k - 1)
                                            if (!res_frac[k] && lz_count == (52 - k))
                                                lz_count = lz_count + 1;
                                        if (lz_count > 0 && res_exp > lz_count) begin
                                            res_frac = res_frac << lz_count;
                                            res_exp = res_exp - lz_count;
                                        end else if (lz_count > 0 && res_exp >= 1) begin
                                            res_frac = res_frac << (res_exp - 1);
                                            res_exp = 0;
                                        end
                                    end
                                end
                            end

                            // Round and pack
                            if (res_exp >= 255) begin
                                result <= nanbox({res_sign, 8'hFF, 23'b0});
                                fflags <= 5'b00101;
                            end else if (res_exp == 0 && res_frac == 0 && !rnd_sticky) begin
                                result <= nanbox({res_sign, 31'b0});
                            end else begin
                                rnd_guard = res_frac[28];
                                rnd_round = res_frac[27];
                                rnd_sticky = rnd_sticky | (|res_frac[26:0]);
                                rnd_up = rnd_guard & (rnd_round | rnd_sticky | res_frac[29]);
                                rnd_frac_s = {1'b0, res_frac[51:29]} + rnd_up;
                                if (rnd_frac_s[23]) begin
                                    res_exp = res_exp + 1;
                                    if (res_exp >= 255) begin
                                        result <= nanbox({res_sign, 8'hFF, 23'b0});
                                        fflags <= 5'b00101;
                                    end else
                                        result <= nanbox({res_sign, res_exp[7:0], 23'b0});
                                end else begin
                                    result <= nanbox({res_sign, res_exp[7:0], rnd_frac_s[22:0]});
                                end
                                if (rnd_guard | rnd_round | rnd_sticky) fflags <= fflags | 5'b00001;
                            end
                        end
                    end
                end else begin
                    // Double FMADD/FMSUB/FNMADD/FNMSUB
                    if (a_d_is_nan || b_d_is_nan || c_d_is_nan) begin
                        result <= QNAN_D;
                        if (a_d_is_snan || b_d_is_snan || c_d_is_snan) fflags <= 5'b10000;
                    end else if ((a_d_is_inf || b_d_is_inf) && (a_d_is_zero || b_d_is_zero)) begin
                        result <= QNAN_D; fflags <= 5'b10000;
                    end else if (a_d_is_inf || b_d_is_inf) begin
                        res_sign = a_d_sign ^ b_d_sign;
                        if (op == FNMADD || op == FNMSUB) res_sign = ~res_sign;
                        if (c_d_is_inf) begin
                            op_c_sign = c_d_sign;
                            if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                            if (res_sign != op_c_sign) begin
                                result <= QNAN_D; fflags <= 5'b10000;
                            end else
                                result <= {res_sign, 11'h7FF, 52'b0};
                        end else
                            result <= {res_sign, 11'h7FF, 52'b0};
                    end else if (c_d_is_inf) begin
                        op_c_sign = c_d_sign;
                        if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                        result <= {op_c_sign, 11'h7FF, 52'b0};
                    end else begin
                        res_sign = a_d_sign ^ b_d_sign;
                        if (op == FNMADD || op == FNMSUB) res_sign = ~res_sign;
                        if (a_d_is_zero || b_d_is_zero) begin
                            op_c_sign = c_d_sign;
                            if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                            if (c_d_is_zero)
                                result <= {res_sign & op_c_sign, 63'b0};
                            else
                                result <= {op_c_sign, c_d_exp, c_d_frac};
                        end else begin
                            op_a_exp = a_d_is_sub ? 13'd1 : {2'b0, a_d_exp};
                            op_b_exp = b_d_is_sub ? 13'd1 : {2'b0, b_d_exp};
                            res_exp = op_a_exp + op_b_exp - 13'd1023;
                            mul_prod = {1'b1, a_d_frac} * {1'b1, b_d_frac};
                            // 53x53=106 bits. Normalize into 53-bit res_frac with hidden at 52
                            rnd_sticky = 0;
                            if (mul_prod[105]) begin
                                rnd_sticky = |mul_prod[51:0];
                                res_frac = mul_prod[105:53];
                                res_exp = res_exp + 1;
                            end else begin
                                rnd_sticky = |mul_prod[50:0];
                                res_frac = mul_prod[104:52];
                            end

                            op_c_sign = c_d_sign;
                            if (op == FMSUB || op == FNMADD) op_c_sign = ~op_c_sign;
                            if (!c_d_is_zero) begin
                                op_c_exp = c_d_is_sub ? 13'd1 : {2'b0, c_d_exp};
                                op_c_frac = {c_d_is_sub ? 1'b0 : 1'b1, c_d_frac};
                                if (res_exp < op_c_exp) begin
                                    exp_diff = op_c_exp - res_exp;
                                    if (exp_diff > 53) begin
                                        rnd_sticky = rnd_sticky | (res_frac != 0);
                                        res_frac = 0;
                                    end else begin
                                        for (k = 0; k < 53; k = k + 1)
                                            if (k < exp_diff) rnd_sticky = rnd_sticky | res_frac[k];
                                        res_frac = res_frac >> exp_diff;
                                    end
                                    res_exp = op_c_exp;
                                end else if (res_exp > op_c_exp) begin
                                    exp_diff = res_exp - op_c_exp;
                                    if (exp_diff > 53) begin
                                        rnd_sticky = rnd_sticky | (op_c_frac != 0);
                                        op_c_frac = 0;
                                    end else begin
                                        for (k = 0; k < 53; k = k + 1)
                                            if (k < exp_diff) rnd_sticky = rnd_sticky | op_c_frac[k];
                                        op_c_frac = op_c_frac >> exp_diff;
                                    end
                                end

                                if (res_sign == op_c_sign) begin
                                    res_frac = {1'b0, res_frac[52:0]} + {1'b0, op_c_frac};
                                    if (res_frac[53]) begin
                                        rnd_sticky = rnd_sticky | res_frac[0];
                                        res_frac = res_frac >> 1;
                                        res_exp = res_exp + 1;
                                    end
                                end else begin
                                    if (res_frac[52:0] > op_c_frac) begin
                                        res_frac = res_frac[52:0] - op_c_frac;
                                    end else if (op_c_frac > res_frac[52:0]) begin
                                        res_frac = op_c_frac - res_frac[52:0];
                                        res_sign = op_c_sign;
                                    end else begin
                                        res_frac = 0;
                                        res_sign = res_sign & op_c_sign;
                                    end
                                    if (res_frac != 0) begin
                                        lz_count = 0;
                                        for (k = 52; k >= 0; k = k - 1)
                                            if (!res_frac[k] && lz_count == (52 - k))
                                                lz_count = lz_count + 1;
                                        if (lz_count > 0 && res_exp > lz_count) begin
                                            res_frac = res_frac << lz_count;
                                            res_exp = res_exp - lz_count;
                                        end else if (lz_count > 0 && res_exp >= 1) begin
                                            res_frac = res_frac << (res_exp - 1);
                                            res_exp = 0;
                                        end
                                    end
                                end
                            end

                            if (res_exp >= 2047) begin
                                result <= {res_sign, 11'h7FF, 52'b0};
                                fflags <= 5'b00101;
                            end else if (res_exp == 0 && res_frac == 0 && !rnd_sticky) begin
                                result <= {res_sign, 63'b0};
                            end else begin
                                rnd_up = rnd_sticky & res_frac[0];
                                rnd_frac_d = {1'b0, res_frac[51:0]} + rnd_up;
                                if (rnd_frac_d[52]) begin
                                    res_exp = res_exp + 1;
                                    if (res_exp >= 2047) begin
                                        result <= {res_sign, 11'h7FF, 52'b0};
                                        fflags <= 5'b00101;
                                    end else
                                        result <= {res_sign, res_exp[10:0], 52'b0};
                                end else begin
                                    result <= {res_sign, res_exp[10:0], rnd_frac_d[51:0]};
                                end
                                if (rnd_sticky) fflags <= fflags | 5'b00001;
                            end
                        end
                    end
                end
            end

            // ===================== FCVT float-to-int =====================
            FCVT_W: begin
                if ((single && a_s_is_nan) || (!single && a_d_is_nan)) begin
                    result <= 64'h000000007FFFFFFF;
                    fflags <= 5'b10000;
                end else begin
                    if (single) begin
                        if (a_s_is_zero) begin
                            result <= 64'b0;
                        end else if (a_s_is_inf) begin
                            result <= a_s_sign ? 64'hFFFFFFFF80000000 : 64'h000000007FFFFFFF;
                            fflags <= 5'b10000;
                        end else begin
                            op_a_exp = {5'b0, a_s_exp};
                            op_a_frac = {1'b1, a_s_frac, 29'b0};
                            if (op_a_exp >= 127 + 31) begin
                                result <= a_s_sign ? 64'hFFFFFFFF80000000 : 64'h000000007FFFFFFF;
                                fflags <= 5'b10000;
                            end else if (op_a_exp < 127) begin
                                // Value is < 1.0, rounds to 0 with RTZ
                                result <= 64'b0;
                                fflags <= 5'b00001;
                            end else begin
                                temp_result = op_a_frac >> (127 + 52 - op_a_exp);
                                if ((temp_result << (127 + 52 - op_a_exp)) != {11'b0, op_a_frac})
                                    fflags <= 5'b00001;
                                if (a_s_sign) temp_result = ~temp_result + 1;
                                result <= {{32{temp_result[31]}}, temp_result[31:0]};
                            end
                        end
                    end else begin
                        if (a_d_is_zero) begin
                            result <= 64'b0;
                        end else if (a_d_is_inf) begin
                            result <= a_d_sign ? 64'hFFFFFFFF80000000 : 64'h000000007FFFFFFF;
                            fflags <= 5'b10000;
                        end else begin
                            op_a_exp = {2'b0, a_d_exp};
                            op_a_frac = {1'b1, a_d_frac};
                            if (op_a_exp >= 1023 + 31) begin
                                result <= a_d_sign ? 64'hFFFFFFFF80000000 : 64'h000000007FFFFFFF;
                                fflags <= 5'b10000;
                            end else if (op_a_exp < 1023) begin
                                result <= 64'b0;
                                fflags <= 5'b00001;
                            end else begin
                                temp_result = op_a_frac >> (1023 + 52 - op_a_exp);
                                if ((temp_result << (1023 + 52 - op_a_exp)) != {11'b0, op_a_frac})
                                    fflags <= 5'b00001;
                                if (a_d_sign) temp_result = ~temp_result + 1;
                                result <= {{32{temp_result[31]}}, temp_result[31:0]};
                            end
                        end
                    end
                end
            end

            FCVT_WU: begin
                if ((single && a_s_is_nan) || (!single && a_d_is_nan)) begin
                    result <= 64'hFFFFFFFFFFFFFFFF;
                    fflags <= 5'b10000;
                end else begin
                    if (single) begin
                        if (a_s_is_zero) begin
                            result <= 64'b0;
                        end else if (a_s_sign) begin
                            if ({5'b0, a_s_exp} < 127) begin
                                result <= 64'b0;
                                fflags <= 5'b00001;
                            end else begin
                                result <= 64'b0;
                                fflags <= 5'b10000;
                            end
                        end else if (a_s_is_inf) begin
                            result <= 64'hFFFFFFFFFFFFFFFF;
                            fflags <= 5'b10000;
                        end else begin
                            op_a_exp = {5'b0, a_s_exp};
                            op_a_frac = {1'b1, a_s_frac, 29'b0};
                            if (op_a_exp >= 127 + 32) begin
                                result <= 64'hFFFFFFFFFFFFFFFF;
                                fflags <= 5'b10000;
                            end else if (op_a_exp < 127) begin
                                result <= 64'b0;
                                fflags <= 5'b00001;
                            end else begin
                                temp_result = op_a_frac >> (127 + 52 - op_a_exp);
                                result <= {{32{temp_result[31]}}, temp_result[31:0]};
                                if ((temp_result << (127 + 52 - op_a_exp)) != {11'b0, op_a_frac})
                                    fflags <= 5'b00001;
                            end
                        end
                    end else begin
                        if (a_d_is_zero) begin
                            result <= 64'b0;
                        end else if (a_d_sign) begin
                            if ({2'b0, a_d_exp} < 1023) begin
                                result <= 64'b0;
                                fflags <= 5'b00001;
                            end else begin
                                result <= 64'b0;
                                fflags <= 5'b10000;
                            end
                        end else if (a_d_is_inf) begin
                            result <= 64'hFFFFFFFFFFFFFFFF;
                            fflags <= 5'b10000;
                        end else begin
                            op_a_exp = {2'b0, a_d_exp};
                            op_a_frac = {1'b1, a_d_frac};
                            if (op_a_exp >= 1023 + 32) begin
                                result <= 64'hFFFFFFFFFFFFFFFF;
                                fflags <= 5'b10000;
                            end else if (op_a_exp < 1023) begin
                                result <= 64'b0;
                                fflags <= 5'b00001;
                            end else begin
                                temp_result = op_a_frac >> (1023 + 52 - op_a_exp);
                                result <= {{32{temp_result[31]}}, temp_result[31:0]};
                                if ((temp_result << (1023 + 52 - op_a_exp)) != {11'b0, op_a_frac})
                                    fflags <= 5'b00001;
                            end
                        end
                    end
                end
            end

            FCVT_L: begin
                if ((single && a_s_is_nan) || (!single && a_d_is_nan)) begin
                    result <= 64'h7FFFFFFFFFFFFFFF;
                    fflags <= 5'b10000;
                end else begin
                    if (single) begin
                        if (a_s_is_zero) result <= 64'b0;
                        else if (a_s_is_inf || {5'b0, a_s_exp} >= 127 + 63) begin
                            result <= a_s_sign ? 64'h8000000000000000 : 64'h7FFFFFFFFFFFFFFF;
                            fflags <= 5'b10000;
                        end else if ({5'b0, a_s_exp} < 127) begin
                            result <= 64'b0;
                            fflags <= 5'b00001;
                        end else begin
                            op_a_exp = {5'b0, a_s_exp};
                            temp_result = {1'b1, a_s_frac, 40'b0} >> (127 + 63 - op_a_exp);
                            if (({1'b1, a_s_frac, 40'b0}) != (temp_result << (127 + 63 - op_a_exp)))
                                fflags <= 5'b00001;
                            if (a_s_sign) temp_result = ~temp_result + 1;
                            result <= temp_result;
                        end
                    end else begin
                        if (a_d_is_zero) result <= 64'b0;
                        else if (a_d_is_inf || {2'b0, a_d_exp} >= 1023 + 63) begin
                            result <= a_d_sign ? 64'h8000000000000000 : 64'h7FFFFFFFFFFFFFFF;
                            fflags <= 5'b10000;
                        end else if ({2'b0, a_d_exp} < 1023) begin
                            result <= 64'b0;
                            fflags <= 5'b00001;
                        end else begin
                            op_a_exp = {2'b0, a_d_exp};
                            temp_result = {1'b1, a_d_frac, 11'b0} >> (1023 + 63 - op_a_exp);
                            if (({1'b1, a_d_frac, 11'b0}) != (temp_result << (1023 + 63 - op_a_exp)))
                                fflags <= 5'b00001;
                            if (a_d_sign) temp_result = ~temp_result + 1;
                            result <= temp_result;
                        end
                    end
                end
            end

            FCVT_LU: begin
                if ((single && a_s_is_nan) || (!single && a_d_is_nan)) begin
                    result <= 64'hFFFFFFFFFFFFFFFF;
                    fflags <= 5'b10000;
                end else begin
                    if (single) begin
                        if (a_s_is_zero) result <= 64'b0;
                        else if (a_s_sign) begin
                            if ({5'b0, a_s_exp} < 127) begin
                                result <= 64'b0; fflags <= 5'b00001;
                            end else begin
                                result <= 64'b0; fflags <= 5'b10000;
                            end
                        end else if (a_s_is_inf || {5'b0, a_s_exp} >= 127 + 64) begin
                            result <= 64'hFFFFFFFFFFFFFFFF; fflags <= 5'b10000;
                        end else if ({5'b0, a_s_exp} < 127) begin
                            result <= 64'b0; fflags <= 5'b00001;
                        end else begin
                            op_a_exp = {5'b0, a_s_exp};
                            temp_result = {1'b1, a_s_frac, 40'b0} >> (127 + 63 - op_a_exp);
                            result <= temp_result;
                            if (({1'b1, a_s_frac, 40'b0}) != (temp_result << (127 + 63 - op_a_exp)))
                                fflags <= 5'b00001;
                        end
                    end else begin
                        if (a_d_is_zero) result <= 64'b0;
                        else if (a_d_sign) begin
                            if ({2'b0, a_d_exp} < 1023) begin
                                result <= 64'b0; fflags <= 5'b00001;
                            end else begin
                                result <= 64'b0; fflags <= 5'b10000;
                            end
                        end else if (a_d_is_inf || {2'b0, a_d_exp} >= 1023 + 64) begin
                            result <= 64'hFFFFFFFFFFFFFFFF; fflags <= 5'b10000;
                        end else if ({2'b0, a_d_exp} < 1023) begin
                            result <= 64'b0; fflags <= 5'b00001;
                        end else begin
                            op_a_exp = {2'b0, a_d_exp};
                            temp_result = {1'b1, a_d_frac, 11'b0} >> (1023 + 63 - op_a_exp);
                            result <= temp_result;
                            if (({1'b1, a_d_frac, 11'b0}) != (temp_result << (1023 + 63 - op_a_exp)))
                                fflags <= 5'b00001;
                        end
                    end
                end
            end

            // ===================== FCVT int-to-float =====================
            FCVT_FROM_W: begin
                if (a[31:0] == 32'b0) begin
                    result <= single ? nanbox(32'b0) : 64'b0;
                end else begin
                    res_sign = a[31];
                    temp_result = res_sign ? {32'b0, (~a[31:0]) + 32'b1} : {32'b0, a[31:0]};
                    lz_count = 0;
                    for (k = 63; k >= 0; k = k - 1)
                        if (!temp_result[k] && lz_count == (63 - k))
                            lz_count = lz_count + 1;
                    res_exp = (single ? 13'd127 : 13'd1023) + 63 - lz_count;
                    temp_result = temp_result << lz_count;
                    if (single) begin
                        // Round: fraction=[62:40](23 bits), guard=[39], round=[38], sticky=|[37:0]
                        rnd_guard = temp_result[39];
                        rnd_round = temp_result[38];
                        rnd_sticky = |temp_result[37:0];
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | temp_result[40]);
                        rnd_frac_s = {1'b0, temp_result[62:40]} + rnd_up;
                        if (rnd_frac_s[23]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_s = 0;
                        end
                        result <= nanbox({res_sign, res_exp[7:0], rnd_frac_s[22:0]});
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end else
                        result <= {res_sign, res_exp[10:0], temp_result[62:11]};
                end
            end

            FCVT_FROM_WU: begin
                if (a[31:0] == 32'b0) begin
                    result <= single ? nanbox(32'b0) : 64'b0;
                end else begin
                    temp_result = {32'b0, a[31:0]};
                    lz_count = 0;
                    for (k = 63; k >= 0; k = k - 1)
                        if (!temp_result[k] && lz_count == (63 - k))
                            lz_count = lz_count + 1;
                    res_exp = (single ? 13'd127 : 13'd1023) + 63 - lz_count;
                    temp_result = temp_result << lz_count;
                    if (single) begin
                        rnd_guard = temp_result[39];
                        rnd_round = temp_result[38];
                        rnd_sticky = |temp_result[37:0];
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | temp_result[40]);
                        rnd_frac_s = {1'b0, temp_result[62:40]} + rnd_up;
                        if (rnd_frac_s[23]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_s = 0;
                        end
                        result <= nanbox({1'b0, res_exp[7:0], rnd_frac_s[22:0]});
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end else
                        result <= {1'b0, res_exp[10:0], temp_result[62:11]};
                end
            end

            FCVT_FROM_L: begin
                if (a == 64'b0) begin
                    result <= single ? nanbox(32'b0) : 64'b0;
                end else begin
                    res_sign = a[63];
                    temp_result = res_sign ? (~a + 1) : a;
                    lz_count = 0;
                    for (k = 63; k >= 0; k = k - 1)
                        if (!temp_result[k] && lz_count == (63 - k))
                            lz_count = lz_count + 1;
                    res_exp = (single ? 13'd127 : 13'd1023) + 63 - lz_count;
                    temp_result = temp_result << lz_count;
                    if (single) begin
                        rnd_guard = temp_result[39];
                        rnd_round = temp_result[38];
                        rnd_sticky = |temp_result[37:0];
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | temp_result[40]);
                        rnd_frac_s = {1'b0, temp_result[62:40]} + rnd_up;
                        if (rnd_frac_s[23]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_s = 0;
                        end
                        result <= nanbox({res_sign, res_exp[7:0], rnd_frac_s[22:0]});
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end else begin
                        // Double: fraction=[62:11](52 bits), guard=[10], round=[9], sticky=|[8:0]
                        rnd_guard = temp_result[10];
                        rnd_round = temp_result[9];
                        rnd_sticky = |temp_result[8:0];
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | temp_result[11]);
                        rnd_frac_d = {1'b0, temp_result[62:11]} + rnd_up;
                        if (rnd_frac_d[52]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_d = 0;
                        end
                        result <= {res_sign, res_exp[10:0], rnd_frac_d[51:0]};
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end
                end
            end

            FCVT_FROM_LU: begin
                if (a == 64'b0) begin
                    result <= single ? nanbox(32'b0) : 64'b0;
                end else begin
                    temp_result = a;
                    lz_count = 0;
                    for (k = 63; k >= 0; k = k - 1)
                        if (!temp_result[k] && lz_count == (63 - k))
                            lz_count = lz_count + 1;
                    res_exp = (single ? 13'd127 : 13'd1023) + 63 - lz_count;
                    temp_result = temp_result << lz_count;
                    if (single) begin
                        rnd_guard = temp_result[39];
                        rnd_round = temp_result[38];
                        rnd_sticky = |temp_result[37:0];
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | temp_result[40]);
                        rnd_frac_s = {1'b0, temp_result[62:40]} + rnd_up;
                        if (rnd_frac_s[23]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_s = 0;
                        end
                        result <= nanbox({1'b0, res_exp[7:0], rnd_frac_s[22:0]});
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end else begin
                        rnd_guard = temp_result[10];
                        rnd_round = temp_result[9];
                        rnd_sticky = |temp_result[8:0];
                        rnd_up = rnd_guard & (rnd_round | rnd_sticky | temp_result[11]);
                        rnd_frac_d = {1'b0, temp_result[62:11]} + rnd_up;
                        if (rnd_frac_d[52]) begin
                            res_exp = res_exp + 1;
                            rnd_frac_d = 0;
                        end
                        result <= {1'b0, res_exp[10:0], rnd_frac_d[51:0]};
                        if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                    end
                end
            end

            // ===================== FCVT between float formats =====================
            FCVT_SD: begin
                if (single) begin
                    // FCVT.S.D: double -> single
                    if (a_d_is_nan) begin
                        result <= nanbox(QNAN_S);
                        if (a_d_is_snan) fflags <= 5'b10000;
                    end else if (a_d_is_inf)
                        result <= nanbox({a_d_sign, 8'hFF, 23'b0});
                    else if (a_d_is_zero)
                        result <= nanbox({a_d_sign, 31'b0});
                    else begin
                        op_a_exp = {2'b0, a_d_exp};
                        res_exp = op_a_exp - 1023 + 127;
                        if (res_exp >= 255) begin
                            result <= nanbox({a_d_sign, 8'hFF, 23'b0});
                            fflags <= 5'b00101;
                        end else if (res_exp <= 0) begin
                            // Subnormal result: shift mantissa right by (1 - res_exp)
                            exp_diff = 1 - res_exp;
                            if (exp_diff > 25) begin
                                result <= nanbox({a_d_sign, 31'b0});
                                fflags <= 5'b00001;
                            end else begin
                                // Build 25-bit value: {1, frac[51:29]} = 24 bits, plus guard
                                // We need to shift {1, d_frac[51:29], d_frac[28]} right by exp_diff
                                // Use temp_result to hold the shifted mantissa
                                temp_result = {39'b0, 1'b1, a_d_frac[51:29], 1'b0};
                                rnd_sticky = |a_d_frac[27:0];
                                // Accumulate sticky from bits shifted out
                                for (k = 0; k < 25; k = k + 1)
                                    if (k < exp_diff)
                                        rnd_sticky = rnd_sticky | temp_result[k];
                                temp_result = temp_result >> exp_diff;
                                // Now temp_result[23:1] = subnormal fraction, [0] = guard
                                rnd_guard = temp_result[0];
                                rnd_round = rnd_sticky;
                                rnd_sticky = 0;
                                rnd_up = rnd_guard & (rnd_round | temp_result[1]);
                                rnd_frac_s = {1'b0, temp_result[23:1]} + rnd_up;
                                if (rnd_frac_s[23]) begin
                                    // Rounded up to normal
                                    result <= nanbox({a_d_sign, 8'd1, 23'b0});
                                end else begin
                                    result <= nanbox({a_d_sign, 8'b0, rnd_frac_s[22:0]});
                                end
                                fflags <= 5'b00001;
                            end
                        end else begin
                            // Round: fraction=a_d_frac[51:29](23 bits), guard=[28], round=[27], sticky=|[26:0]
                            rnd_guard = a_d_frac[28];
                            rnd_round = a_d_frac[27];
                            rnd_sticky = |a_d_frac[26:0];
                            rnd_up = rnd_guard & (rnd_round | rnd_sticky | a_d_frac[29]);
                            rnd_frac_s = {1'b0, a_d_frac[51:29]} + rnd_up;
                            if (rnd_frac_s[23]) begin
                                res_exp = res_exp + 1;
                                if (res_exp >= 255) begin
                                    result <= nanbox({a_d_sign, 8'hFF, 23'b0});
                                    fflags <= 5'b00101;
                                end else
                                    result <= nanbox({a_d_sign, res_exp[7:0], 23'b0});
                            end else begin
                                result <= nanbox({a_d_sign, res_exp[7:0], rnd_frac_s[22:0]});
                            end
                            if (rnd_guard | rnd_round | rnd_sticky) fflags <= 5'b00001;
                        end
                    end
                end else begin
                    // FCVT.D.S: single -> double (exact, no rounding needed)
                    if (a_s_is_nan) begin
                        result <= QNAN_D;
                        if (a_s_is_snan) fflags <= 5'b10000;
                    end else if (a_s_is_inf)
                        result <= {a_s_sign, 11'h7FF, 52'b0};
                    else if (a_s_is_zero)
                        result <= {a_s_sign, 63'b0};
                    else begin
                        op_a_exp = {5'b0, a_s_exp};
                        res_exp = op_a_exp - 127 + 1023;
                        result <= {a_s_sign, res_exp[10:0], a_s_frac, 29'b0};
                    end
                end
            end

            default: begin
                result <= 64'b0;
            end
        endcase
    end else begin
        done <= 0;
    end
end

endmodule
