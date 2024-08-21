module risc(
	input wire clk,
	input wire rst,
	output wire halt
);
	localparam integer ADDR_WIDTH=5;
	localparam integer DATA_WIDTH=8;

	wire [2:0] phase;

	counter #(
		.WIDTH(3)
	) counter_clk (
		.cnt_in(3'b000),
		.cnt_out(phase),
		.enab(!halt),
		.load(1'b0),
		.clk(clk),
		.rst(rst)
	);

	wire [2:0] opcode;

	controller controller_inst(
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


	wire [ADDR_WIDTH-1:0] ir_addr;
	wire [ADDR_WIDTH-1:0] pc_addr;

	counter #(
		.WIDTH(ADDR_WIDTH)
	) counter_program (
		.cnt_in(ir_addr),
		.cnt_out(pc_addr),
		.enab(inc_pc),
		.load(ld_pc),
		.clk(clk),
		.rst(rst)
	);

	wire [ADDR_WIDTH-1:0] addr;

	multiplexor #(
		.DATA_WIDTH(ADDR_WIDTH)
	) multiplexor_inst (
		.in0(ir_addr),
		.in1(pc_addr),
		.sel(sel),
		.mux_out(addr)
	);

	wire [DATA_WIDTH-1:0] data;

	memory #(
		.ADDR_WIDTH(ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	) memory_inst (
		.clk(clk),
		.wr(wr),
		.rd(rd),
		.data(data),
		.addr(addr)
	);


	register #(
		.DATA_WIDTH(DATA_WIDTH)
	) register_instruction (
		.clk(clk),
		.rst(rst),
		.load(load),
		.data_in(data),
		.data_out({opcode,ir_addr})
	);

	wire [7:0] acc_out;
	wire [7:0] alu_out;

	alu #(
		.WIDTH(DATA_WIDTH)
	) alu_inst (
		.opcode(opcode),
		.in_a(acc_out),
		.in_b(data),
		.a_is_zero(zero),
		.alu_out(alu_out)
	);

	register #(
		.DATA_WIDTH(DATA_WIDTH)
	) accumulator_register (
		.clk(clk),
		.rst(rst),
		.load(ld_ac),
		.data_in(alu_out),
		.data_out(acc_out)
	);


	driver #(
		.DATA_WIDTH(DATA_WIDTH)
	) driver_inst (
		.data_en(data_e),
		.data_in(alu_out),
		.data_out(data)
	);

endmodule
