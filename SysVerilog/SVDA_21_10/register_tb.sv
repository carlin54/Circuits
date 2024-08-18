module register_tb;
	timeunit 1ns;
	timeprecision 100ps;

    parameter WIDTH = 4;

    logic clk;
    logic reset;
	logic enable;
    logic [WIDTH-1:0] d;
    logic [WIDTH-1:0] q;

    register #(
        .WIDTH(WIDTH)
    ) DUT (
        .clk(clk),
        .reset(reset),
		.enable(enable),
        .d(d),
        .q(q)
    );


    function void assert_equal(input logic [WIDTH-1:0] actual, input logic [WIDTH-1:0] expected);
        if (expected !== actual) begin
            $error("Assertion failed [time=%0t]:expected=%b, actual=%b", $time, expected, actual);
        end else begin
			`ifdef TESTBENCH_PRINT_ASSERT_PASS
				$display("Assertion passed [time=%0t]:expected=%b, actual=%b", $time, expected, actual);
			`endif
        end
    endfunction

	initial begin

		// Check reset
		enable = 0; reset = 1; clk = 1; #10 clk = 0; reset = 0;
		assert_equal(q, {WIDTH{1'b0}});

		// Check enable
		for (int i = 0; i < 2**WIDTH; i++) begin
			enable = 1; d = i;  reset = 0; clk = 0; #5; clk = 1; #5;
			assert_equal(q, i);

			enable = 1; d = {WIDTH{1'b1}}; reset = 1; clk = 0; #5; clk = 1; #5;
			assert_equal(q, {WIDTH{1'b0}});
		end

		reset = 1; clk = 1; #10 clk = 0; reset = 0;
		assert_equal(q, {WIDTH{1'b0}});

		// Check not enable
		for (int i = 0; i < 2**WIDTH; i++) begin
			enable = 0; d = i;  reset = 0; clk = 0; #5; clk = 1; #5;
			assert_equal(q, {WIDTH{1'b0}});

			enable = 0; d = {WIDTH{1'b1}}; reset = 1; clk = 0; #5; clk = 1; #5;
			assert_equal(q, {WIDTH{1'b0}});
		end
		$display("register_tb passed");
		$finish;
	end

	`ifdef TESTBENCH_PRINT_MONITOR
		initial begin
			$monitor("Monitor: time=%0t, reset=%b, d=%b, q=%b", $time, reset, d, q);
		end
	`endif

endmodule
