module multiplexor_tb;
	reg [0:31] in0_1;
	reg [0:4] in0_2;

	reg [0:31] in1_1;
	reg [0:4] in1_2;

	reg sel;

	wire [0:31] mux_out_1;
	wire [0:4] mux_out_2;

	multiplexor #(
		.DATA_WIDTH(32)
	) mux1 (
		.in0(in0_1),
		.in1(in1_1),
		.sel(sel),
		.mux_out(mux_out_1)
	);

	multiplexor #(
		.DATA_WIDTH(5)
	) mux2 (
		.in0(in0_2),
		.in1(in1_2),
		.sel(sel),
		.mux_out(mux_out_2)
	);

	initial begin
		in0_1 = 2; in1_1 = 8; sel = 0; # 100
		if (mux_out_1 == 2) begin
			// $display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);
		end else begin
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);
		end

		in0_1 = 2; in1_1 = 8; sel = 1; # 100
		if (mux_out_1 == 8) begin
			// $display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);
		end else begin
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_1, in1_1, sel, mux_out_1);
		end

		in0_2 = 5'b10101; in1_2 = 5'b01010; sel = 0; # 100
		if (mux_out_2 == 5'b10101) begin
			// $display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);
		end else begin
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);
		end

		in0_2 = 5'b10101; in1_2 = 5'b01010; sel = 1; # 100
		if (mux_out_2 == 5'b01010) begin
			// $display("PASS: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);
		end else begin
			$display("FAIL: (in0,%d), (in1,%d), (sel,%d), (mux_out,%d)", in0_2, in1_2, sel, mux_out_2);
		end

	end
endmodule
