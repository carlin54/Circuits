import typedefs::*;
module alu (
	output logic [7:0] out,
	output logic zero,
	input logic clk,
	input logic [7:0] accum,
	input logic [7:0] data,
	input opcode_t opcode
);

	timeunit 1ns;
	timeprecision 100ps;

	always @(negedge clk) begin
		unique case ( opcode )
			ADD : out <= accum + data;
			AND : out <= accum & data;
			XOR : out <= accum ^ data;
			LDA : out <=         data;
			HLT,
			SKZ,
			JMP,
			STO  : out <= accum;
		endcase
	end

	always_comb begin
		zero = ~(|accum);
	end

endmodule
