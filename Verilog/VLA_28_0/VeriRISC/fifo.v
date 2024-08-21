module fifo #(
	parameter DATA_WIDTH = 8,
	parameter ADDRESS_WIDTH = 8
)(
	input [DATA_WIDTH-1:0] wdata,
	input rst,
	input wr,
	input rd,
	input clk,
	output wire empty,
	output wire full,
	output reg [DATA_WIDTH-1:0] rdata
);

	localparam STACK_SIZE=2**ADDRESS_WIDTH;
	reg [DATA_WIDTH-1:0] stack [0:STACK_SIZE-1];

	reg [ADDRESS_WIDTH-1:0] write_ptr;
	reg [ADDRESS_WIDTH-1:0] read_ptr;
	reg wrote;

	initial begin
		read_ptr <= {ADDRESS_WIDTH{1'b0}};
		write_ptr <= {ADDRESS_WIDTH{1'b0}};
		rdata <= {ADDRESS_WIDTH{1'b0}};
		wrote <= 1'b0;
	end

	assign empty = (read_ptr == write_ptr) && !wrote;
	assign full = (read_ptr == write_ptr) && wrote;

	always @(posedge clk or posedge rst) begin

		if (rst) begin
			read_ptr = {ADDRESS_WIDTH{1'b0}};
			write_ptr = {ADDRESS_WIDTH{1'b0}};
			rdata <= {ADDRESS_WIDTH{1'b0}};
			wrote <= 1'b0;
		end else begin

			if (rd && !empty) begin
				rdata <= stack[read_ptr];
				read_ptr <= read_ptr + 1;
				wrote <= 1'b0;
			end

			if (wr && !full) begin
				stack[write_ptr] <= wdata;
				write_ptr <= write_ptr + 1;
				wrote <= 1'b1;
			end

		end


	end

endmodule
