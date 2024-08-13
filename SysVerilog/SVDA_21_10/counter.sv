module counter
	#(
		parameter WIDTH = 8
	)(
		input logic clk,
		input logic reset,
		input logic load,
		input logic enable,
		input [WIDTH-1:0] data,
		output logic [WIDTH-1:0] count
	);
	logic [WIDTH-1:0] i = 0;

	always_ff @(posedge clk) begin
		if (reset) begin
			i = {WIDTH{1'b0}};
		end else if (load) begin
			i = data;
		end else if (enable) begin
			i = i + 1;
		end
		count = i;
	end

endmodule
