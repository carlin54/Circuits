module md5_tb;
    reg clk;
    reg reset;
	reg [511:0] data_in;
    reg data_in_ready;
    reg [8:0] data_in_length;
    wire [127:0] hash;
    wire hash_ready;

    md5 DUT (
        .clk(clk),
        .reset(reset),
        .data_in_ready(data_in_ready),
		.data_in_length(data_in_length),
        .data_in(data_in),
        .hash(hash),
        .hash_ready(hash_ready)
    );

	initial begin
		clk = 0;
		reset = 0;
		data_in_ready = 0;
	end

	always begin
		#5 clk = ~clk;
	end

    task run_test;
        input [511:0] input_data;
		input [8:0] input_data_length;
        input [127:0] expected_hash;
        begin
			@(posedge clk);
            reset <= 1;
			@(posedge clk);
            reset <= 0;
			@(posedge clk);
			data_in <= input_data;
			data_in_length <= input_data_length;
			data_in_ready <= 1;
			#1000;
			$finish;

            wait(hash_ready);

            if (hash === expected_hash) begin
                $display("PASS: Input = %h, Expected Hash = %h, Output Hash = %h", input_data, expected_hash, hash);
            end else begin
                $display("FAIL: Input = %h, Expected Hash = %h, Output Hash = %h", input_data, expected_hash, hash);
            end

			$stop;
			$finish;

        end
    endtask

	integer file;

	//reg [645*2:0] line; // I dont know why
	reg [4095:0] line;
	reg [511:0] input_data;
	reg [8:0] input_data_length;
	reg [127:0] expected_hash;
	integer input_file, output_file, status;

	initial begin

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

				status = $sscanf(line, "%128h %d %32h", input_data, input_data_length, expected_hash);

				if (status != 3) begin
					$display("Error parsing line: \"%s\"", line);
					$stop;
					$finish;
				end

				$display("input_data:%h, input_data_length:%d, expected_hash:%h", input_data, input_data_length, expected_hash);

				run_test(input_data, input_data_length, expected_hash);
			end

			$stop;
			$finish;
		end

		$fclose(file);
		$finish;  // End simulation gracefully
	end


endmodule
