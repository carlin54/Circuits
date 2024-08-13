module counter_tb;
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

	initial begin
		// Check reset
		reset = 1'b1; data = {WIDTH{1'bx}}; load = 1'bx; enable = 1'bx; clk = 1; #5; clk=0; #5
		expected_task({WIDTH{1'b0}});

		// Check enable
		for (int i = 1; i < 2**WIDTH; i++) begin
			reset = 1'b0; data = {WIDTH{1'bx}}; load = 0; enable = 1'b1; clk = 1; #5; clk=0; #5
			expected_task(i);
		end

		// Check disabled
		for (int i = 1; i < 2**WIDTH; i++) begin
			reset = 1'b0; data = {WIDTH{1'bx}}; load = 0; enable = 1'b0; clk = 1; #5; clk=0; #5
			expected_task((2**WIDTH)-1);
		end

		// Check roll over
		reset = 1; data = {WIDTH{1'bx}}; load = 1'b0; enable = 1'b1; clk = 1; #5 clk = 0; #5
		expected_task({WIDTH{1'b0}});

		// Check load
		for (int i = (2**WIDTH)-1; i > 0; i--) begin
			reset = 1'b0; data = i; load = 1'b1; enable = 1'b0; clk = 1; #5 clk = 0; #5
			expected_task(i);
		end

		// Reset
		reset = 1'b1; data = {WIDTH{1'bx}}; load = 1'bx; enable = 1'bx; clk = 1; #5; clk=0; #5
		expected_task({WIDTH{1'b0}});

		// Check load and enable
		for (int i = (2**WIDTH)-1; i > 0; i--) begin
			reset = 1'b0; data = i; load = 1'b1; enable = 1'b1; clk = 1; #5 clk = 0; #5
			expected_task(i);
		end

	end

endmodule;
