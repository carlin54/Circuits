module register_tb;
	reg [7:0] data_in;
	reg load;
	reg clk;
	reg rst;
	wire [7:0] data_out;

	register #(
		.DATA_WIDTH(8)
	) DUT (
		.data_in(data_in),
		.load(load),
		.clk(clk),
		.rst(rst),
		.data_out(data_out)
	);

	initial
	begin
		// Reset the register with high load
		data_in=8'b01010101; load=1'b1; clk=1'b1; rst=1'b1; #100 clk=1'b0; # 100
		if (data_out == 8'b00000000) begin
			// $display("PASS: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end else begin
			$display("FAIL: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end

		// Reset with low load
		data_in=8'b01010101; load=1'b0; clk=1'b1; rst=1'b1; #100 clk=1'b0; # 100
		if (data_out == 8'b00000000) begin
			// $display("PASS: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end else begin
			$display("FAIL: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end

		// No load high
		data_in=8'b01010101; load=1'b0; clk=1'b1; rst=1'b0; #100 clk=1'b0; # 100
		if (data_out == 8'b00000000) begin
			// $display("PASS: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end else begin
			$display("FAIL: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end

		// No clock -> no load
		data_in=8'b01010101; load=1'b0; clk=1'b0; rst=1'b0; #100 clk=1'b0; # 100
		if (data_out == 8'b00000000) begin
			// $display("PASS: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end else begin
			$display("FAIL: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end

		// Load
		data_in=8'b01010101; load=1'b1; clk=1'b1; rst=1'b0; #100 clk=1'b0; # 100
		if (data_out == 8'b01010101) begin
			// $display("PASS: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end else begin
			$display("FAIL: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end

		// Load again
		data_in=8'b10101010; load=1'b1; clk=1'b1; rst=1'b0; #100 clk=1'b0; # 100
		if (data_out == 8'b10101010) begin
			// $display("PASS: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end else begin
			$display("FAIL: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end

		// No clk, no reset
		data_in=8'b00000000; load=1'b0; clk=1'b0; rst=1'b1; #100 clk=1'b0; # 100
		if (data_out == 8'b10101010) begin
			// $display("PASS: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end else begin
			$display("FAIL: (data_in, %d), (load, %b), (rst, %b), (data_out, %d)", data_in, load, rst, data_out);
		end

	end
	endmodule
