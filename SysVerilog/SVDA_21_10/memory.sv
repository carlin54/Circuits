module memory
	#(
		parameter ADDR_WIDTH=8,
		parameter DATA_WIDTH=8
	)(
		input logic clk,
		input logic read,
		input logic write,
		input logic [ADDR_WIDTH-1:0] addr,
		input logic [DATA_WIDTH-1:0] data_in,
		output logic [DATA_WIDTH-1:0] data_out
	);

	timeunit 1ns;
	timeprecision 1ns;

	logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

	always @(posedge clk) begin
		if (write && !read) begin
			#1;
			mem[addr] <= data_in;
		end
	end

	always_ff @(posedge clk iff ((read == 1'b1) && (write == 1'b0))) begin
       data_out <= mem[addr];
	end

endmodule
