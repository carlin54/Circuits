module register #(
	parameter WIDTH = 8
)(
	output logic [WIDTH-1:0] out,
	input logic [WIDTH-1:0] data,
	input clk,
	input enable,
	input reset
);

	timeunit 1ns;
	timeprecision 100ps;

	always_ff @(posedge clk, negedge reset) begin
		if (!reset) begin
			out <= {WIDTH{1'b0}};
		end else if (enable) begin
			out <= data;
		end
	end

endmodule
