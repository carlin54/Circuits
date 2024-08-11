module mux
	#(
		parameter WIDTH = 8
	)(
		input logic [WIDTH-1:0] in_a,
		input logic [WIDTH-1:0] in_b,
		input sel_a,
		output logic [WIDTH-1:0] out
	);

	always_comb begin
		unique case (sel_a)
			1'b1: 		out = in_a;
			1'b0: 		out = in_b;
			default: 	out = {WIDTH{1'b0}};
		endcase
	end
endmodule
