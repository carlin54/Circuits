module cpu(
	output logic halt,
	output logic load_ir,
	input logic clk,
	input logic cntrl_clk,
	input logic alu_clk,
	input logic fetch,
	input logic reset
);

	timeunit 1ns;
	timeprecision 100ps;

	import typedefs::*;

	logic [7:0] data_out, alu_out, accum, ir_out;
	logic [4:0] pc_addr, ir_addr, addr;

	opcode_t opcode;
	logic load_ac, mem_rd, mem_wr, inc_pc, load_pc, zero;

	register ac(
		.out(accum),
		.data(alu_out),
		.clk(clk),
		.enable(load_ac),
		.reset(reset)
	);

	register ir(
		.out (ir_out),
		.data(data_out),
		.clk(clk),
		.enable (load_ir),
		.reset(reset)
	);

	assign opcode =  opcode_t'(ir_out[7:5]);

	assign ir_addr = ir_out[4:0];

	counter pc(
		.count(pc_addr),
		.data(ir_addr),
		.clk(clk),
		.load(load_pc),
		.enable(inc_pc),
		.reset(reset)
	);

	alu alu1(
		.out(alu_out),
		.zero(zero),
		.clk(alu_clk),
		.accum,
		.data(data_out),
		.opcode
	);

	mux #5 mux(
		.out (addr),
		.in_a(pc_addr),
		.in_b(ir_addr),
		.sel_a(fetch)
	);

	memory memory1(
		.clk(~cntrl_clk),
		.read(mem_rd),
		.write(mem_wr),
		.addr(addr),
		.data_in(alu_out),
		.data_out(data_out)
	);


	controller cntl(
		.load_ac(load_ac),
		.mem_rd(mem_rd),
		.mem_wr(mem_wr),
		.inc_pc(inc_pc),
		.load_pc(load_pc),
		.load_ir(load_ir),
		.halt(halt),
		.opcode(opcode),
		.zero(zero),
		.clk(cntrl_clk),
		.reset(reset)
	);

endmodule
