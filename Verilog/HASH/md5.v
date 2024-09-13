module md5 (
    input wire clk,
    input wire reset,
    input wire [511:0] part_in,
    input wire part_in_ready,
	input wire [63:0] total_data_length,
    output reg [127:0] hash,
	output reg ready_for_next_part,
    output reg hash_valid
);

    reg enable;
	reg message_block_processed;
    reg [511:0] md5_part_in;
	reg [63:0] data_length;
	reg [63:0] processed_data_length;
	reg [63:0] part_in_length;

    wire md5_core_hash_valid;
	reg prepare_next_hash;

	wire [127:0] hash_wire;
	integer i;

	// MD5 core block processing would go here
	md5_core_block md5_core (
		.clk(clk),
		.reset(reset),
		.enable(enable),
		.data_in(md5_part_in),
		.prepare_next_hash(prepare_next_hash),
		.hash(hash_wire),
		.hash_valid(md5_core_hash_valid)
	);

	// Used for formatting the final data length to the message block correctly
	function [63:0] reverse_bits;
		input [63:0] in;
		integer i;
		begin
			for (i = 0; i < 64; i = i + 1) begin
				reverse_bits[i] = in[63 - i];
			end
		end
	endfunction

	always @(posedge clk) begin

		if (reset) begin
			hash_valid <= 0;
			hash <= 0;
			enable <= 0;
			md5_part_in <= 512'b0;
			message_block_processed <= 0;
			data_length <= 0;
			prepare_next_hash <= 0;
			processed_data_length <= 0;
			ready_for_next_part <= 1;
		end else if (hash_valid) begin
			// Do nothing, wait until reset
		end else if (md5_core_hash_valid && prepare_next_hash) begin
			prepare_next_hash <= 0;
		end else if (md5_core_hash_valid && !prepare_next_hash) begin
			if (processed_data_length >= total_data_length) begin
				if (message_block_processed) begin
					enable <= 0;
					hash <= hash_wire;
					hash_valid <= 1;
					message_block_processed <= 0;
					prepare_next_hash <= 1;
					ready_for_next_part <= 0;
				end else begin
					// Generate the final block
					md5_part_in[0] <= (part_in_length == 512) ? 1 : 0;
					for (i = 1; i < 448; i = i + 1) begin
						md5_part_in[i] <= 0;
					end

					// Place the 64 bit lsb integer at the end of the block
					md5_part_in[511:448] <= reverse_bits({
						total_data_length[7:0],
						total_data_length[15:8],
						total_data_length[23:16],
						total_data_length[31:24],
						total_data_length[39:32],
						total_data_length[47:40],
						total_data_length[55:48],
						total_data_length[63:56]
					});

					enable <= 1;
					prepare_next_hash <= 1;
					hash_valid <= 0;
					message_block_processed <= 1;
					hash <= 0;
				end

			end else begin
				prepare_next_hash <= 1;
				ready_for_next_part <= 1;
				enable <= 0;
			end

		end else if (part_in_ready && !enable) begin
			part_in_length = (total_data_length - processed_data_length < 512) ? (total_data_length - processed_data_length) : 512;
			prepare_next_hash <= 1;
			if (part_in_length == 512) begin
				md5_part_in <= part_in;
				message_block_processed <= 0;
			end if (part_in_length < 448) begin
				// Process the final block
				for (i = 0; i < part_in_length; i = i + 1) begin
					md5_part_in[i] <= part_in[i];
				end

				// Place the final bit
				md5_part_in[part_in_length] <= 1'b1;

				// Add the padding zeros
				for (i = part_in_length + 1; i < 448; i = i + 1) begin
					md5_part_in[i] <= 0;
				end

				// Place the size of the total data, convert msb input to lsb
				md5_part_in[511:448] <= reverse_bits({
					total_data_length[7:0],
					total_data_length[15:8],
					total_data_length[23:16],
					total_data_length[31:24],
					total_data_length[39:32],
					total_data_length[47:40],
					total_data_length[55:48],
					total_data_length[63:56]
				});

				message_block_processed <= 1;

			end else if (part_in_length >= 448 && part_in_length < 512 && !message_block_processed) begin
				// Need to pass two blocks
				md5_part_in <= part_in;

				for (i = 0; i < part_in_length; i = i + 1) begin
					md5_part_in[i] <= part_in[i];
				end

				// Place the final bit
				md5_part_in[part_in_length] <= 1'b1;

				for (i = part_in_length + 1; i < 512; i = i + 1) begin
					md5_part_in[i] <= 0;
				end
				message_block_processed <= 0;
			end
			processed_data_length <= processed_data_length + part_in_length;
			enable <= 1;
			hash_valid <= 0;
			ready_for_next_part <= 0;
		end else begin
			prepare_next_hash <= 0;
			hash_valid <= 0;
		end

	end

endmodule
