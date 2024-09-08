module md5 (
    input wire clk,
    input wire reset,
    input wire [511:0] part_in,
    input wire part_in_ready,
	input wire [63:0] total_data_length,
    output reg [127:0] hash,
	output reg ready,
    output reg digest_valid
);

    reg enable;
	reg message_block_processed;
    reg [511:0] md5_part_in;
	reg [63:0] data_length;
	reg [63:0] processed_data_length;

	//assign part_in_length = (total_data_length - processed_data_length < 512) ? (total_data_length - processed_data_length) : 512;
	reg [63:0] part_in_length;


    wire md5_core_digest_valid;
	reg prepare_next_hash;

	wire [127:0] hash_wire;
	integer i;

	// MD5 core block processing would go here
	md5_core_block md5_core (
		.clk(clk && enable),
		.reset(reset),
		.enable(enable),
		.data_in(md5_part_in),
		.prepare_next_hash(prepare_next_hash),
		.hash(hash_wire),
		.digest_valid(md5_core_digest_valid)
	);

	function [63:0] reverse_64bit;
		input [63:0] in;
		integer i;
		begin
			for (i = 0; i < 64; i = i + 1) begin
				reverse_64bit[i] = in[63 - i];  // Reverse the bits
			end
		end
	endfunction

	always @(posedge clk or posedge reset) begin
		$display("md5:clk");
		$display("md5: message_block_processed: %b, reset:%b, part_in_ready:%b, enable:%b, md5_core_digest_valid:%b, part_in_length:%d, processed_data_length:%d, total_data_length:%d", message_block_processed, reset, part_in_ready, enable, md5_core_digest_valid, part_in_length, processed_data_length, total_data_length, total_data_length - processed_data_length);
		if (reset) begin
			$display("md5: resetting");
			digest_valid <= 0;
			hash <= 0;
			enable <= 0;
			md5_part_in <= 512'b0;
			message_block_processed <= 0;
			data_length <= 0;
			prepare_next_hash <= 0;
			processed_data_length <= 0;
		end if (digest_valid) begin
			$display("md5: digest is valid, not doing anything");
		end else if (md5_core_digest_valid && prepare_next_hash) begin
			prepare_next_hash <= 0;
		end else if (md5_core_digest_valid && !prepare_next_hash) begin
			$display("md5: digest is valid, processed_data_length:%d, total_data_length:%d, part_in_length:%d", processed_data_length, total_data_length, part_in_length);

			if (processed_data_length >= total_data_length) begin
				$display("md5: processed_data_length == total_data_length");
				//if ((part_in_length == 512)
				//	|| (part_in_length < 448)
				// || (part_in_length >= 448 && part_in_length < 512 && message_block_processed)) begin
				if (message_block_processed) begin
					enable <= 0;
					hash <= hash_wire;
					digest_valid <= 1;
					message_block_processed <= 0;
					prepare_next_hash <= 1;
				//end else if (part_in_length >= 448 && part_in_length < 512 && !message_block_processed) begin
				end else if (!message_block_processed) begin
					// Final block still needs processing
					$display("md5: message_block_processed");

					// Generate the final block
					md5_part_in[0] = (part_in_length == 512) ? 1 : 0;
					for (i = 1; i < 448; i = i + 1) begin
						md5_part_in[i] <= 0;
					end

					// Place the 64 bit lsb integer at the end of the block
					md5_part_in[511:448] <= reverse_64bit({
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
					digest_valid <= 0;
					message_block_processed <= 1;
					hash <= 0;

					$display("md5: prepare_next_hash:%b, message_block_processed: %b, reset:%b, part_in_ready:%b, enable:%b, md5_core_digest_valid:%b", prepare_next_hash, message_block_processed, reset, part_in_ready, enable, md5_core_digest_valid);
				end else begin
					$display("md5: prepare next hash");
					prepare_next_hash <= 1;
				end
			end

		end else if (part_in_ready && !enable) begin
			part_in_length = (total_data_length - processed_data_length < 512) ? (total_data_length - processed_data_length) : 512;
			$display("md5: md5 starting, part_in_length:%d", part_in_length);
			prepare_next_hash <= 1;
			if (part_in_length == 512) begin
				$display("md5: cond part_in_length == 512");
				md5_part_in <= part_in;
				message_block_processed <= 0;
			end if (part_in_length < 448) begin
				$display("md5: cond part_in_length < 448");

				// Process the final block
				for (i = 0; i < part_in_length; i = i + 1) begin
					md5_part_in[i] <= part_in[i];
				end

				// Place the final bit
				md5_part_in[part_in_length] <= 1'b1;

				for (i = part_in_length + 1; i < 448; i = i + 1) begin
					md5_part_in[i] <= 0;
				end

				// Place the 64 bit lsb integer at the end of the block
				md5_part_in[511:448] <= reverse_64bit({
					total_data_length[7:0],
					total_data_length[15:8],
					total_data_length[23:16],
					total_data_length[31:24],
					total_data_length[39:32],
					total_data_length[47:40],
					total_data_length[55:48],
					total_data_length[63:56]
				});

				//$display("md5: part_in after inital:%b", md5_part_in);
				message_block_processed <= 1;
			end else if (part_in_length >= 448 && part_in_length < 512 && !message_block_processed) begin
				$display("md5: first block cond part_in_length >= 448 && part_in_length < 512 && !message_block_processed");
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

			$display("processed_data_length: %d", processed_data_length);
			$display("total_data_length: %d", total_data_length);
			$display("part_in_length: %d", part_in_length);

			processed_data_length <= processed_data_length + part_in_length;
			enable <= 1;
			digest_valid <= 0;
		end else begin
			prepare_next_hash <= 0;
			digest_valid <= 0;
		end

	end


endmodule
