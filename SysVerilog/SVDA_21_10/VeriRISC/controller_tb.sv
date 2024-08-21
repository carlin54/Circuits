module controller_tb;
	timeunit 1ns;
	timeprecision 100ps;

	import typedefs::*;

	logic reset = 1'b1;
	logic zero;

	opcode_t opcode;
	state_t lstate;

	logic load_ac, mem_rd, mem_wr, inc_pc, load_pc, load_ir, halt;

	integer response_num;
	integer stimulus_num;
	logic [6:0] response_mem[1:550];
	logic [3:0] stimulus_mem[1:64];
	logic [3:0] stimulus_reg;
	logic [6:0] response_net;

	`define PERIOD 10
	logic clk = 1'b1;

	assign opcode = opcode_t'(stimulus_reg[2:0]);

	always begin
		#(`PERIOD/2)clk = ~clk;
	end

	controller DUT (
		.load_ac(load_ac), .mem_rd(mem_rd), .mem_wr(mem_wr), .inc_pc(inc_pc),
		.load_pc(load_pc), .load_ir(load_ir), .halt(halt), .opcode(opcode),
		.zero(zero), .clk(clk), .reset(reset)
	);

	assign response_net = {mem_rd, load_ir, halt, inc_pc, load_ac, load_pc, mem_wr};
	assign zero = stimulus_reg[3];
	assign lstate = DUT.state;

	task automatic expected_task;
		input [6:0] actual;
		input [6:0] expected;
		if (actual !== expected) begin
			$display("Assertion failed:");
			$display("{mem_rd,load_ir,halt,inc_pc,load_ac,load_pc,mem_wr}");
			$display("is        %b", response_net);
			$display("should be %b", response_mem[response_num]);
			$display("state: %s   opcode: %s  zero: %b", lstate.name(), opcode.name(), zero);
			$stop;
			$finish;
		end else begin
			`ifdef TESTBENCH_PRINT_ASSERT_PASS
				$display("Assertion passed [time=%0t]:", $time);
				$display("{mem_rd,load_ir,halt,inc_pc,load_ac,load_pc,mem_wr}");
				$display("state: %s   opcode: %s  zero: %b", lstate.name(), opcode.name(), zero);
			`endif
		end
	endtask

	initial begin
		$readmemb("stimulus.pat", stimulus_mem);
		$readmemb("response.pat", response_mem);
		stimulus_reg = 0;
		stimulus_num = 0;
		response_num = 0;
		@(negedge clk) reset = 0;
		@(negedge clk) reset = 1;

		do begin
			@(negedge clk);

			response_num = response_num + 1;

			expected_task(response_net, response_mem[response_num]);

			if (response_num[2:0] == 3'b111) begin
				stimulus_num++;
				stimulus_reg = stimulus_mem[stimulus_num];
			end

		end while (stimulus_num <= 64);

		$display("controller_tb passed");
		$finish;
	end

endmodule
