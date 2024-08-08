module register_tb;

    parameter WIDTH = 4;

    logic clk;
    logic reset;
    logic [WIDTH-1:0] d;
    logic [WIDTH-1:0] q;
    integer i;

    register #(
        .WIDTH(WIDTH)
    ) DUT (
        .clk(clk),
        .reset(reset),
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
		reset = 1; clk = 1; #10 clk = 0; reset = 0;
		assert_equal(q, {WIDTH{1'b0}});

        for (i = 0; i < 2**WIDTH; i = i + 1) begin
			d = i; reset = 0; clk = 1; #10; clk = 0;
			assert_equal(q, i);

			reset = 1; clk = 1; #10 clk = 0; reset = 0;
			assert_equal(q, {WIDTH{1'b0}});
        end

		reset = 1; clk = 1; #10 clk = 0; reset = 0;
		assert_equal(q, {WIDTH{1'b0}});

        $finish;
    end

	`ifdef TESTBENCH_PRINT_MONITOR
		initial begin
			$monitor("Monitor: time=%0t, reset=%b, d=%b, q=%b", $time, reset, d, q);
		end
	`endif

endmodule
