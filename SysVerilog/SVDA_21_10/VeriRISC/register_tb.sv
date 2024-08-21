module register_tb;
	timeunit 1ns;
	timeprecision 100ps;

    parameter WIDTH = 4;

    logic clk;
    logic reset;
	logic enable;
    logic [WIDTH-1:0] data;
    logic [WIDTH-1:0] out;

    register #(
        .WIDTH(WIDTH)
    ) DUT (
        .clk(clk),
        .reset(reset),
		.enable(enable),
        .data(data),
        .out(out)
    );


    function void assert_equal(input logic [WIDTH-1:0] actual, input logic [WIDTH-1:0] expected);
        if (expected !== actual) begin
            $error("Assertion failed [time=%0t]:expected=%b, actual=%b", $time, expected, actual);
			$stop;
        end else begin
			`ifdef TESTBENCH_PRINT_ASSERT_PASS
				$display("Assertion passed [time=%0t]:expected=%b, actual=%b", $time, expected, actual);
			`endif
        end
    endfunction

	initial begin

	end

	logic [WIDTH-1:0] i;

	initial begin

		i = {WIDTH{1'b0}};

		// Check reset
		data = {WIDTH{1'b1}}; enable = 0; reset = 1; clk = 0; #5 clk = 0; reset = 0; #5
		assert_equal(out, {WIDTH{1'b0}});

		// Check enable
		do begin
			enable = 1; data = i; reset = 1; clk = 1;
			#5;
			assert_equal(out, i);
			clk = 0;
			#5;

			enable = 1; data = {WIDTH{1'b1}}; reset = 1; clk = 0;
			#5;
			reset = 0; clk = 0;
			#5;
			assert_equal(out, {WIDTH{1'b0}});
			i = i + 1;
		end while (i != 0);

		// Reset
		data = {WIDTH{1'b1}}; enable = 0; reset = 1; clk = 0; #5 clk = 0; reset = 0; #5
		assert_equal(out, {WIDTH{1'b0}});

		do begin
			enable = 0; data = i; reset = 1; clk = 1;
			#5;
			assert_equal(out, {WIDTH{1'b0}});
			clk = 0;
			#5;

			enable = 0; data = {WIDTH{1'b1}}; reset = 1; clk = 0;
			#5;
			reset = 0; clk = 0;
			#5;
			assert_equal(out, {WIDTH{1'b0}});
			i = i + 1;
		end while (i != 0);

		$display("register_tb passed");
		$finish;
	end

	`ifdef TESTBENCH_PRINT_MONITOR
		initial begin
			$monitor("Monitor: time=%0t, reset=%b, data=%b, out=%b", $time, reset, data, out);
		end
	`endif

endmodule
