module counter_tb;
	reg [4:0] cnt_in;
	wire [4:0] cnt_out;
	reg enab;
	reg load;
	reg clk;
	reg rst;

	counter #(
		.WIDTH(5)
	) DUT (
		.cnt_in(cnt_in),
		.cnt_out(cnt_out),
		.enab(enab),
		.load(load),
		.clk(clk),
		.rst(rst)
	);


	task assert;
		input [4:0] exp_out;
		if (cnt_out === exp_out) begin
			//$display("PASS: (cnt_in, %b), (cnt_out, %d), (enab, %b), (load, %b), (rst, %b), (expected, %d)", cnt_in, cnt_out, enab, load, rst, exp_out);
		end else begin
			$display("FAIL: (cnt_in, %b), (cnt_out, %d), (enab, %b), (load, %b), (rst, %b), (expected, %d)", cnt_in, cnt_out, enab, load, rst, exp_out);
		end
	endtask

	integer i;
	integer j;

	initial begin

		// Confirm that it counts
		rst = 0; load = 1; enab = 1; cnt_in = 5'b00000; clk = 1; #100; clk = 0; #5;
		assert(5'b00000);
		for (i = 0; i < 30; i++) begin
			assert(i[4:0]);
			rst = 0; load = 0; enab = 1; cnt_in = 5'b00000; clk = 1; #100; clk = 0; #5;
			j = i + 1;
			assert(j[4:0]);
		end

		// Confirm that it loads correctly
		rst = 0; load = 1; enab = 1; cnt_in = 5'b00000; clk = 1; #100; clk = 0; #5;
		assert(5'b00000);
		for (i = 0; i < 32; i++) begin
			rst = 0; load = 1; enab = 1; cnt_in = i[4:0]; clk = 1; #100; clk = 0; #5;
			assert(i[4:0]);
		end

		// Confirm that it only updates when enables is set
		rst = 0; load = 1; enab = 1; cnt_in = 5'b00000; clk = 1; #100; clk = 0; #5;
		assert(5'b00000);
		for (i = 0; i < 32; i++) begin
			// Load
			rst = 0; load = 1; enab = 0; cnt_in = i[4:0]; clk = 1; #100; clk = 0; #5;
			assert(i[4:0]);

			// Clock without enabled
			rst = 0; load = 0; enab = 0; cnt_in = i[4:0]; clk = 1; #100; clk = 0; #5;
			rst = 0; load = 0; enab = 0; cnt_in = i[4:0]; clk = 1; #100; clk = 0; #5;
			rst = 0; load = 0; enab = 0; cnt_in = i[4:0]; clk = 1; #100; clk = 0; #5;

			assert(i[4:0]);

		end

		// Confirm that it resets every time
		rst = 0; load = 1; enab = 1; cnt_in = 5'b00000; clk = 1; #100; clk = 0; #5;
		assert(5'b00000);
		for (i = 0; i < 32; i++) begin
			rst = 0; load = 1; enab = 1; cnt_in = i[4:0]; clk = 1; #100; clk = 0; #5;
			assert(i[4:0]);

			rst = 1; load = 0; enab = 0; cnt_in = i[4:0]; clk = 1; #100; clk = 0; #5;
			assert(5'b00000);
		end

	end

endmodule
