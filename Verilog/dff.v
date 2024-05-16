module dff (
    input wire clk,       // Clock input
    input wire d,         // Data input
    output reg q          // Output
);

	initial begin
		q = 0;
	end

	always @(posedge clk) begin
		q <= d;               // Transfer input to output on clock edge
	end

endmodule
