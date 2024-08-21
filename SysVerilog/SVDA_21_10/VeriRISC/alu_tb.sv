import typedefs::*;

module alu_tb;

	timeunit 1ns;
	timeprecision 100ps;

	`define PERIOD 10
	logic clk = 1'b1;

	always begin
		#(`PERIOD/2)clk = ~clk;
	end

	parameter WIDTH = 8;
	logic [WIDTH-1:0] accum, data, out;
	logic zero;
	logic expect_zero;

	opcode_t opcode = HLT;

	alu DUT(.out(out), .zero(zero), .clk(clk), .accum(accum),
		 	.data(data), .opcode(opcode));

	task assert_equals(input [WIDTH:0] expected, input [WIDTH:0] actual);
		begin
			if (actual !== expected) begin
				$display("Assertion failed: %t opcode=%s data=%b accum=%b | zero=%b out=%b",
					$time, opcode.name(), data, accum, zero, out);
				$display("Actual: 	zero:%b, out:%b", actual[0], actual[8:1]);
				$display("Expected: zero:%b, out:%b", expected[0], expected[8:1]);
				$finish;
			end else begin
				`ifdef TESTBENCH_PRINT_ASSERT_PASS
					$display ("Assertion passed: %t opcode=%s data=%b accum=%b | zero=%b out=%b",
						$time, opcode.name(), data, accum, zero, out);
				`endif
			end
		end
	endtask

	logic signed [WIDTH-1:0] i, j;
	initial begin
		i = 0; j = 0;
		@(posedge clk)
		do begin
			do begin
				expect_zero = j == 0;

				{ opcode, data, accum } = {HLT, i, j};
				@(posedge clk)
				assert_equals({expect_zero, accum}, {zero, out});

				{ opcode, data, accum } = {SKZ, i, j};
				@(posedge clk)
				assert_equals({expect_zero, accum}, {zero, out});

				{ opcode, data, accum } = {ADD, i, j};
				@(posedge clk)
				assert_equals({expect_zero, accum + data}, {zero, out});

				{ opcode, data, accum } = {AND, i, j};
				@(posedge clk)
				assert_equals({expect_zero, data & accum}, {zero, out});

				{ opcode, data, accum } = {XOR, i, j};
				@(posedge clk)
				assert_equals({expect_zero, data ^ accum}, {zero, out});

				{ opcode, data, accum } = {LDA, i, j};
				@(posedge clk)
				assert_equals({expect_zero, data}, {zero, out});

				{ opcode, data, accum } = {STO, i, j};
				@(posedge clk)
				assert_equals({expect_zero, accum}, {zero, out});

				{ opcode, data, accum } = {JMP, i, j};
				@(posedge clk)
				assert_equals({expect_zero, accum}, {zero, out});
				j = j + 1;
			end while (j != 0);
			i = i + 1;
		end while (i != 0);

		$display("alu_tb passed");
		$finish;
	end

endmodule
