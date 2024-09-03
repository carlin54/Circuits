module md5 (
    input wire clk,
    input wire reset,
    input wire [511:0] data_in,
    input wire [8:0] data_in_length,
    input wire data_in_ready,
    output reg [127:0] hash,
    output reg hash_ready
);

    reg enable;
    reg [31:0] A, B, C, D;
    reg process_second_block;  // State to track whether the second block needs to be processed
    reg first_block_processed; // State to track if the first block has been processed
    reg [511:0] md5_data_in;   // Declare as reg since we're going to assign it in an always block
    wire md5_core_hash_ready;
	wire [127:0] hash_wire;

	always @(posedge clk or posedge reset) begin
		if (reset) begin
			$display("md5: resetting", clk, reset);
			hash_ready <= 0;
			hash <= 0;

			A <= 32'h67452301;
			B <= 32'hEFCDAB89;
			C <= 32'h98BADCFE;
			D <= 32'h10325476;

			enable <= 0;
			process_second_block <= 0;
			first_block_processed <= 0;
			md5_data_in <= 512'b0;  // Zero out md5_data_in
			$display("md5: md5_data_in 1:%b", md5_data_in);

		end else if (data_in_ready && !first_block_processed) begin
			if (data_in_length > 447) begin
				process_second_block <= 1'b1;
				md5_data_in <= (data_in << (511 - data_in_length))
                          | (512'b1 << (511 - data_in_length))
                          | (data_in_length << 3);
			end else begin
				process_second_block <= 1'b0;
			end

			// Place the '1' bit right after the original message length
			md5_data_in <= (data_in << 1) | (512'b1 << (data_in_length));
			$display("md5: md5_data_in 2:%b", md5_data_in);

			first_block_processed <= 1'b1;
			enable <= 1'b1;

		end else if (md5_core_hash_ready && process_second_block) begin
			// Second block: zero padding followed by the original length in bits
			md5_data_in <= {448'b0, (data_in_length << 3), 64'b0};
			$display("md5: md5_data_in 3:%b", md5_data_in);

			process_second_block <= 1'b0;  // Reset after processing the second block
			enable <= 1'b1;  // Re-enable for the second block
		end
	end

    // MD5 core block processing would go here
    md5_core_block md5_core (
        .clk(clk),
        .reset(reset),
        .A(A),
        .B(B),
        .C(C),
        .D(D),
        .enable(enable),
        .data_in(md5_data_in),
        .hash(hash_wire),
        .hash_ready(md5_core_hash_ready)
    );

endmodule
