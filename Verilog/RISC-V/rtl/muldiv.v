module muldiv (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [3:0]  op,
    input  wire        is_word_op,
    output reg  [63:0] result,
    output reg         done,
    output wire        busy
);

localparam MUL    = 4'b0000;
localparam MULH   = 4'b0001;
localparam MULHSU = 4'b0010;
localparam MULHU  = 4'b0011;
localparam DIV_OP = 4'b0100;
localparam DIVU   = 4'b0101;
localparam REM_OP = 4'b0110;
localparam REMU   = 4'b0111;

assign busy = 0;

// Working registers for W-variants
reg [31:0] a_w, b_w;
reg [63:0] mul_w;
reg [31:0] div_s_w, div_u_w, rem_s_w, rem_u_w;

// Working registers for 64-bit ops
reg signed [127:0] mul_ss;
reg [127:0] mul_uu, mul_su;
reg [63:0] div_s, div_u, rem_s, rem_u;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done   <= 0;
        result <= 64'b0;
    end else if (start) begin
        done <= 1;
        if (is_word_op) begin
            a_w = a[31:0];
            b_w = b[31:0];
            mul_w = {32'b0, a_w} * {32'b0, b_w};

            if (b_w == 32'b0) begin
                div_s_w = 32'hFFFFFFFF;
                div_u_w = 32'hFFFFFFFF;
                rem_s_w = a_w;
                rem_u_w = a_w;
            end else if (a_w == 32'h80000000 && b_w == 32'hFFFFFFFF) begin
                div_s_w = 32'h80000000;
                div_u_w = 32'b0;
                rem_s_w = 32'b0;
                rem_u_w = a_w % b_w;
            end else begin
                div_s_w = $signed(a_w) / $signed(b_w);
                div_u_w = a_w / b_w;
                rem_s_w = $signed(a_w) % $signed(b_w);
                rem_u_w = a_w % b_w;
            end

            case (op)
                MUL:    result <= {{32{mul_w[31]}}, mul_w[31:0]};
                DIV_OP: result <= {{32{div_s_w[31]}}, div_s_w};
                DIVU:   result <= {{32{div_u_w[31]}}, div_u_w};
                REM_OP: result <= {{32{rem_s_w[31]}}, rem_s_w};
                REMU:   result <= {{32{rem_u_w[31]}}, rem_u_w};
                default: result <= 64'b0;
            endcase
        end else begin
            mul_ss = $signed(a) * $signed(b);
            mul_uu = a * b;
            mul_su = $signed({{64{a[63]}}, a}) * $signed({64'b0, b});

            if (b == 64'b0) begin
                div_s = 64'hFFFFFFFFFFFFFFFF;
                div_u = 64'hFFFFFFFFFFFFFFFF;
                rem_s = a;
                rem_u = a;
            end else if (a == 64'h8000000000000000 && b == 64'hFFFFFFFFFFFFFFFF) begin
                div_s = 64'h8000000000000000;
                div_u = 64'b0;
                rem_s = 64'b0;
                rem_u = a % b;
            end else begin
                div_s = $signed(a) / $signed(b);
                div_u = a / b;
                rem_s = $signed(a) % $signed(b);
                rem_u = a % b;
            end

            case (op)
                MUL:    result <= mul_ss[63:0];
                MULH:   result <= mul_ss[127:64];
                MULHSU: result <= mul_su[127:64];
                MULHU:  result <= mul_uu[127:64];
                DIV_OP: result <= div_s;
                DIVU:   result <= div_u;
                REM_OP: result <= rem_s;
                REMU:   result <= rem_u;
                default: result <= 64'b0;
            endcase
        end
    end else begin
        done <= 0;
    end
end

endmodule
