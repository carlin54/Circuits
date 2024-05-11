module Driver #(
	parameter DATA_WIDTH = 8
)(
	input wire [DATA_WIDTH-1:0] data_in,
	input wire data_en,
	output reg [DATA_WIDTH-1:0] data_out
);

	always @(data_in, data_en) begin
		if (data_en == 1'b1)
			data_out = data_in;
		else
			data_out = {DATA_WIDTH{1'bz}};
	end

endmodule
