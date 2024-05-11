module ALU_TB;
	reg [0:3] in_a;
	reg [0:3] in_b;
	reg [0:2] opcode;
	wire [0:3] alu_out;
	wire a_is_zero;

	ALU #(
		.WIDTH(4)
	) alu (
		.in_a(in_a),
		.in_b(in_b),
		.opcode(opcode),
		.alu_out(alu_out),
		.a_is_zero(a_is_zero)
	);

	initial

	begin
		// HLT
		in_a=4'b0010;
		in_b=4'b0100;
		opcode=3'b000;
		# 100;
		if (alu_out === in_a && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);

		// SKZ
		in_a=4'b0010;
		in_b=4'b0100;
		opcode=3'b001;
		# 100;
		if (alu_out === in_a && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);

		// ADD
		in_a=4'b0001;
		in_b=4'b0011;
		opcode=3'b010;
		# 100;
		if (alu_out === (in_a + in_b) && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);

		// AND
		in_a=4'b0110;
		in_b=4'b0100;
		opcode=3'b011;
		# 100;
		if (alu_out === (in_a & in_b) && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("XOR FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);

		// XOR
		in_a=4'b0110;
		in_b=4'b0100;
		opcode=3'b100;
		# 100;
		if (alu_out === (in_a ^ in_b) && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("XOR FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);


		// LDA
		in_a=4'b0110;
		in_b=4'b0100;
		opcode=3'b101;
		# 100;
		if (alu_out === in_b && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);


		// STO
		in_a=4'b0110;
		in_b=4'b0100;
		opcode=3'b110;
		# 100;
		if (alu_out === in_a && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);

		// JMP
		in_a=4'b0110;
		in_b=4'b0100;
		opcode=3'b111;
		# 100;
		if (alu_out === in_a && a_is_zero == 0)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);

		// A is zero
		in_a=4'b0000;
		in_b=4'b0100;
		opcode=3'b111;
		# 100;
		if (alu_out === in_a && a_is_zero == 1)
			$display("PASS: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);
		else
			$display("FAIL: (in_a,%d), (in_b,%d), (opcode,%d), (alu_out,%d), (a_is_zero,%d)",in_a,in_b,opcode,alu_out,a_is_zero);

	end

endmodule
