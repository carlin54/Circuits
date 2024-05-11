module Multiplexor_TB;
	reg [0:31] in0_1;
	reg [0:4] in0_2;

	reg [0:31] in1_1;
	reg [0:4] in1_2;

	reg sel;

	wire [0:31] mux_out_1;
	wire [0:4] mux_out_2;

	Multiplexor #(
		.DATA_WIDTH(32)
	) mux1(
		.in0(in0_1),
		.in1(in1_1),
		.sel(sel),
		.mux_out(mux_out_1)
	);


	Multiplexor #(
		.DATA_WIDTH(5)
	) mux2 (
		.in0(in0_2),
		.in1(in1_2),
		.sel(sel),
		.mux_out(mux_out_2)
	);

	initial begin
		in0_1 = 100; in1_1 = 200; sel = 0; # 100
		if (mux_out_1 == 100)
			$display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);
		else
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);

		in0_1 = 100; in1_1 = 200; sel = 1; # 100
		if (mux_out_1 == 200)
			$display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);
		else
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);


		in0_2 = 1; in1_2 = 12; sel = 0; # 100
		if (mux_out_2 == 1)
			$display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);
		else
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);

		in0_2 = 1; in1_2 = 12; sel = 1; # 100
		if (mux_out_2 == 12)
			$display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);
		else
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);
	end
endmodule
