module mux_tb;
	timeunit 1ns;
	timeprecision 100ps;

	parameter WIDTH = 4;

	logic [WIDTH-1:0] in_a;
	logic [WIDTH-1:0] in_b;
	logic sel_a;
	logic [WIDTH-1:0] out;

	mux #(
		.WIDTH(WIDTH)
	) DUT (
		.in_a(in_a),
		.in_b(in_b),
		.sel_a(sel_a),
		.out(out)
	);


	function void assert_equal(input logic [WIDTH-1:0] actual, input logic [WIDTH-1:0] expected);
		if (expected !== actual) begin
			$error("Assertion failed [time=%0t]:expected=%b, actual=%b", $time, expected, actual);
			$finish;
		end else begin
			`ifdef TESTBENCH_PRINT_ASSERT_PASS
				$display("Assertion passed [time=%0t]:expected=%b, actual=%b", $time, expected, actual);
			`endif
		end
	endfunction

	initial begin

		for (int i = 0; i < 2**WIDTH; i++) begin
			in_a = i;
			in_b = {WIDTH{1'b1}};
			sel_a = 1;
			#10
			assert_equal(out, i);
		end

		for (int i = 0; i < 2**WIDTH; i++) begin
			in_a = {WIDTH{1'b0}};
			in_b = i;
			sel_a = 0;
			#10
			assert_equal(out, i);
		end

		$display("mux_tb passed");
		$finish;
	end


	`ifdef TESTBENCH_PRINT_MONITOR
		initial begin
			$monitor("Monitor: time=%0t, reset=%b, d=%b, q=%b", $time, reset, d, q);
		end
	`endif

endmodule
