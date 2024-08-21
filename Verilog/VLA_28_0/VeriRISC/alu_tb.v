module alu_tb;
	reg [7:0] in_a;
	reg [7:0] in_b;
	reg [2:0] opcode;
	wire [7:0] alu_out;
	wire a_is_zero;

	alu #(
		.WIDTH(8)
	) DUT (
		.in_a(in_a),
		.in_b(in_b),
		.opcode(opcode),
		.alu_out(alu_out),
		.a_is_zero(a_is_zero)
	);

	task assert;
		input [7:0] exp_alu_out;
		input exp_a_is_zero;

		if (alu_out === exp_alu_out && a_is_zero === exp_a_is_zero) begin
			//$display("PASS: (in_a, %d), (in_b, %d), (opcode, %d), (alu_out, %d), (exp_alu_out, %d), (a_is_zero, %d), (exp_a_is_zero, %d)", in_a, in_b, opcode, alu_out, exp_alu_out, a_is_zero, exp_a_is_zero);
		end else begin
			$display("FAIL: (in_a, %d), (in_b, %d), (opcode, %d), (alu_out, %d), (exp_alu_out, %d), (a_is_zero, %d), (exp_a_is_zero, %d)", in_a, in_b, opcode, alu_out, exp_alu_out, a_is_zero, exp_a_is_zero);
		end


	endtask;

	localparam [2:0] OP_HLT = 3'b000;
	localparam [2:0] OP_SKZ = 3'b001;
	localparam [2:0] OP_ADD = 3'b010;
	localparam [2:0] OP_AND = 3'b011;
	localparam [2:0] OP_XOR = 3'b100;
	localparam [2:0] OP_LDA = 3'b101;
	localparam [2:0] OP_STO = 3'b110;
	localparam [2:0] OP_JMP = 3'b111;

	initial	begin
		in_a=8'b01010101; in_b=8'b10101010; opcode=OP_HLT; #100; assert(in_a, 0);
		in_a=8'b10101010; in_b=8'b01010101; opcode=OP_SKZ; #100; assert(in_a, 0);
		in_a=8'b00001111; in_b=8'b01011111; opcode=OP_ADD; #100; assert(in_a + in_b, 0);
		in_a=8'b11001100; in_b=8'b11110000; opcode=OP_AND; #100; assert(in_a & in_b, 0);
		in_a=8'b00110011; in_b=8'b00001111; opcode=OP_XOR; #100; assert(in_a ^ in_b, 0);
		in_a=8'b00000001; in_b=8'b11111111; opcode=OP_LDA; #100; assert(in_b, 0);
		in_a=8'b11111111; in_b=8'b00000000; opcode=OP_STO; #100; assert(in_a, 0);
		in_a=8'b11111111; in_b=8'b00000000; opcode=OP_JMP; #100; assert(in_a, 0);
		in_a=8'b00000000; in_b=8'b00000000; opcode=OP_JMP; #100; assert(in_a, 1);
		/*
		in_a=8'h42; in_b=8'h86; opcode=OP_HLT; #100; assert(8'h42, 1'b0);
		in_a=8'h42; in_b=8'h86; opcode=OP_SKZ; #100; assert(8'h42, 1'b0);
		in_a=8'h42; in_b=8'h86; opcode=OP_ADD; #100; assert(8'hC8, 1'b0);
		in_a=8'h42; in_b=8'h86; opcode=OP_AND; #100; assert(8'h02, 1'b0);
		in_a=8'h42; in_b=8'h86; opcode=OP_XOR; #100; assert(8'hC4, 1'b0);
		in_a=8'h42; in_b=8'h86; opcode=OP_LDA; #100; assert(8'h86, 1'b0);
		in_a=8'h42; in_b=8'h86; opcode=OP_STO; #100; assert(8'h42, 1'b0);
		in_a=8'h42; in_b=8'h86; opcode=OP_JMP; #100; assert(8'h42, 1'b0);
		in_a=8'h00; in_b=8'h86; opcode=OP_JMP; #100; assert(8'h00, 1'b1);
		*/
	end

endmodule
