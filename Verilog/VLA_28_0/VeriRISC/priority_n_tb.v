module priority_n_tb;
	reg [7:0] py;
	wire [3:0] pa;

	task assert;
		input integer exp_out;
		if (exp_out[3:0] == pa) begin
			//$display("PASS: (py: %b), (pa, %b), (expected, %b)", py, pa, exp_out[3:0]);
		end else begin
			$display("FAIL: (py: %b), (pa, %b), (expected, %b)", py, pa, exp_out[3:0]);
		end

	endtask

	priority_n #(
		.WIDTH(8)
	) DUT (
		.py(py),
		.pa(pa)
	);

	initial begin

		py = 8'b00000000; #100; assert(0);
		py = 8'b0000000x; #100; assert(1);
		py = 8'b000000xx; #100; assert(2);
		py = 8'b00000xxx; #100; assert(3);
		py = 8'b0000xxxx; #100; assert(4);
		py = 8'b000xxxxx; #100; assert(5);
		py = 8'b00xxxxxx; #100; assert(6);
		py = 8'b0xxxxxxx; #100; assert(7);
		py = 8'bxxxxxxxx; #100; assert(8);

	end


endmodule
