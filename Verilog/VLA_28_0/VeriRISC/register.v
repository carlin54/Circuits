module register #(
	parameter DATA_WIDTH=8
)(
	input [DATA_WIDTH-1:0] data_in,
	input load,
	input clk,
	input rst,
	output reg [DATA_WIDTH-1:0] data_out
);


	always @(posedge clk) begin
		if (rst) begin
			data_out = {DATA_WIDTH{1'b0}};
		end else if (load) begin
			data_out = data_in;
		end
	end

endmodule
