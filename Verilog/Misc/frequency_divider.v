module frequency_divider
# (
	parameter N = 8
)(
	input wire clk,
	input wire rst,
	output reg out_clk
);

	integer counter;

	initial begin
		out_clk <= 0;
		counter <= 0;
	end

	always @(posedge clk or posedge rst) begin
		if (rst === 1) begin
			out_clk <= 0;
			counter <= 0;
		end else begin
			if (counter >= N-1) begin
				out_clk = ~out_clk;
				counter = 0;
			end else begin
				counter = counter + 1;
			end
		end
	end

endmodule
