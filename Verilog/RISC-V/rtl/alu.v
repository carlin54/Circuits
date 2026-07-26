module alu (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [3:0]  alu_op,
    input  wire        is_word_op,
    output wire [63:0] result
);

localparam ALU_ADD  = 4'b0000;
localparam ALU_SUB  = 4'b0001;
localparam ALU_AND  = 4'b0010;
localparam ALU_OR   = 4'b0011;
localparam ALU_XOR  = 4'b0100;
localparam ALU_SLL  = 4'b0101;
localparam ALU_SRL  = 4'b0110;
localparam ALU_SRA  = 4'b0111;
localparam ALU_SLT  = 4'b1000;
localparam ALU_SLTU = 4'b1001;
localparam ALU_PASSB = 4'b1010;

wire [5:0] shamt = is_word_op ? {1'b0, b[4:0]} : b[5:0];

wire signed [63:0] a_s = a;
wire signed [31:0] a_w_s = a[31:0];
wire [63:0] sra_full = a_s >>> shamt;
wire [31:0] sra_word = a_w_s >>> shamt[4:0];

reg [63:0] raw_result;

always @(*) begin
    case (alu_op)
        ALU_ADD:  raw_result = is_word_op ? {32'b0, a[31:0] + b[31:0]} : a + b;
        ALU_SUB:  raw_result = is_word_op ? {32'b0, a[31:0] - b[31:0]} : a - b;
        ALU_AND:  raw_result = a & b;
        ALU_OR:   raw_result = a | b;
        ALU_XOR:  raw_result = a ^ b;
        ALU_SLL:  raw_result = is_word_op ? {32'b0, a[31:0] << shamt[4:0]} : a << shamt;
        ALU_SRL:  raw_result = is_word_op ? {32'b0, a[31:0] >> shamt[4:0]} : a >> shamt;
        ALU_SRA:  raw_result = is_word_op ? {{32{sra_word[31]}}, sra_word} :
                                            sra_full;
        ALU_SLT:  raw_result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0;
        ALU_SLTU: raw_result = (a < b) ? 64'd1 : 64'd0;
        ALU_PASSB: raw_result = b;
        default:  raw_result = 64'b0;
    endcase
end

assign result = (is_word_op && alu_op != ALU_SRA) ? {{32{raw_result[31]}}, raw_result[31:0]} : raw_result;

endmodule
