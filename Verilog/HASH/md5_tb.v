module md5_tb;
    reg clk;
    reg reset;
	reg [511:0] data_in;
    reg data_in_ready;
    reg [63:0] data_in_length;
    wire [127:0] hash;
    wire hash_ready;

    md5 DUT (
        .clk(clk),
        .reset(reset),
        .part_in_ready(data_in_ready),
		.total_data_length(data_in_length),
        .part_in(data_in),
        .hash(hash),
        .digest_valid(hash_ready)
    );

	initial begin
		clk <= 0;
		reset <= 0;
		data_in_ready <= 0;
	end

	always begin
		#5 clk = ~clk;
	end

	integer j;
    task run_test;
        input [511:0] input_data;
		input [63:0] input_data_length;
        input [127:0] expected_hash;
        begin
			for (j = 0; j < 512; j = j + 1) begin
				data_in[j] = input_data[511 - j];
			end
			data_in_length = input_data_length;

			//$display("input_data (b): %b", input_data);
			//$display("data_in (b): %b", data_in);
			$display("md5_tb: data_in_length: %d", data_in_length);
			@(posedge clk);
            reset <= 1;

			@(posedge clk);
            reset <= 0;

			@(posedge clk);
			data_in_ready <= 1;
            wait(hash_ready);

			@(posedge clk);
			data_in_ready = 0;

            $display("ah = %b", hash);
            $display("eh = %b", expected_hash);
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

	//reg [645*2:0] line; // I dont know why
	reg [8192:0] line;
	reg [511:0] input_data;
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

				$display("input_data:%h, input_data_length:%d, expected_hash:%h", input_data, input_data_length, expected_hash);
				$stop;
				$finish;
				run_test(input_data, input_data_length, expected_hash);
			end

		end

		$fclose(file);
		$finish;  // End simulation gracefully
	end


endmodule
