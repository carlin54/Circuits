module controller (
	input wire zero,
	input wire [2:0] phase,
	input wire [2:0] opcode,
	output reg sel,
	output reg rd,
	output reg ld_ir,
	output reg halt,
	output reg inc_pc,
	output reg ld_ac,
	output reg ld_pc,
	output reg wr,
	output reg data_e
);

	localparam [2:0] OP_HLT = 3'b000;
	localparam [2:0] OP_SKZ = 3'b001;
	localparam [2:0] OP_ADD = 3'b010;
	localparam [2:0] OP_AND = 3'b011;
	localparam [2:0] OP_XOR = 3'b100;
	localparam [2:0] OP_LDA = 3'b101;
	localparam [2:0] OP_STO = 3'b110;
	localparam [2:0] OP_JMP = 3'b111;

	localparam [2:0] PHASE_INST_ADDR 	= 3'b000;
	localparam [2:0] PHASE_INST_FETCH 	= 3'b001;
	localparam [2:0] PHASE_INST_LOAD 	= 3'b010;
	localparam [2:0] PHASE_IDLE 		= 3'b011;
	localparam [2:0] PHASE_OP_ADDR 		= 3'b100;
	localparam [2:0] PHASE_OP_FETCH 	= 3'b101;
	localparam [2:0] PHASE_OP_ALU_OP 	= 3'b110;
	localparam [2:0] PHASE_STORE 		= 3'b111;

	reg H, A, Z, J, S;

	always @* begin
		H = (opcode == OP_HLT);
		A = (opcode == OP_ADD) || (opcode == OP_AND) || (opcode == OP_XOR) || (opcode == OP_LDA);
		Z = (opcode == OP_SKZ && zero);
		J = (opcode == OP_JMP);
		S = (opcode == OP_STO);

		case (phase)
			PHASE_INST_ADDR: 	begin sel = 1; rd = 0; ld_ir = 0; halt = 0; inc_pc = 0; ld_ac = 0; ld_pc = 0; wr = 0; data_e = 0; end
			PHASE_INST_FETCH: 	begin sel = 1; rd = 1; ld_ir = 0; halt = 0; inc_pc = 0; ld_ac = 0; ld_pc = 0; wr = 0; data_e = 0; end
			PHASE_INST_LOAD: 	begin sel = 1; rd = 1; ld_ir = 1; halt = 0; inc_pc = 0; ld_ac = 0; ld_pc = 0; wr = 0; data_e = 0; end
			PHASE_IDLE: 		begin sel = 1; rd = 1; ld_ir = 1; halt = 0; inc_pc = 0; ld_ac = 0; ld_pc = 0; wr = 0; data_e = 0; end
			PHASE_OP_ADDR: 		begin sel = 0; rd = 0; ld_ir = 0; halt = H; inc_pc = 1; ld_ac = 0; ld_pc = 0; wr = 0; data_e = 0; end
			PHASE_OP_FETCH: 	begin sel = 0; rd = A; ld_ir = 0; halt = 0; inc_pc = 0; ld_ac = 0; ld_pc = 0; wr = 0; data_e = 0; end
			PHASE_OP_ALU_OP: 	begin sel = 0; rd = A; ld_ir = 0; halt = 0; inc_pc = Z; ld_ac = 0; ld_pc = J; wr = 0; data_e = S; end
			PHASE_STORE: 		begin sel = 0; rd = A; ld_ir = 0; halt = 0; inc_pc = 0; ld_ac = A; ld_pc = J; wr = S; data_e = S; end
		endcase
	end

endmodule
