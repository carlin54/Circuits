module cpu_tb;
	timeunit 1ns;
	timeprecision 100ps;

	import typedefs::*;

	logic reset;
	logic [12*8:1] testfile;
	opcode_t   topcode;
	logic [31:0]   test_number;

	logic clk, alu_clk, cntrl_clk, clk2, fetch, halt;
	logic load_ir;

	`define PERIOD 10
	logic master_clk = 1'b1;

	logic [3:0] count;

	always begin
		#(`PERIOD/2) master_clk = ~master_clk;
	end


	always @(posedge master_clk or negedge reset) begin
		if (~reset) begin
			count <= 3'b0;
		end else begin
			count <= count + 1;
		end
	end

	assign cntrl_clk = ~count[0];
	assign clk  = count[1];
	assign fetch = ~count[3];
	assign alu_clk = ~(count == 4'hc);

	cpu cpu1(
		.halt(halt),
		.load_ir(load_ir),
		.clk(clk),
		.alu_clk(alu_clk),
		.cntrl_clk(cntrl_clk),
		.fetch (fetch),
		.reset(reset)
	);

	initial begin
		$timeformat(-9, 1, " ns", 12);
	end

	initial begin
		for (int test_number = 1; test_number < 4; test_number++) begin

			case (test_number)
				1: begin
					$display("CPUtest1 - BASIC CPU DIAGNOSTIC PROGRAM \n");
					$display("THIS TEST SHOULD HALT WITH THE PC AT 17 hex\n");
				end
				2: begin
					$display("CPUtest2 - ADVANCED CPU DIAGNOSTIC PROGRAM\n");
					$display("THIS TEST SHOULD HALT WITH THE PC AT 10 hex\n");
				end
				3: begin
					$display("CPUtest3 - FIBONACCI NUMBERS to 144\n");
					$display("THIS TEST SHOULD HALT WITH THE PC AT 1C hex\n");
				end
			endcase

			testfile = {"CPUtest", 8'h30+test_number[7:0], ".dat"};
			$readmemb(testfile, cpu1.memory1.memory);
			reset = 1;
			repeat (2) @(negedge master_clk);
			reset = 0;
			repeat (2) @(negedge master_clk);
			reset = 1;
			$display("     TIME       PC    INSTR    OP   ADR   DATA\n");
			$display("  ----------    --    -----    --   ---   ----\n");
			while (!halt)
				@(posedge clk)

				if (load_ir) begin
					#(`PERIOD/2)
					topcode =  cpu1.opcode;
					$display ( "%t    %h    %s      %h    %h     %h     %h",
						$time,cpu1.pc_addr,topcode.name(),cpu1.opcode,
						cpu1.addr,cpu1.alu_out,cpu1.data_out );

					if ((test_number == 3) && (topcode == JMP)) begin
						$display ("Next Fibonacci number is %d", cpu1.memory1.memory[5'h1B] );
					end
				end

			if ( test_number == 1 && cpu1.pc_addr !== 5'h17
				|| test_number == 2 && cpu1.pc_addr !== 5'h10
				|| test_number == 3 && cpu1.pc_addr !== 5'h0C
				|| cpu1.pc_addr === 5'hXX) begin
					$display("cpu test %d failed", test_number);
					$finish;
				end
			$display ("\ncpu test %0d passed", test_number);
		end
		$display ("cpu_tb passed");
		$finish;
	end

endmodule
