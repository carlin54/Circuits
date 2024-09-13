module md5_tb;
    reg clk;
    reg reset;
	reg [511:0] md5_data_in;
    reg md5_part_in_ready;
    reg [63:0] md5_total_data_in_length;
    wire [127:0] hash;
    wire hash_ready;
	wire ready_for_next_part;

    md5 DUT (
        .clk(clk),
        .reset(reset),
        .part_in_ready(md5_part_in_ready),
		.total_data_length(md5_total_data_in_length),
        .part_in(md5_data_in),
        .hash(hash),
        .hash_valid(hash_ready),
		.ready_for_next_part(ready_for_next_part)
    );

	initial begin
		clk <= 0;
		reset <= 0;
		md5_part_in_ready <= 0;
	end

	always begin
		#5 clk = ~clk;
	end

	integer j;

	reg [63:0] data_idx;
	reg [63:0] processed;
	reg loop_enabled;
    task run_test;
        input [2047:0] input_data;
		input [63:0] input_data_length;
        input [127:0] expected_hash;
        begin
			$display("md5_tb: run_test: input_data: %b", input_data);
			$display("md5_tb: run_test: input_data: %h", input_data);
			$display("md5_tb: run_test: input_data_length: %d", input_data_length);
			$display("md5_tb: run_test: expected_hash: %h", expected_hash);
			@(posedge clk);
			reset = 1;

			@(posedge clk);
			reset = 0;

			md5_total_data_in_length = input_data_length;
			data_idx = 2047;
			processed = 0;
			loop_enabled = md5_total_data_in_length == 0;
			while (processed < md5_total_data_in_length || loop_enabled) begin
				$display("md5_tb: run_test: start processing part: hash_ready:%b, ready_for_next_part:%b, processed: %d, total_data_length:%d", hash_ready, ready_for_next_part, processed, md5_total_data_in_length);
				for (j = 0; j < 512; j = j + 1) begin
					if (processed < input_data_length) begin
						md5_data_in[j] = input_data[data_idx];
					end else begin
						md5_data_in[j] = 1'bz;
					end
					data_idx = data_idx - 1;
					processed = processed + 1;
				end
				$display("md5_tb: run_test: processed: %d, data_idx: %d", processed, data_idx);
				$display("md5_tb: run_test: md5_data_in: %b", md5_data_in);
				md5_part_in_ready <= 1;
				wait(!ready_for_next_part);

				md5_part_in_ready <= 0;

				wait(hash_ready || ready_for_next_part);


				$display("md5_tb: run_test: end processing part: hash_ready:%b, ready_for_next_part:%b, processed: %d, total_data_length:%d", hash_ready, ready_for_next_part, processed, md5_total_data_in_length);
				loop_enabled = 0;
			end

			if (hash_ready == 1) begin
				$display("PASS: actual hash_ready:%b, expected hash_ready:%b", hash_ready, 1);
			end else begin
				$display("FAIL: actual hash_ready:%b, expected hash_ready:%b", hash_ready, 1);
				$stop;
				$finish;
			end

			if (ready_for_next_part == 0) begin
				$display("PASS: actual ready_for_next_part:%b, expected ready_for_next_part:%b", ready_for_next_part, 0);
			end else begin
				$display("FAIL: actual ready_for_next_part:%b, expected ready_for_next_part:%b", ready_for_next_part, 0);
				$stop;
				$finish;
			end

			if (hash === expected_hash) begin
				$display("PASS: Input = %h, Expected Hash = %h, Output Hash = %h", input_data, expected_hash, hash);
			end else begin
				$display("FAIL: Input = %h, Expected Hash = %h, Output Hash = %h", input_data, expected_hash, hash);
				$stop;
				$finish;
			end


        end
    endtask

	integer file;

	reg [8192:0] line;
	reg [2047:0] input_data;
	reg [63:0] input_data_length;
	reg [127:0] expected_hash;
	integer input_file, output_file, status;

	initial begin

		input_data_length = 0;
		file = $fopen("md5_hashes.txt", "r");
		if (file == 0) begin
			$display("Error opening file.");
			$finish;
		end

		while (!$feof(file)) begin
			// Read the entire line
			status = $fgets(line, file);
			if (status != 0) begin

				$display("Raw line:\"%s\"", line);

				status = $sscanf(line, "%512h %d %32h", input_data, input_data_length, expected_hash);

				if (status != 3) begin
					$display("Error parsing line: \"%s\"", line);
					$stop;
					$finish;
				end

				$display("md5_tb: input_data:%h", input_data);
				$display("md5_tb: input_data_length:%h", input_data_length);
				$display("md5_tb: expected_hash:%h", expected_hash);

				run_test(input_data, input_data_length, expected_hash);
			end

		end

		$fclose(file);
		$finish;
		$stop;
	end


endmodule
