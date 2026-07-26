module frequency_divider_tb;
	reg clk;
	reg rst;
	wire out_clk;

	frequency_divider #(
		.N(8)
	) DUT (
		.clk(clk),
		.rst(rst),
		.out_clk(out_clk)
	);

	task assert;
		input exp_out_clk;
		if (exp_out_clk !== out_clk) begin
			$display("FAIL: (rst,%b), (out_clk,%b), (exp_clk,%b)", rst, out_clk, exp_out_clk);
		end else begin
			// $display("PASS: (rst,%b), (out_clk,%b), (exp_clk,%b)", rst, out_clk, exp_out_clk);
		end
	endtask


	initial begin
		rst=0;

		for (integer i = 0; i < 8; i++) begin
			clk = 1; 	#100; 	clk = 0; 	#100; 	assert(0);
		end

		for (integer i = 0; i < 8; i++) begin
			clk=1; #100; clk=0; #100; assert(1);
		end

		for (integer i = 0; i < 8; i++) begin
			clk=1; #100; clk=0; #100; assert(0);
		end

		for (integer i = 0; i < 4; i++) begin
			clk=1; #100; clk=0; #100; assert(1);
		end

		rst=1; clk=1; #10; rst=0; clk=0; #10;
		assert(0);

	end


endmodule
