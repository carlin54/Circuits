module counter #(
	parameter WIDTH = 5
)(
	output logic [WIDTH-1:0] count,
	input logic [WIDTH-1:0] data,
	input clk,
	input load,
	input reset,
	input enable);

	timeunit 1ns;
	timeprecision 100ps;

	always_ff @(posedge clk or negedge reset) begin
		if (!reset)
			count <= {WIDTH{1'b0}};
		else if (load) begin
			count <= data;
		end else if (enable)  begin
			count <= count + 1;
		end
	end

endmodule
