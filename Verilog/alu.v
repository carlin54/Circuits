module ALU #(
	parameter WIDTH=8
)(
	   input [WIDTH-1:0] in_a,
	   input [WIDTH-1:0] in_b,
	   input [2:0] opcode,
	   output reg [WIDTH-1:0] alu_out,
	   output reg a_is_zero
);

always @(in_a or in_b or opcode) begin
	case (opcode)
		3'b000: alu_out = in_a; 		// HLT
		3'b001: alu_out = in_a; 		// SKZ
		3'b010: alu_out = in_a + in_b; 	// ADD
		3'b011: alu_out = in_a & in_b; 	// AND
		3'b100: alu_out = in_a ^ in_b; 	// XOR
		3'b101: alu_out = in_b; 		// LDA
		3'b110: alu_out = in_a; 		// STO
		3'b111: alu_out = in_a; 		// JMP
	endcase
	a_is_zero = (in_a === {WIDTH{1'b0}}) ? 1'b1 : 1'b0;
end

endmodule
