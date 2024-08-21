module counter_tb;
	timeunit 1ns;
	timeprecision 100ps;

	parameter WIDTH = 4;

	logic clk;
	logic reset;
	logic enable;
	logic load;
	logic [WIDTH-1:0] data;
	logic [WIDTH-1:0] count;

	counter #(
		.WIDTH(WIDTH)
	) DUT (
		.clk(clk),
		.reset(reset),
		.load(load),
		.enable(enable),
		.data(data),
		.count(count)
	);

	task expected_task;
		input [WIDTH-1:0] expected;
		if (expected !== count) begin
			$error("Assertion failed [time=%0t]:expected=%b, actual (data)=%b", $time, expected, count);
			$finish;
		end else begin
			`ifdef TESTBENCH_PRINT_ASSERT_PASS
				$display("Assertion passed [time=%0t]:expected=%b, actual (data)=%b", $time, expected, data);
			`endif
		end
	endtask
	logic [WIDTH-1:0] i;

	initial begin
		// Check reset
		reset = 1; data = {WIDTH{1'bx}}; load = 0; enable = 0; clk = 0;
		#5;
		reset = 0;
		#5
		expected_task({WIDTH{1'b0}});

		// Check enabled
		i = {WIDTH{1'b0}};
		do begin
			i = i + 1;
			reset = 1; data = {WIDTH{1'b0}}; load = 0; enable = 1; clk = 1;
			#5;
			expected_task(i);
			clk = 0;
			#5;
			// Checks roll-over on final
		end while (i != 0);

		// Reset
		reset = 1; data = {WIDTH{1'bx}}; load = 0; enable = 0; clk = 0;
		#5;
		reset = 0;
		#5
		expected_task({WIDTH{1'b0}});

		// Check disabled
		i = {WIDTH{1'b0}};
		do begin
			i = i + 1;
			reset = 1; data = {WIDTH{1'b0}}; load = 0; enable = 0; clk = 1;
			#5;
			expected_task({WIDTH{1'b0}});
			clk = 0;
			#5;
		end while (i != 0);

		// Check load
		i = {WIDTH{1'b1}};
		do begin
			reset = 1; data = i; load = 1; enable = 0; clk = 1;
			#5;
			expected_task(i);
			clk = 0;
			#5;
			i = i - 1;
		end while (i != 0);

		$display("counter_tb passed");
		$finish;
	end

endmodule
