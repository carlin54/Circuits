module memory #(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 5
)(
    input clk,
	input read,
	input write,
	input logic [ADDR_WIDTH-1:0] addr,
	input logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);

	timeunit 1ns;
	timeprecision 1ns;

	logic [DATA_WIDTH-1:0] memory [0:(2**ADDR_WIDTH)-1];

	always @(posedge clk) begin
		if (write && !read) begin
			#1 memory[addr] <= data_in;
		end
	end

	always_ff @(posedge clk iff ((read == '1) && (write == '0))) begin
		data_out <= memory[addr];
	end

endmodule
