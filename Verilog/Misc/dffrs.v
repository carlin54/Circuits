module dffrs (
    input wire d,
    input wire clk,
    input wire r,
    input wire s,
    input wire e,
    output reg q
);
	initial begin
		q = 0;
	end

	always @(posedge clk or posedge r or posedge s) begin
		if (r)
			q <= 1'b0;
		else if (s)
			q <= 1'b1;
		else if (e)
			q <= d;
	end

endmodule
