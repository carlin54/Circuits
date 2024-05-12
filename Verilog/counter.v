module counter #(
	parameter WIDTH=5
)(
	input [WIDTH-1:0] cnt_in,
	output reg [WIDTH-1:0] cnt_out,
	input enab,
	input load,
	input clk,
	input rst
);


	always @(posedge clk) begin
		if (rst) begin
			cnt_out <= {WIDTH{1'b0}};
		end else if (load) begin
			cnt_out <= cnt_in;
		end else if (enab) begin
			cnt_out <= cnt_out + 1;
		end
	end

endmodule
