module dff (
    input wire clk,
    input wire d,
    output reg q
);

	initial begin
		q = 0;
	end

	always @(posedge clk) begin
		q <= d;
	end

endmodule
