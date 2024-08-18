module memory_tb #(
	parameter ADDR_WIDTH = 5,
	parameter DATA_WIDTH = 8
)(
	input clk,
	output logic read,
	output logic write,
	output logic [ADDR_WIDTH-1:0] addr,
	output logic [DATA_WIDTH-1:0] data_in,
	input logic [DATA_WIDTH-1:0] data_out,
	input debug
);
	timeunit 1ns;
	timeprecision 1ns;


	function void print_ports();
		$display("memory_tb: write:%b, read:%b, addr:%b, data_in:%b, data_out:%b", write, read, addr, data_in, data_out);
	endfunction

	task write_memory(logic [ADDR_WIDTH-1:0] arg_addr, logic [DATA_WIDTH-1:0] arg_data_in);
		@(negedge clk);
		addr <= arg_addr;
		data_in <= arg_data_in;
		write <= 1;
		read <= 0;

		if (debug == 1) begin
			print_ports();
		end

	endtask

	task read_memory(logic [ADDR_WIDTH-1:0] arg_addr);
		@(negedge clk);
		addr <= arg_addr;
		data_in <= 0;
		write <= 0;
		read <= 1;

		if (debug == 1) begin
			print_ports();
		end
	endtask

	task assert_equals(logic [DATA_WIDTH-1:0] expected, logic [DATA_WIDTH-1:0] actual);

		if (expected != actual) begin
			$display("memory_tb failed");
			$display("Assertion failed: expected:%b, actual (data_out):%b", expected, actual);
			$display("write:%b, read:%b, addr:%b, data_in:%b, data_out:%b", write, read, addr, data_in, data_out);
			$finish;
		end

	endtask

	logic signed [ADDR_WIDTH-1:0] i_addr;
	logic signed [DATA_WIDTH-1:0] i_data;
	initial begin: mem_test
		// Write to memory
		i_addr = 0;
		i_data = 0;
		do begin
			write_memory(i_addr, i_data);
			read_memory(i_addr);
			@(negedge clk);
			assert_equals(i_data, data_out);
			i_addr = i_addr + 1;
			i_data = i_data + 1;
		end while (i_addr != {ADDR_WIDTH{1'b0}});


		// Re-read the memory
		i_addr = 0;
		i_data = 0;
		do begin
			read_memory(i_addr);
			@(negedge clk);
			assert_equals(i_data, data_out);
			i_addr = i_addr + 1;
			i_data = i_data + 1;
		end while (i_addr != {ADDR_WIDTH{1'b0}});

		// Zero the memory
		i_addr = 0;
		do begin
			write_memory(i_addr, {DATA_WIDTH{1'b0}});
			read_memory(i_addr);
			@(negedge clk);
			assert_equals({DATA_WIDTH{1'b0}}, data_out);
			i_addr = i_addr + 1;
			i_data = i_data + 1;
		end while (i_addr != {ADDR_WIDTH{1'b0}});

		// Re-read the memory
		i_addr = 0;
		do begin
			read_memory(i_addr);
			@(negedge clk);
			assert_equals({DATA_WIDTH{1'b0}}, data_out);
			i_addr = i_addr + 1;
		end while (i_addr != {ADDR_WIDTH{1'b0}});

		// Complete
		$display("memory_tb passed");
		$finish;
	end

endmodule
