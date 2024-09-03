module md5_core_block (
    input wire clk,
    input wire reset,
    input wire [31:0] A,
    input wire [31:0] B,
	input wire [31:0] C,
    input wire [31:0] D,
    input wire enable,
    input wire [511:0] data_in,
    output reg [127:0] hash,
    output reg hash_ready
);
	reg [31:0] M [0:15];
    reg [31:0] A_reg, B_reg, C_reg, D_reg, B_reg_tmp;
    reg [31:0] A_final, B_final, C_final, D_final, B_final_tmp;
    reg [31:0] F_result; reg [6:0] step;
    reg [31:0] K [0:63];
    reg [4:0] s [0:63];

	genvar i;
	generate
		for (i = 0; i < 16; i = i + 1) begin : gen_M
			always @(*) begin
				// Convert each 32-bit word to little-endian format
				M[i] = {data_in[32*i + 0],   // Byte 0 (LSB in little-endian)
						data_in[32*i + 1],   // Byte 1
						data_in[32*i + 2],   // Byte 2
						data_in[32*i + 3],   // Byte 3 (MSB in little-endian)
						data_in[32*i + 4],
						data_in[32*i + 5],
						data_in[32*i + 6],
						data_in[32*i + 7]};
			end
		end
	endgenerate

	/*
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_M
            always @(*) begin M[i] = data_in[32*i + 31 : 32*i]; end
        end
    endgenerate
	*/

	// K constants initialization
	initial begin
		K[0]  = 32'hd76aa478; K[1]  = 32'he8c7b756; K[2]  = 32'h242070db; K[3]  = 32'hc1bdceee;
		K[4]  = 32'hf57c0faf; K[5]  = 32'h4787c62a; K[6]  = 32'ha8304613; K[7]  = 32'hfd469501;
		K[8]  = 32'h698098d8; K[9]  = 32'h8b44f7af; K[10] = 32'hffff5bb1; K[11] = 32'h895cd7be;
		K[12] = 32'h6b901122; K[13] = 32'hfd987193; K[14] = 32'ha679438e; K[15] = 32'h49b40821;
		K[16] = 32'hf61e2562; K[17] = 32'hc040b340; K[18] = 32'h265e5a51; K[19] = 32'he9b6c7aa;
		K[20] = 32'hd62f105d; K[21] = 32'h02441453; K[22] = 32'hd8a1e681; K[23] = 32'he7d3fbc8;
		K[24] = 32'h21e1cde6; K[25] = 32'hc33707d6; K[26] = 32'hf4d50d87; K[27] = 32'h455a14ed;
		K[28] = 32'ha9e3e905; K[29] = 32'hfcefa3f8; K[30] = 32'h676f02d9; K[31] = 32'h8d2a4c8a;
		K[32] = 32'hfffa3942; K[33] = 32'h8771f681; K[34] = 32'h6d9d6122; K[35] = 32'hfde5380c;
		K[36] = 32'ha4beea44; K[37] = 32'h4bdecfa9; K[38] = 32'hf6bb4b60; K[39] = 32'hbebfbc70;
		K[40] = 32'h289b7ec6; K[41] = 32'heaa127fa; K[42] = 32'hd4ef3085; K[43] = 32'h04881d05;
		K[44] = 32'hd9d4d039; K[45] = 32'he6db99e5; K[46] = 32'h1fa27cf8; K[47] = 32'hc4ac5665;
		K[48] = 32'hf4292244; K[49] = 32'h432aff97; K[50] = 32'hab9423a7; K[51] = 32'hfc93a039;
		K[52] = 32'h655b59c3; K[53] = 32'h8f0ccc92; K[54] = 32'hffeff47d; K[55] = 32'h85845dd1;
		K[56] = 32'h6fa87e4f; K[57] = 32'hfe2ce6e0; K[58] = 32'ha3014314; K[59] = 32'h4e0811a1;
		K[60] = 32'hf7537e82; K[61] = 32'hbd3af235; K[62] = 32'h2ad7d2bb; K[63] = 32'heb86d391;
	end

	// s shift amounts initialization
	initial begin
		s[0]  = 7;  s[1]  = 12; s[2]  = 17; s[3]  = 22;
		s[4]  = 7;  s[5]  = 12; s[6]  = 17; s[7]  = 22;
		s[8]  = 7;  s[9]  = 12; s[10] = 17; s[11] = 22;
		s[12] = 7;  s[13] = 12; s[14] = 17; s[15] = 22;

		s[16] = 5;  s[17] = 9;  s[18] = 14; s[19] = 20;
		s[20] = 5;  s[21] = 9;  s[22] = 14; s[23] = 20;
		s[24] = 5;  s[25] = 9;  s[26] = 14; s[27] = 20;
		s[28] = 5;  s[29] = 9;  s[30] = 14; s[31] = 20;

		s[32] = 4;  s[33] = 11; s[34] = 16; s[35] = 23;
		s[36] = 4;  s[37] = 11; s[38] = 16; s[39] = 23;
		s[40] = 4;  s[41] = 11; s[42] = 16; s[43] = 23;
		s[44] = 4;  s[45] = 11; s[46] = 16; s[47] = 23;

		s[48] = 6;  s[49] = 10; s[50] = 15; s[51] = 21;
		s[52] = 6;  s[53] = 10; s[54] = 15; s[55] = 21;
		s[56] = 6;  s[57] = 10; s[58] = 15; s[59] = 21;
		s[60] = 6;  s[61] = 10; s[62] = 15; s[63] = 21;
	end

	reg [31:0] temp_sum;
	reg [31:0] temp_A_F;
	reg [31:0] temp_A_F_M;
	reg [31:0] temp_A_F_M_K;
	reg [31:0] rotated_sum;
	reg [31:0] temp_B_rotated;
	integer j;
	integer message_index;

	// MD5 core computation
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			$display("md5_core: resetting");
			A_reg <= A;
			B_reg <= B;
			C_reg <= C;
			D_reg <= D;
			step <= 0;
			hash_ready <= 0;

		end else if (enable) begin
			if (step < 64) begin
				case (step / 16)
					2'b00: begin
						F_result = (B_reg & C_reg) | (~B_reg & D_reg);  // F function
						message_index = step % 16;
					end
					2'b01: begin
						F_result = (D_reg & B_reg) | (~D_reg & C_reg);  // G function
						message_index = (5 * step + 1) % 16;
					end
					2'b10: begin
						F_result = B_reg ^ C_reg ^ D_reg;              // H function
						message_index = (3 * step + 5) % 16;
					end
					2'b11: begin
						F_result = C_reg ^ (B_reg | ~D_reg);           // I function
						message_index = (7 * step) % 16;
					end
            	endcase

				$display("md5_core: md5_in: %h", data_in);
				for (j = 0; j < 16; j++) begin
					$display("md5_core: msg[%d] = %b", j, M[j]);
				end
				//M[0] = 32'b00000000000000000000000010000000;

				// Display A_reg
				$display("A_reg");
				$display("%h", A_reg);

				// Display A_reg + F_result
				temp_A_F = A_reg + F_result;
				$display("A_reg + F_result");
				$display("%h", temp_A_F);

				temp_A_F_M = temp_A_F + M[message_index];
				$display("A_reg + F_result + M[step %% 16]");
				$display("Result (%%32): %h", temp_A_F_M);
				$display("M (using %%h): %h", M[message_index]);
				$display("M (using %%b): %b", M[message_index]);
				$display("M (using %%d): %d", M[message_index]);
				$display("message index: %d", message_index);
				$display("step: %d", step);
				$display("step modulo: %d", step % 16);
				$display("step: %d", step);

				// Display A_reg + F_result + M[step % 16] + K[step]
				temp_A_F_M_K = temp_A_F_M + K[step];
				$display("A_reg + F_result + M[step %% 16] + K[step]");
				$display("%h", temp_A_F_M_K);

				// Display (A_reg + F_result + M[step % 16] + K[step]) & 32'hFFFFFFFF
				temp_sum = temp_A_F_M_K & 32'hFFFFFFFF;
				$display("(A_reg + F_result + M[step %% 16] + K[step]) & 32'hFFFFFFFF");
				$display("%h", temp_sum);

				// Display (B_reg + left_rotate((A_reg + F_result + M[step % 16] + K[step]) & 32'hFFFFFFFF, s[step]))
				rotated_sum = (temp_sum << s[step]) | (temp_sum >> (32 - s[step]));

				temp_B_rotated = B_reg + rotated_sum;
				$display("(B_reg + left_rotate((A_reg + F_result + M[step %% 16] + K[step]) & 32'hFFFFFFFF, s[step]))");
				$display("%h", temp_B_rotated);

				// Display (B_reg + left_rotate((A_reg + F_result + M[step % 16] + K[step]) & 32'hFFFFFFFF, s[step])) & 32'hFFFFFFFF
				F_result = temp_B_rotated & 32'hFFFFFFFF;
				$display("(B_reg + left_rotate((A_reg + F_result + M[step %% 16] + K[step]) & 32'hFFFFFFFF, s[step])) & 32'hFFFFFFFF");
				$display("%h", F_result);

				A_reg = D_reg;
				D_reg = C_reg;
				C_reg = B_reg;
				B_reg = F_result;

				$display("All: A_reg: %h, B_reg: %h, C_reg: %h, D_reg: %h", A_reg, B_reg, C_reg, D_reg);
				$display("All: A: %h, B: %h, C: %h, D: %h", A, B, C, D);

				//$display("md5_core: Before: m:%h, k:%h, s:%d, A:%h, B:%h, C:%h, D:%h", M[step % 16], K[step], s[step], A_reg, B_reg, C_reg, D_reg);
				/*
				F_result = (B_reg + ((A_reg + F_result + M[step % 16] + K[step]) <<< s[step])) & 32'hFFFFFFFF;
				A_reg = D_reg;
				D_reg = C_reg;
				C_reg = B_reg;
				B_reg = F_result;
				$display("md5_core: After: m:%d, k:%h, s:%d, A:%h, B:%h, C:%h, D:%h", M[step % 16], K[step], s[step], A_reg, B_reg, C_reg, D_reg);*/

				step = step + 1;
				hash_ready = 0;
				A_final = (A + A_reg) & 32'hFFFFFFFF;
				B_final = (B + B_reg) & 32'hFFFFFFFF;
				C_final = (C + C_reg) & 32'hFFFFFFFF;
				D_final = (D + D_reg) & 32'hFFFFFFFF;

				hash = {A_final, B_final, C_final, D_final};
				$display("md5_core: little-endian hash = %h", hash);

			end else begin
				A_final = (A + A_reg) & 32'hFFFFFFFF;
				B_final = (B + B_reg) & 32'hFFFFFFFF;
				C_final = (C + C_reg) & 32'hFFFFFFFF;
				D_final = (D + D_reg) & 32'hFFFFFFFF;
				hash = {A_final, B_final, C_final, D_final};

				$display("md5_core: little-endian hash = %02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h%02h",
					A_final[7:0], A_final[15:8], A_final[23:16], A_final[31:24],
					B_final[7:0], B_final[15:8], B_final[23:16], B_final[31:24],
					C_final[7:0], C_final[15:8], C_final[23:16], C_final[31:24],
					D_final[7:0], D_final[15:8], D_final[23:16], D_final[31:24]);

				$display("md5_core: hash ready, data_in = %h", data_in);
				$display("md5_core: hash ready, hash = %h", hash);
				hash_ready = 1;
			end
		end else begin
			$display("md5_core: stopping hash");
			hash_ready <= 0;
		end
	end

endmodule
