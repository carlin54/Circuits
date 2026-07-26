module decoder (
    input  wire [31:0] instr,
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rs3,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire [1:0]  fmt,
    output wire [4:0]  funct5,
    output reg  [63:0] imm,
    output wire [11:0] imm_i
);

assign opcode = instr[6:0];
assign rd     = instr[11:7];
assign funct3 = instr[14:12];
assign rs1    = instr[19:15];
assign rs2    = instr[24:20];
assign funct7 = instr[31:25];
assign rs3    = instr[31:27];
assign funct5 = instr[31:27];
assign fmt    = instr[26:25];
assign imm_i  = instr[31:20];

always @(*) begin
    case (opcode)
        // I-type: LOAD, LOAD-FP, OP-IMM, OP-IMM-32, JALR, SYSTEM, MISC-MEM
        7'b0000011, 7'b0000111, 7'b0010011, 7'b0011011, 7'b1100111, 7'b1110011, 7'b0001111:
            imm = {{52{instr[31]}}, instr[31:20]};

        // S-type: STORE, STORE-FP
        7'b0100011, 7'b0100111:
            imm = {{52{instr[31]}}, instr[31:25], instr[11:7]};

        // B-type: BRANCH
        7'b1100011:
            imm = {{51{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

        // U-type: LUI, AUIPC
        7'b0110111, 7'b0010111:
            imm = {{32{instr[31]}}, instr[31:12], 12'b0};

        // J-type: JAL
        7'b1101111:
            imm = {{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

        // R-type and others: no immediate
        default:
            imm = 64'b0;
    endcase
end

endmodule
