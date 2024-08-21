module l1ca_generator_tb;
	reg clk;
	reg set;
	reg rst;
	wire out;

	reg [0:9] in_taps;
	reg [0:9] actual_output;

	l1ca_generator l1ca_generator_inst(
		.clk(clk),
		.set(set),
		.rst(rst),
		.in_taps(in_taps),
		.out(out)
	);

	task clock (input integer number);
		repeat (number) begin clk=0; #100; clk=1; #100; end
	endtask


	// Refernce [p7-8]: https://naic.nrao.edu/arecibo/phil/rfi/gps/AFD-070803-059-1.pdf
	parameter NUM_SVS = 32;
	reg [9:0] first_10_chips[NUM_SVS-1:0];
	reg [31:0] tap1[31:0];
	reg [31:0] tap2[31:0];

	reg [9:0] expected_output;
	initial begin
        $readmemh("l1ca_generator_tap1.hex", tap1);
        $readmemh("l1ca_generator_tap2.hex", tap2);
        $readmemh("l1ca_generator_octals.hex", first_10_chips);
		rst = 0;
        for (integer i = 0; i < NUM_SVS; i++) begin
            $display("i:%d, Tap1: %h, Tap2: %h, Octal: %h", i + 1, tap1[i], tap2[i], first_10_chips[i]);
        end

		for (integer sv = 0; sv < NUM_SVS; sv++) begin
			in_taps <= 10'b0000000000;

			in_taps[tap1[sv] - 1] <= 1'b1;
			in_taps[tap2[sv] - 1] <= 1'b1;
			expected_output <= first_10_chips[sv];

			// Check set
			set = 1'b1;
			clock(1);
			set=1'b0;

			for (integer i = 0; i < 10; i++) begin
				clock(1);
				actual_output[i] = out;
				g1_actual_output[i] = g1_output;
				g2_actual_output[i] = g2_output;
			end

			if (actual_output !== expected_output) begin
				$display("FAIL: (sv:%d), (g1:%b), (g2:%b), (actual:%b), (expected:%b)", sv + 1, g1_actual_output, g2_actual_output, actual_output, expected_output);
				$stop;
			end

			// Check reset
			rst = 1'b1;
			clock(1);
			rst =1'b0;

			for (integer i = 0; i < 10; i++) begin
				clock(1);
				actual_output[i] = out;
				g1_actual_output[i] = g1_output;
				g2_actual_output[i] = g2_output;
			end

			if (actual_output !== expected_output) begin
				$display("FAIL: (sv:%d), (g1:%b), (g2:%b), (actual:%b), (expected:%b)", sv + 1, g1_actual_output, g2_actual_output, actual_output, expected_output);
				$stop;
			end

			// Check roll-over
			rst = 1'b1;
			clock(1);
			rst =1'b0;
			clock(1023);

			for (integer i = 0; i < 10; i++) begin
				clock(1);
				actual_output[i] = out;
				g1_actual_output[i] = g1_output;
				g2_actual_output[i] = g2_output;
			end

		end

	end

endmodule
