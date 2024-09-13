module md5_core_block (
    input wire clk,
    input wire reset,
    input wire prepare_next_hash,
    input wire enable,
    input wire [511:0] data_in,
    input wire reset_hash_valid,
    output reg [127:0] hash,
    output reg hash_valid
);
	reg [31:0] M [0:15];
    reg [31:0] A_reg, B_reg, C_reg, D_reg, B_reg_tmp;
    reg [31:0] A, B, C, D;
	reg [31:0] F_result; reg [6:0] step;
    reg [31:0] K [0:63];
    reg [4:0] s [0:63];

	function [31:0] reverse_bits;
		input [31:0] word;
		integer j;
		begin
			for (j = 0; j < 32; j = j + 1) begin
				reverse_bits[j] = word[31 - j];  // Reverse the order of the bits in the 32-bit word
			end
		end
	endfunction

	genvar i;
	generate
		for (i = 0; i < 16; i = i + 1) begin : gen_M
			always @(*) begin
				M[i] <= reverse_bits({
					data_in[32*i + 7: 32*i],      	// Byte 0 -> Byte 3 (LSB to MSB)
					data_in[32*i + 15: 32*i + 8],  	// Byte 1 -> Byte 2
					data_in[32*i + 23: 32*i + 16], 	// Byte 2 -> Byte 1
					data_in[32*i + 31: 32*i + 24]  	// Byte 3 -> Byte 0 (MSB to LSB)
				});
			end
		end
	endgenerate

	integer j;

	// MD5 core computation
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			A <= 32'h67452301;
			B <= 32'hEFCDAB89;
			C <= 32'h98BADCFE;
			D <= 32'h10325476;

			A_reg <= 32'h67452301;
			B_reg <= 32'hEFCDAB89;
			C_reg <= 32'h98BADCFE;
			D_reg <= 32'h10325476;

			step <= 0;
			hash_valid <= 0;

			// Initilise shift constants
			s[0]  <= 7;  s[1]  <= 12; s[2]  <= 17; s[3]  <= 22;
			s[4]  <= 7;  s[5]  <= 12; s[6]  <= 17; s[7]  <= 22;
			s[8]  <= 7;  s[9]  <= 12; s[10] <= 17; s[11] <= 22;
			s[12] <= 7;  s[13] <= 12; s[14] <= 17; s[15] <= 22;

			s[16] <= 5;  s[17] <= 9;  s[18] <= 14; s[19] <= 20;
			s[20] <= 5;  s[21] <= 9;  s[22] <= 14; s[23] <= 20;
			s[24] <= 5;  s[25] <= 9;  s[26] <= 14; s[27] <= 20;
			s[28] <= 5;  s[29] <= 9;  s[30] <= 14; s[31] <= 20;

			s[32] <= 4;  s[33] <= 11; s[34] <= 16; s[35] <= 23;
			s[36] <= 4;  s[37] <= 11; s[38] <= 16; s[39] <= 23;
			s[40] <= 4;  s[41] <= 11; s[42] <= 16; s[43] <= 23;
			s[44] <= 4;  s[45] <= 11; s[46] <= 16; s[47] <= 23;

			s[48] <= 6;  s[49] <= 10; s[50] <= 15; s[51] <= 21;
			s[52] <= 6;  s[53] <= 10; s[54] <= 15; s[55] <= 21;
			s[56] <= 6;  s[57] <= 10; s[58] <= 15; s[59] <= 21;
			s[60] <= 6;  s[61] <= 10; s[62] <= 15; s[63] <= 21;

			// Initilise K constants
			K[0]  <= 32'hd76aa478; K[1]  <= 32'he8c7b756; K[2]  <= 32'h242070db; K[3]  <= 32'hc1bdceee;
			K[4]  <= 32'hf57c0faf; K[5]  <= 32'h4787c62a; K[6]  <= 32'ha8304613; K[7]  <= 32'hfd469501;
			K[8]  <= 32'h698098d8; K[9]  <= 32'h8b44f7af; K[10] <= 32'hffff5bb1; K[11] <= 32'h895cd7be;
			K[12] <= 32'h6b901122; K[13] <= 32'hfd987193; K[14] <= 32'ha679438e; K[15] <= 32'h49b40821;
			K[16] <= 32'hf61e2562; K[17] <= 32'hc040b340; K[18] <= 32'h265e5a51; K[19] <= 32'he9b6c7aa;
			K[20] <= 32'hd62f105d; K[21] <= 32'h02441453; K[22] <= 32'hd8a1e681; K[23] <= 32'he7d3fbc8;
			K[24] <= 32'h21e1cde6; K[25] <= 32'hc33707d6; K[26] <= 32'hf4d50d87; K[27] <= 32'h455a14ed;
			K[28] <= 32'ha9e3e905; K[29] <= 32'hfcefa3f8; K[30] <= 32'h676f02d9; K[31] <= 32'h8d2a4c8a;
			K[32] <= 32'hfffa3942; K[33] <= 32'h8771f681; K[34] <= 32'h6d9d6122; K[35] <= 32'hfde5380c;
			K[36] <= 32'ha4beea44; K[37] <= 32'h4bdecfa9; K[38] <= 32'hf6bb4b60; K[39] <= 32'hbebfbc70;
			K[40] <= 32'h289b7ec6; K[41] <= 32'heaa127fa; K[42] <= 32'hd4ef3085; K[43] <= 32'h04881d05;
			K[44] <= 32'hd9d4d039; K[45] <= 32'he6db99e5; K[46] <= 32'h1fa27cf8; K[47] <= 32'hc4ac5665;
			K[48] <= 32'hf4292244; K[49] <= 32'h432aff97; K[50] <= 32'hab9423a7; K[51] <= 32'hfc93a039;
			K[52] <= 32'h655b59c3; K[53] <= 32'h8f0ccc92; K[54] <= 32'hffeff47d; K[55] <= 32'h85845dd1;
			K[56] <= 32'h6fa87e4f; K[57] <= 32'hfe2ce6e0; K[58] <= 32'ha3014314; K[59] <= 32'h4e0811a1;
			K[60] <= 32'hf7537e82; K[61] <= 32'hbd3af235; K[62] <= 32'h2ad7d2bb; K[63] <= 32'heb86d391;

		end else if (prepare_next_hash) begin
			step <= 0;
			hash_valid <= 0;
		end else if (enable && !hash_valid) begin
			case (step / 16)
				2'b00: begin
					// F function
					F_result =
						(B_reg + (((((A_reg + ((B_reg & C_reg) | (~B_reg & D_reg)) & 32'hFFFFFFFF) + M[step % 16] + K[step]) & 32'hFFFFFFFF) << s[step])
						| ((((A_reg + ((B_reg & C_reg) | (~B_reg & D_reg)) & 32'hFFFFFFFF) + M[step % 16] + K[step]) & 32'hFFFFFFFF) >> (32 - s[step])))) & 32'hFFFFFFFF;
				end
				2'b01: begin
					// G function
					F_result =
						(B_reg + (((((A_reg + ((D_reg & B_reg) | (~D_reg & C_reg)) & 32'hFFFFFFFF) + M[(5 * step + 1) % 16] + K[step]) & 32'hFFFFFFFF) << s[step])
						| ((((A_reg + ((D_reg & B_reg) | (~D_reg & C_reg)) & 32'hFFFFFFFF) + M[(5 * step + 1) % 16] + K[step]) & 32'hFFFFFFFF) >> (32 - s[step])))) & 32'hFFFFFFFF;
				end
				2'b10: begin
					// H function
					F_result =
						(B_reg + (((((A_reg + (B_reg ^ C_reg ^ D_reg) & 32'hFFFFFFFF) + M[(3 * step + 5) % 16] + K[step]) & 32'hFFFFFFFF) << s[step])
						| ((((A_reg + (B_reg ^ C_reg ^ D_reg) & 32'hFFFFFFFF) + M[(3 * step + 5) % 16] + K[step]) & 32'hFFFFFFFF) >> (32 - s[step])))) & 32'hFFFFFFFF;
				end
				2'b11: begin
					// I function
					F_result =
						(B_reg + (((((A_reg + (C_reg ^ (B_reg | ~D_reg)) & 32'hFFFFFFFF) + M[(7 * step) % 16] + K[step]) & 32'hFFFFFFFF) << s[step])
						| ((((A_reg + (C_reg ^ (B_reg | ~D_reg)) & 32'hFFFFFFFF) + M[(7 * step) % 16] + K[step]) & 32'hFFFFFFFF) >> (32 - s[step])))) & 32'hFFFFFFFF;
				end
			endcase

			A_reg = D_reg;
			D_reg = C_reg;
			C_reg = B_reg;
			B_reg = F_result;

			if (step != 63) begin
				step <= step + 1;
			end else begin
				A = (A + A_reg) & 32'hFFFFFFFF;
				B = (B + B_reg) & 32'hFFFFFFFF;
				C = (C + C_reg) & 32'hFFFFFFFF;
				D = (D + D_reg) & 32'hFFFFFFFF;
				A_reg <= A;
				B_reg <= B;
				C_reg <= C;
				D_reg <= D;

				// Convert the hash to msb
				hash <= {
					A[7:0], A[15:8], A[23:16], A[31:24],
					B[7:0], B[15:8], B[23:16], B[31:24],
					C[7:0], C[15:8], C[23:16], C[31:24],
					D[7:0], D[15:8], D[23:16], D[31:24]
				};

				hash_valid <= 1;
			end
		end
	end
endmodule
