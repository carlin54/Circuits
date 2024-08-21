module multiplexor #(
	parameter DATA_WIDTH = 5
)(
	input wire [DATA_WIDTH-1:0] in0,
	input wire [DATA_WIDTH-1:0] in1,
	input wire sel,
	output reg [DATA_WIDTH-1:0] mux_out
);

always @(in0 or in1 or sel) begin
	case(sel)
		1'b0: mux_out = in0;
		1'b1: mux_out = in1;
		default: mux_out = {DATA_WIDTH{1'b0}};
	endcase
end
endmodule
