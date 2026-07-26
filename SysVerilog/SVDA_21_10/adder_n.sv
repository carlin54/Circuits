module adder_n #(
 parameter	BITS = 8
)(
	input logic [BITS-1:0] a,
	input logic [BITS-1:0] b,
	input logic cin,
	output logic [BITS-1:0] sum,
	output logic cout
);

	logic [BITS-1:0] carry;
	genvar i;
	generate
		for (i = 0; i < BITS; i++) begin : gen_full_adder
			if (i == 0) begin
				adder a(
					.a(a[i]),
					.b(b[i]),
					.cin(cin),
					.sum(sum[i]),
					.cout(carry[i])
				);
			end else begin
				adder a(
					.a(a[i]),
					.b(b[i]),
					.cin(carry[i-1]),
					.sum(sum[i]),
					.cout(carry[i])
				);
			end
		end
	endgenerate
	assign cout = carry[BITS-1];

endmodule
