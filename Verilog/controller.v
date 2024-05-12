module Controller (
	input wire zero,
	input wire [2:0] phase,
	input wire [2:0] opcode,
	input wire rst,
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
	localparam [2:0] PHASE_ALU_OP 		= 3'b111;
	localparam [2:0] PHASE_STORE 		= 3'b111;

	wire ALUOP;
	assign ALUOP = (opcode === OP_ADD) || (opcode === OP_AND) || (opcode === OP_XOR) || (opcode === OP_LDA);

	always @* begin
		if (rst) begin
			sel = 0;
			rd = 0;
			ld_ir = 0;
			halt = 0;
			inc_pc = 0;
			ld_ac = 0;
			ld_pc = 0;
			wr = 0;
			data_e = 0;
		end else begin

			case (phase)
				PHASE_INST_ADDR: begin 		// INST_ADDR
					sel = 1;
					rd = 0;
					ld_ir = 0;
					halt = 0;
					inc_pc = 0;
					ld_ac = 0;
					ld_pc = 0;
					wr = 0;
					data_e = 0;
				end
				PHASE_INST_FETCH: begin  		// INST_FETCH
					sel = 1;
					rd = 1;
					ld_ir = 0;
					inc_pc = 0;
					halt = 0;
					ld_ac = 0;
					ld_pc = 0;
					wr = 0;
					data_e = 0;
				end
				PHASE_INST_LOAD: begin 		// INST_LOAD
					sel = 1;
					rd = 1;
					ld_ir = 1;
					halt = 0;
					inc_pc = 0;
					ld_ac = 0;
					ld_pc = 0;
					wr = 0;
					data_e = 0;
				end
				PHASE_IDLE: begin 		// IDLE
					sel = 1;
					rd = 1;
					ld_ir = 1;
					halt = 0;
					inc_pc = 0;
					ld_ac = 0;
					ld_pc = 0;
					wr = 0;
					data_e = 0;
				end
				PHASE_OP_ADDR: begin 		// OP_ADDR
					sel = 0;
					rd = 0;
					ld_ir = 0;
					halt = (opcode === OP_HLT);
					inc_pc = 1;
					ld_ac = 0;
					ld_pc = 0;
					wr = 0;
					data_e = 0;
				end
				PHASE_OP_FETCH: begin 		// OP_FETCH
					sel = 0;
					rd = ALUOP;
					ld_ir = 0;
					halt = 0;
					inc_pc = 0;
					ld_ac = 0;
					ld_pc = 0;
					wr = 0;
					data_e = 0;
				end
				PHASE_OP_ALU_OP: begin 		// ALU_OP
					sel = 0;
					rd = ALUOP;
					ld_ir = 0;
					halt = 0;
					inc_pc = (opcode === OP_SKZ) && zero;
					ld_ac = 0;
					ld_pc = (opcode === OP_JMP);
					wr = 0;
					data_e = (opcode === OP_STO);
				end
				PHASE_STORE: begin 		// STORE
					sel = 0;
					rd = ALUOP;
					ld_ir = 0;
					inc_pc = 0;
					halt = 0;
					ld_ac = ALUOP;
					ld_pc = (opcode === OP_JMP);
					wr = (opcode === OP_STO);
					data_e = (opcode === OP_STO);
				end
			endcase
		end
	end

endmodule
