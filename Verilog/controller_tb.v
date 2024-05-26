module controller_tb;
	reg [2:0] opcode;
  	reg [2:0] phase;
	reg zero;
	wire sel;
	wire rd;
	wire ld_ir;
  	wire inc_pc;
  	wire halt;
  	wire ld_pc;
  	wire data_e;
  	wire ld_ac;
  	wire wr;

	controller DUT(
		.zero(zero),
		.phase(phase),
		.opcode(opcode),
		.sel(sel),
		.rd(rd),
		.ld_ir(ld_ir),
		.halt(halt),
		.inc_pc(inc_pc),
		.ld_ac(ld_ac),
		.ld_pc(ld_pc),
		.wr(wr),
		.data_e(data_e)
	);

	task expect;
		input [8:0] exp_out;
		if ({sel,rd,ld_ir,inc_pc,halt,ld_pc,data_e,ld_ac,wr} !== exp_out) begin
		  $display("\nTEST FAILED");
		  $display("time\topcode phase zero sel rd ld_ir inc_pc halt ld_pc data_e ld_ac wr");
		  $display("====\t====== ===== ==== === == ===== ====== ==== ===== ====== ===== ==");
		  $display("%0d\t%d      %d     %b    %b   %b  %b     %b      %b    %b     %b      %b     %b",
				   $time, opcode, phase, zero, sel, rd, ld_ir, inc_pc, halt, ld_pc,
				   data_e, ld_ac, wr);
		  $display("WANT\t                  %b   %b  %b     %b      %b    %b     %b      %b     %b",
				   exp_out[8],exp_out[7],exp_out[6],exp_out[5],exp_out[4],exp_out[3],exp_out[2],exp_out[1],exp_out[0]);
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
	localparam [2:0] PHASE_INST_FETCH 	= 3'b001;
	localparam [2:0] PHASE_INST_LOAD 	= 3'b010;
	localparam [2:0] PHASE_IDLE 		= 3'b011;
	localparam [2:0] PHASE_OP_ADDR 		= 3'b100;
	localparam [2:0] PHASE_OP_FETCH 	= 3'b101;
	localparam [2:0] PHASE_OP_ALU_OP 	= 3'b110;
	localparam [2:0] PHASE_ALU_OP 		= 3'b111;
	localparam [2:0] PHASE_STORE 		= 3'b111;


	initial begin

		opcode=OP_HLT; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect(9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect(9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect(9'b111000000);
		phase=PHASE_IDLE; 		#100 expect(9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect(9'b000110000);
		phase=PHASE_OP_FETCH; 	#100 expect(9'b000000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect(9'b000000000);
		phase=PHASE_STORE; 		#100 expect(9'b000000000);
		$display("PASS: (opcode, OP_HLT, %d)", opcode);

		opcode=OP_SKZ; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect(9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect(9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect(9'b111000000);
		phase=PHASE_IDLE; 		#100 expect(9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect(9'b000100000);
		phase=PHASE_OP_FETCH; 	#100 expect(9'b000000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect(9'b000000000);
		zero=1; 				#100 expect(9'b000100000);
		phase=PHASE_STORE; 		#100 expect(9'b000000000);
		//$display("PASS: (opcode, OP_SKZ, %d)", opcode);

		opcode=OP_ADD; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect (9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect (9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect (9'b111000000);
		phase=PHASE_IDLE; 		#100 expect (9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect (9'b000100000);
		phase=PHASE_OP_FETCH; 	#100 expect (9'b010000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect (9'b010000000);
		phase=PHASE_STORE; 		#100 expect (9'b010000010);
		//$display("PASS: (opcode, OP_ADD, %d)", opcode);

		opcode=OP_AND; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect (9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect (9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect (9'b111000000);
		phase=PHASE_IDLE; 		#100 expect (9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect (9'b000100000);
		phase=PHASE_OP_FETCH; 	#100 expect (9'b010000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect (9'b010000000);
		phase=PHASE_STORE; 		#100 expect (9'b010000010);
		//$display("PASS: (opcode, OP_AND, %d)", opcode);

		opcode=OP_XOR; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect (9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect (9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect (9'b111000000);
		phase=PHASE_IDLE; 		#100 expect (9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect (9'b000100000);
		phase=PHASE_OP_FETCH; 	#100 expect (9'b010000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect (9'b010000000);
		phase=PHASE_STORE; 		#100 expect (9'b010000010);
		//$display("PASS: (opcode, OP_XOR, %d)", opcode);

		opcode=OP_LDA; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect (9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect (9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect (9'b111000000);
		phase=PHASE_IDLE; 		#100 expect (9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect (9'b000100000);
		phase=PHASE_OP_FETCH; 	#100 expect (9'b010000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect (9'b010000000);
		phase=PHASE_STORE; 		#100 expect (9'b010000010);
		//$display("PASS: (opcode, OP_LDA, %d)", opcode);

		opcode=OP_STO; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect (9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect (9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect (9'b111000000);
		phase=PHASE_IDLE; 		#100 expect (9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect (9'b000100000);
		phase=PHASE_OP_FETCH; 	#100 expect (9'b000000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect (9'b000000100);
		phase=PHASE_STORE; 		#100 expect (9'b000000101);
		//$display("PASS: (opcode, OP_STO, %d)", opcode);

		opcode=OP_JMP; zero=0;
		phase=PHASE_INST_ADDR; 	#100 expect (9'b100000000);
		phase=PHASE_INST_FETCH; #100 expect (9'b110000000);
		phase=PHASE_INST_LOAD; 	#100 expect (9'b111000000);
		phase=PHASE_IDLE; 		#100 expect (9'b111000000);
		phase=PHASE_OP_ADDR; 	#100 expect (9'b000100000);
		phase=PHASE_OP_FETCH; 	#100 expect (9'b000000000);
		phase=PHASE_OP_ALU_OP; 	#100 expect (9'b000001000);
		phase=PHASE_STORE; 		#100 expect (9'b000001000);
		//$display("PASS: (opcode, OP_JMP, %d)", opcode);

	end

endmodule
