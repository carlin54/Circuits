module memory_tb;
	reg [4:0] addr;
	wire [7:0] data;
	reg [7:0] data_in;
	reg clk;
	reg wr;
	reg rd;

	memory #(
		.ADDR_WIDTH(5),
		.DATA_WIDTH(8)
	) memory_inst (
		.addr(addr),
		.data(data),
		.clk(clk),
		.wr(wr),
		.rd(rd)
	);


	integer data_i;
	integer addr_i;
	reg [7:0] expected_data;

	assign data = wr ? data_in : (rd ? 8'bz : 8'bz);

	initial
	begin
		addr = 5'b0000; data_in = 8'b11110000; rd=0; wr=1; clk=1; #100 clk=0; #5
		addr = 5'b0000; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0; #5

		if (data == 8'b11110000) begin
			// $display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end


		addr = 5'b11111; data_in = 8'b00001111; rd=0; wr=1; clk=1; #100 clk=0; #5
		addr = 5'b11111; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0; #5
		if (data == 8'b00001111) begin
			// $display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end

		addr = 5'b10101; data_in = 8'b10101010; rd=0; wr=1; clk=1; #100 clk=0; #5
		addr = 5'b10101; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0; #5
		if (data == 8'b10101010) begin
			// $display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end


		addr = 5'b01010; data_in = 8'b01010101; rd=0; wr=1; clk=1; #100 clk=0; #5
		addr = 5'b01010; data_in = 8'b00000000; rd=1; wr=0; clk=1; #100 clk=0; #5
		if (data == 8'b01010101) begin
			// $display("PASS: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end else begin
			$display("FAIL: (addr,%d), (data,%d), (rd,%d), (wr,%d)", addr, data, rd, wr);
		end

		for (data_i = 0; data_i < 256; data_i++) begin

			// Write memory with data
			for (addr_i = 0; addr_i < 32; addr_i++) begin
				expected_data = data_i[7:0];

				// Write data
				addr = addr_i; data_in = data_i[7:0]; 	wr = 1; rd = 0; #100 clk = 1; #100 clk = 0; #5

				// Read data
				addr = addr_i; data_in = 8'b00000000; 	wr = 0; rd = 1; #100 clk = 1; #100 clk = 0; #5

				// Read data for the second time
				addr = addr_i; data_in = 8'b00000000; 	wr = 0; rd = 1; #100 clk = 1; #100 clk = 0;

				if (data !== expected_data) begin
					$display("FAIL: (addr, %b), (data, %b), (wr, %b), (rd, %b), (expected_data, %b)", addr, data, wr, rd, expected_data);
				end
			end


			// Write memory with data
			for (addr_i = 0; addr_i < 32; addr_i++) begin
				expected_data = 8'b00000000;

				// Write data
				addr = addr_i; data_in = 8'b00000000; 	wr = 1; rd = 0; #100 clk = 1; #100 clk = 0; #5

				// Read data
				addr = addr_i; data_in = 8'b00000000; 	wr = 0; rd = 1; #100 clk = 1; #100 clk = 0; #5

				// Read data for the second time
				addr = addr_i; data_in = 8'b00000000; 	wr = 0; rd = 1; #100 clk = 1; #100 clk = 0;

				if (data !== expected_data) begin
					$display("FAIL: (addr, %b), (data, %b), (wr, %b), (rd, %b), (expected_data, %b)", addr, data, wr, rd, expected_data);
				end
			end


        end
	end

endmodule
