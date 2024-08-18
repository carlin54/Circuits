import typedefs::*;

module alu
	#(
		parameter WIDTH = 8
	)(
		input opcode_t opcode,
		input logic [WIDTH-1:0] accum,
		input logic [WIDTH-1:0] data,
		input clk,
		output logic [WIDTH-1:0] out,
		output logic zero
	);

	timeunit 1ns;
	timeprecision 100ps;

	always_comb begin
		if (accum == 0) begin
			zero <= 1'b1;
		end else begin
			zero <= 1'b0;
		end
	end

	always_ff @(negedge clk) begin
		case (opcode)
			HLT: out <= accum;
			SKZ: out <= accum;
			ADD: out <= data + accum;
			AND: out <= data & accum;
			XOR: out <= data ^ accum;
			LDA: out <= data;
			STO: out <= accum;
			JMP: out <= accum;
		endcase
	end

endmodule
