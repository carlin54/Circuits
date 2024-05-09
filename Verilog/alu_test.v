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
		a=1;
		b=1;
		op=3'b000;
		# 100;

		if (y == 2)
			$display("PASS: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
		else
			$display("FAIL: (a,%d), (b,%d), (op,%d), (y,%d), (z,%d)",a,b,op,y,z);
	  	
	end

endmodule
		
