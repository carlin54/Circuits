module l1ca_generator(
	input clk,
	input set,
	input rst,
	input [0:9] in_taps,
	output reg out
);

	reg [0:9] g1;
	reg [0:9] g2;
	reg [0:9] taps;
	reg g1_output;
	reg g2_output;
	wire g1_feedback = g1[2] ^ g1[9];
    wire g2_feedback = g2[1] ^ g2[2] ^ g2[5] ^ g2[7] ^ g2[8] ^ g2[9];
	integer counter = 0;

	always @(posedge clk) begin
		if (set) begin
			g1 = 10'b1111111111;
			g2 = 10'b1111111111;
			taps = in_taps;
			g1_output = g1[9];
			g2_output = 1'b0;
			out = g1_output ^ g2_output;
			counter = 0;
		end else if (rst || counter >= 1023) begin
			g1 = 10'b1111111111;
			g2 = 10'b1111111111;
			g1_output = g1[9];
			g2_output = 1'b0;
			out = g1_output ^ g2_output;
			counter = 0;
		end else begin
			g1_output = g1[9];
			g2_output = 1'b0;
			for (integer i = 0; i < 10; i++) begin
				if (taps[i]) begin
					g2_output = g2_output ^ g2[i];
				end
			end

			out = g1_output ^ g2_output;
			g1 = {g1_feedback, g1[0:8]};
			g2 = {g2_feedback, g2[0:8]};

			counter += 1;
		end
	end

endmodule
