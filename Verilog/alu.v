module alu #(
	parameter WIDTH=8
)(
	   input [WIDTH-1:0] in_a,
	   input [WIDTH-1:0] in_b,
	   input [2:0] opcode,
	   output reg [WIDTH-1:0] alu_out,
	   output reg a_is_zero
);

	localparam [2:0] OP_HLT = 3'b000;
	localparam [2:0] OP_SKZ = 3'b001;
	localparam [2:0] OP_ADD = 3'b010;
	localparam [2:0] OP_AND = 3'b011;
	localparam [2:0] OP_XOR = 3'b100;
	localparam [2:0] OP_LDA = 3'b101;
	localparam [2:0] OP_STO = 3'b110;
	localparam [2:0] OP_JMP = 3'b111;

	initial begin
		alu_out <= {WIDTH{1'b0}};
		a_is_zero <= 1'b0;
	end

	always @(in_a or in_b or opcode) begin
		case (opcode)
			OP_HLT: alu_out <= in_a; 		// HLT
			OP_SKZ: alu_out <= in_a; 		// SKZ
			OP_ADD: alu_out <= in_a + in_b; // ADD
			OP_AND: alu_out <= in_a & in_b;	// AND
			OP_XOR: alu_out <= in_a ^ in_b; // XOR
			OP_LDA: alu_out <= in_b; 		// LDA
			OP_STO: alu_out <= in_a; 		// STO
			OP_JMP: alu_out <= in_a; 		// JMP
		endcase
		a_is_zero <= (in_a === {WIDTH{1'b0}}) ? 1'b1 : 1'b0;
	end

endmodule
