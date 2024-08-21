module fifo_tb;
	localparam DATA_WIDTH=8;
	localparam ADDRESS_WIDTH=8;

	reg [DATA_WIDTH-1:0] wdata;
	reg rst;
	reg wr;
	reg rd;
	reg clk;
	wire empty;
	wire full;
	wire [DATA_WIDTH-1:0] rdata;


	fifo #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDRESS_WIDTH(ADDRESS_WIDTH)
	) DUT (
		.wdata(wdata),
		.rst(rst),
		.wr(wr),
		.rd(rd),
		.clk(clk),
		.empty(empty),
		.full(full),
		.rdata(rdata)
	);

	task assert;
		input [DATA_WIDTH-1:0] exp_rdata;
		input exp_empty;
		input exp_full;

		if (exp_rdata !== rdata || exp_empty !== empty || exp_full !== full) begin
			$display("FAIL: (rdata, %b), (exp_rdata, %b), (empty, %b), (exp_empty, %b), (full, %b), (exp_full, %b)", rdata, exp_rdata, empty, exp_empty, full, exp_full);
		end


	endtask


	initial begin
		#100;

		// Check that it starts empty
		assert(8'b00000000, 1, 0);

		// Try writing 4 elements to the buffer
		wdata = 8'b10101010; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00000000, 0, 0);
		wdata = 8'b01010101; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00000000, 0, 0);
		wdata = 8'b11110000; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00000000, 0, 0);
		wdata = 8'b00001111; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00000000, 0, 0);

		// Try writing 4 elements to the buffer
		wdata = 8'b00000000; wr = 0; rd = 1; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b10101010, 0, 0);
		wdata = 8'b00000000; wr = 0; rd = 1; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b01010101, 0, 0);
		wdata = 8'b00000000; wr = 0; rd = 1; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b11110000, 0, 0);
		wdata = 8'b00000000; wr = 0; rd = 1; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00001111, 1, 0);

		// Try resetting the buffer
		wdata = 8'b10101010; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00001111, 0, 0);
		wdata = 8'b01010101; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00001111, 0, 0);
		wdata = 8'b11110000; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00001111, 0, 0);
		wdata = 8'b00001111; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
		assert(8'b00001111, 0, 0);
		wdata = 8'b11111111; wr = 0; rd = 0; rst = 1; clk = 1; #100; clk = 0;
		assert(8'b00000000, 1, 0);

		// Can fill the buffer
		for (integer i = 0; i < 2**ADDRESS_WIDTH; i++) begin
			wdata = i[7:0]; wr = 1; rd = 0; rst = 0; clk = 1; #100; clk = 0;
			if (i !== (2**ADDRESS_WIDTH)-1) begin
				assert(8'b0000000, 0, 0);
			end else begin
				assert(8'b0000000, 0, 1);
			end
		end

		// Can we read the whole buffer
		for (integer i = 0; i < 2**ADDRESS_WIDTH; i++) begin
			wdata = 8'b0000000; wr = 0; rd = 1; rst = 0; clk = 1; #100; clk = 0;
			if (i === (2**ADDRESS_WIDTH)-1) begin
				assert(i[7:0], 1, 0);
			end else begin
				assert(i[7:0], 0, 0);
			end
		end

	end

endmodule
