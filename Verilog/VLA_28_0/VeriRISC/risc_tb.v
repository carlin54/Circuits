module risc_tb;

	reg clk;
	reg rst;
	wire halt;


	risc risc_inst (
		.clk(clk),
		.rst(rst),
		.halt(halt)
	);


	task clock (input integer number);
		repeat (number) begin clk=0; #10; clk=1; #10; end
	endtask

	task reset;
		begin
			rst = 1; clock(1);
			rst = 0; clock(1);
		end
	endtask

	task assert (input exp_halt);
		if (halt !== exp_halt) begin
			$display("FAILED: (time, %0d), (halt, %b), (asserted, %b)", $time, halt, exp_halt);
			$finish;
		end
	endtask


	localparam [2:0] OP_HLT = 3'b000;
	localparam [2:0] OP_SKZ = 3'b001;
	localparam [2:0] OP_ADD = 3'b010;
	localparam [2:0] OP_AND = 3'b011;
	localparam [2:0] OP_XOR = 3'b100;
	localparam [2:0] OP_LDA = 3'b101;
	localparam [2:0] OP_STO = 3'b110;
	localparam [2:0] OP_JMP = 3'b111;

	localparam [2:0] PHASE_INST_ADDR 	= 3'b000;
	localparam [2:0] PHASE_INST_FETCH	= 3'b001;
	localparam [2:0] PHASE_INST_LOAD 	= 3'b010;
	localparam [2:0] PHASE_IDLE 		= 3'b011;
	localparam [2:0] PHASE_OP_ADDR 		= 3'b100;
	localparam [2:0] PHASE_OP_FETCH 	= 3'b101;
	localparam [2:0] PHASE_OP_ALU_OP 	= 3'b110;
	localparam [2:0] PHASE_ALU_OP 		= 3'b111;
	localparam [2:0] PHASE_STORE 		= 3'b111;


	initial begin
		$display("Testing reset, time: %d", $time);
		risc_inst.memory_inst.ram[0] = { OP_HLT, 5'bx };
		reset;
		assert(0);

		$display("Testing HLT instruction, time: %d", $time);
		risc_inst.memory_inst.ram[0] = { OP_HLT, 5'bx };
		reset;
		clock(2); assert(0); clock(1); assert(1);

		$display("Testing XOR instruction");
		risc_inst.memory_inst.ram[0] = { OP_LDA, 5'd10};
		risc_inst.memory_inst.ram[1] = { OP_XOR, 5'd11};
		risc_inst.memory_inst.ram[2] = { OP_SKZ, 5'bx };
		risc_inst.memory_inst.ram[3] = { OP_JMP, 5'd5 };
		risc_inst.memory_inst.ram[4] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[5] = { OP_XOR, 5'd12};
		risc_inst.memory_inst.ram[6] = { OP_SKZ, 5'bx };
		risc_inst.memory_inst.ram[7] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[8] = { OP_JMP, 5'd9 };
		risc_inst.memory_inst.ram[9] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[10]= { 8'h55};
		risc_inst.memory_inst.ram[11]= { 8'h54};
		risc_inst.memory_inst.ram[12]= { 8'h01};
		reset;
		for (integer i = 0; i < 58; i++) begin
			clock(1);
			assert(0);
		end
		clock(1); assert(1);

		$display("Testing AND instruction");
		risc_inst.memory_inst.ram[0] = { OP_LDA, 5'd10};
		risc_inst.memory_inst.ram[1] = { OP_AND, 5'd11};
		risc_inst.memory_inst.ram[2] = { OP_SKZ, 5'bx };
		risc_inst.memory_inst.ram[3] = { OP_JMP, 5'd5 };
		risc_inst.memory_inst.ram[4] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[5] = { OP_AND, 5'd12};
		risc_inst.memory_inst.ram[6] = { OP_SKZ, 5'bx };
		risc_inst.memory_inst.ram[7] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[8] = { OP_JMP, 5'd9 };
		risc_inst.memory_inst.ram[9] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[10]= { 8'hff };
		risc_inst.memory_inst.ram[11]= { 8'h01 };
		risc_inst.memory_inst.ram[12]= { 8'hfe };
		reset;
		clock(58); assert(0); clock(1); assert(1);


		$display("Testing ADD instruction");
		risc_inst.memory_inst.ram[0] = { OP_LDA, 5'd9 };
		risc_inst.memory_inst.ram[1] = { OP_ADD, 5'd11};
		risc_inst.memory_inst.ram[2] = { OP_SKZ, 5'bx };
		risc_inst.memory_inst.ram[3] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[4] = { OP_ADD, 5'd11};
		risc_inst.memory_inst.ram[5] = { OP_SKZ, 5'bx };
		risc_inst.memory_inst.ram[6] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[7] = { OP_JMP, 5'd9 };
		risc_inst.memory_inst.ram[8] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[9] = { 8'hff};
		risc_inst.memory_inst.ram[11]= { 8'h01};
		reset;
		clock(42); assert(0); clock(1); assert(1);

		$display("Testing JMP instruction, time: %d", $time);
		risc_inst.memory_inst.ram[0] = { OP_JMP, 5'd2 };
		risc_inst.memory_inst.ram[1] = { OP_JMP, 5'd2 };
		risc_inst.memory_inst.ram[2] = { OP_HLT, 5'bx };
		reset;
		clock(10); assert(0); clock(1); assert(1);

		$display("Testing STO instruction, time: %d", $time);
		risc_inst.memory_inst.ram[0] = { OP_LDA, 5'd7 };
		risc_inst.memory_inst.ram[1] = { OP_STO, 5'd8 };
		risc_inst.memory_inst.ram[2] = { OP_LDA, 5'd8 };
		risc_inst.memory_inst.ram[3] = { OP_SKZ, 5'bx };
		risc_inst.memory_inst.ram[4] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[5] = { OP_JMP, 5'd6 };
		risc_inst.memory_inst.ram[6] = { OP_HLT, 5'bx };
		risc_inst.memory_inst.ram[7] = { 8'd1 };
		risc_inst.memory_inst.ram[8] = { 8'd0 };
		reset;
		clock(34);
		assert(0);
		clock(1);
		assert(1);

	end


endmodule
