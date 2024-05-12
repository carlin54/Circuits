module Memory_TB;
	reg [4:0] addr;
	wire [7:0] data;
	reg [7:0] data_in;
	reg clk;
	reg wr;
	reg rd;

	Memory #(
		.ADDR_WIDTH(5),
		.DATA_WIDTH(8)
	) memory (
		.addr(addr),
		.data(data),
		.clk(clk),
		.wr(wr),
		.rd(rd)
	);

	assign data = wr ? data_in : (rd ? 8'bz : 8'bz);

	initial
	begin
		addr = 5'b0000; data_in = 8'b11110000; rd=0; wr=1; clk=1; #100 clk=0;
		addr = 5'b0000; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0;

		if (data == 8'b11110000) begin
			$display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end


		addr = 5'b11111; data_in = 8'b00001111; rd=0; wr=1; clk=1; #100 clk=0;
		addr = 5'b11111; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0;
		if (data == 8'b00001111) begin
			$display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end

		addr = 5'b10101; data_in = 8'b10101010; rd=0; wr=1; clk=1; #100 clk=0;
		addr = 5'b10101; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0;
		if (data == 8'b10101010) begin
			$display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end


		addr = 5'b01010; data_in = 8'b01010101; rd=0; wr=1; clk=1; #100 clk=0;
		addr = 5'b01010; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0;
		if (data == 8'b01010101) begin
			$display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end

	end

endmodule
