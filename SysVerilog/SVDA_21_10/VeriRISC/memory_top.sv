module memory_top;

	timeunit 1ns;
	timeprecision 1ns;

	parameter ADDR_WIDTH = 5;
	parameter DATA_WIDTH = 8;

	bit clk;
	wire read;
	wire write;

	wire [ADDR_WIDTH-1:0] addr;
	wire [DATA_WIDTH-1:0] data_out;
	wire [DATA_WIDTH-1:0] data_in;

	logic debug = 0;

	memory_tb #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH)
	) DUT_TB (.*, .debug(debug));

	memory #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH)
	) DUT(.*);

	always begin
		#5
		clk = ~clk;
	end

endmodule
