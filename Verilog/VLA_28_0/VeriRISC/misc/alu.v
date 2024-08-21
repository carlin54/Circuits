module ALU(
	   input [31:0] a_in,
	   input [31:0] b_in,
	   input [2:0] op_in,
	   output reg [31:0] y_out,
	   output reg z_out
);

always @(a_in or b_in or op_in) begin
	case (op_in)
		3'b000: y_out = a_in + b_in;
		3'b001: y_out = a_in - b_in;
		3'b010: y_out = a_in * b_in;
		3'b100: y_out = (b_in == 0) ? 0 : a_in / b_in;
  	endcase
	z_out = (y_out == 0) ? 1'b1 : 1'b0;
end

endmodule
