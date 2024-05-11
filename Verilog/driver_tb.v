module Driver_TB;
	reg [7:0] data_in;
	reg data_en;
	wire [7:0] data_out;

	Driver #(
		.DATA_WIDTH(8)
	) driver (
		.data_in(data_in),
		.data_en(data_en),
		.data_out(data_out)
	);

	initial begin
		data_in = 8'b01010101; data_en = 1'b1; # 100
		if (data_out == 8'b01010101)
			$display("PASS: (data_in,%d), (data_en,%d), (data_out,%d)", data_in, data_en, data_out);
		else
			$display("FAIL: (data_in,%d), (data_en,%d), (data_out,%d)", data_in, data_en, data_out);

		data_in = 8'b01010101; data_en = 1'b0; # 100
		if (data_out === 8'bz)
			$display("PASS: (data_in,%d), (data_en,%d), (data_out,%d)", data_in, data_en, data_out);
		else
			$display("FAIL: (data_in,%d), (data_en,%d), (data_out,%d)", data_in, data_en, data_out);

	end

endmodule
