import typedefs::*;

module controller(
	output logic load_ac,
	output logic mem_rd,
	output logic mem_wr,
	output logic inc_pc,
	output logic load_pc,
	output logic load_ir,
	output logic halt,
	input opcode_t opcode,
	input zero,
	input clk,
	input reset
);

	timeunit 1ns;
	timeprecision 100ps;

	state_t state;

	logic aluop;

	assign aluop = (opcode inside {ADD, AND, XOR, LDA});

	always_ff @(posedge clk or negedge reset) begin
		if (!reset) begin
			state <= INST_ADDR;
		end else begin
			state <= state.next();
		end
	end

	always_comb begin
		{mem_rd, load_ir, halt, inc_pc, load_ac, load_pc, mem_wr}  =  7'b000_0000;
		unique case (state)
			INST_ADDR : ;
			INST_FETCH: mem_rd = 1;
			INST_LOAD : begin
				mem_rd = 1;
				load_ir = 1;
			end
			IDLE: begin
				mem_rd = 1;
				load_ir = 1;
			end
			OP_ADDR: begin
				inc_pc = 1;
				halt = (opcode == HLT);
			end
			OP_FETCH: mem_rd = aluop;
			ALU_OP: begin
				load_ac = aluop;
				mem_rd = aluop;
				inc_pc = ((opcode == SKZ) && zero);
				load_pc = (opcode == JMP);
			end
			STORE: begin
				load_ac = aluop;
				mem_rd = aluop;
				inc_pc = (opcode == JMP || ((opcode == SKZ) && zero));
				load_pc = (opcode == JMP);
				mem_wr = (opcode == STO);
			end
		endcase
	end

endmodule
