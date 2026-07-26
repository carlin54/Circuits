module adder_tb_4 #(parameter BITS = 4);

	timeunit 1ns;
    timeprecision 100ps;

	logic [BITS-1:0] a, b, sum;
	logic cin, cout;

	adder_n #(.BITS(BITS)) DUT1 (
		.a(a),
		.b(b),
		.cin(cin),
		.sum(sum),
		.cout(cout)
	);

	logic [BITS-1:0] i;
	logic [BITS-1:0] j;
	logic [BITS:0] s;
	initial begin
		cin <= 0;
		i = {BITS{1'b0}};
		do begin
			a <= i;

			j = {BITS{1'b0}};
			do begin
				b <= j;
				#100
				if (sum != a + b) begin
					$display("adder_tb failed: sum:%b, a:%b, b:%b, cout:%b", sum, a, b, cout);
					$stop;
				end

				s = i + j;
				if (s > (2**BITS-1) && cout != 1'b1) begin
					$display("adder_tb failed: sum:%d, a:%d, b:%d, cout:%b", sum, a, b, cout);
				end

				j = j + 1;
			end while(j != {{1'b0}});
			i = i + 1;
		end while(i != {{1'b0}});
	end

endmodule


module adder_tb_8 #(parameter BITS = 8);

	timeunit 1ns;
    timeprecision 100ps;

	logic [BITS-1:0] a, b, sum;
	logic cin, cout;

	adder_n #(.BITS(BITS)) DUT1 (
		.a(a),
		.b(b),
		.cin(cin),
		.sum(sum),
		.cout(cout)
	);

	logic [BITS-1:0] i;
	logic [BITS-1:0] j;
	logic [BITS:0] s;
	initial begin
		cin <= 0;
		i = {BITS{1'b0}};
		do begin
			a <= i;

			j = {BITS{1'b0}};
			do begin
				b <= j;
				#100
				if (sum != a + b) begin
					$display("adder_tb failed: sum:%b, a:%b, b:%b, cout:%b", sum, a, b, cout);
					$stop;
				end

				s = i + j;
				if (s > (2**BITS-1) && cout != 1'b1) begin
					$display("adder_tb failed: sum:%d, a:%d, b:%d, cout:%b", sum, a, b, cout);
				end

				j = j + 1;
			end while(j != {{1'b0}});
			i = i + 1;
		end while(i != {{1'b0}});
	end

endmodule
