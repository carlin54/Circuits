import typedefs::*;

module controller (
		input opcode_t opcode,
		input logic zero,
		input logic clk,
		input logic reset,

		output logic load_ac,
		output logic mem_rd,
		output logic mem_wr,
		output logic inc_pc,
		output logic load_pc,
		output logic load_ir,
		output logic halt
);


	logic aluop;
	state_t state = INST_ADDR;

	logic [6:0] control_signals;
 	assign {mem_rd, load_ir, halt, inc_pc, load_ac, load_pc, mem_wr} = control_signals;

	always_ff @(posedge clk or negedge reset) begin
		aluop <= (opcode == ADD) ||
		  		(opcode == XOR) ||
		  		(opcode == AND) ||
		  		(opcode == LDA);

		if (!reset) begin
			state = INST_ADDR;
		end else begin
			state = state_t'(state + 1);
		end

		case (state)
			INST_ADDR: begin
				control_signals = 7'b0000000;
			end
			INST_FETCH: begin
				control_signals = 7'b1000000;
			end
			INST_LOAD: begin
				control_signals = 7'b1100000;
			end
			IDLE: begin
				control_signals = 7'b1100000;
			end
			OP_ADDR: begin
				control_signals = {2'b00, opcode == HLT, 4'b1000};
			end
			OP_FETCH: begin
				control_signals = {aluop, 6'b000000};
			end
			ALU_OP: begin
				control_signals = {aluop, 2'b00, opcode == SKZ && zero, aluop, opcode == JMP, 1'b0};
			end
			STORE: begin
				control_signals = {aluop, 2'b00, opcode == JMP, aluop, opcode == JMP, opcode == STO};
			end

		endcase

	end

endmodule
