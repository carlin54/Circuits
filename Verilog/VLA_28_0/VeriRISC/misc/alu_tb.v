module ALU_TB;
	reg [0:31] a;
	reg [0:31] b;
	reg [0:2] op;
	wire [0:31] y;
	wire z;

	ALU alu
	(
		.a_in(a),
		.b_in(b),
		.op_in(op),
		.y_out(y),
		.z_out(z)
	);

	initial

	begin
		// Addition
		a=1;
		b=1;
		op=3'b000;
		# 100;

		if (y == 2 && z == 0)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);


		a=0;
		b=0;
		op=3'b000;
		# 100;
		if (y == 0 && z == 1)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);


		// Subtraction
		a=100;
		b=50;
		op=3'b001;
		# 100;

		if (y == 50 && z == 0)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);


		a=50;
		b=50;
		op=3'b001;
		# 100;
		if (y == 0 && z == 1)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);


		// Multiplication
		a=25;
		b=25;
		op=3'b010;
		# 100;

		if (y == 625 && z == 0)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);


		a=50;
		b=0;
		op=3'b010;
		# 100;
		if (y == 0 && z == 1)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);


		// Division
		a=50;
		b=5;
		op=3'b100;
		# 100;

		if (y == 10 && z == 0)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);


		a=50;
		b=0;
		op=3'b100;
		# 100;
		if (y == 0 && z == 1)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);

		a=0;
		b=50;
		op=3'b100;
		# 100;
		if (y == 0 && z == 1)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);

	end

endmodule
