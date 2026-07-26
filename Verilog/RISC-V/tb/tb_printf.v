`timescale 1ns / 1ps

module tb_printf;

`ifndef TEST_HEX
    `define TEST_HEX "build/printf.hex"
`endif

`ifndef MAX_CYCLES
    `define MAX_CYCLES 10_000_000
`endif

reg clk, rst_n;
integer cycle_count;
wire halt;

top #(
    .HEX_FILE(`TEST_HEX)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .halt(halt)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    cycle_count = 0;
    #20;
    rst_n = 1;
end

// Capture UART output into buffer
reg [7:0] uart_buf [0:1023];
integer uart_len;

initial uart_len = 0;

// Expected output
reg [7:0] expected [0:255];
integer expected_len;

initial begin
    // "Hello, RISC-V!\n40 + 2 = 42\nhex: dead\nnegative: -123\nchar: Z\nstring: world\nlong: 1000000000000\npercent: 100%\n"
    expected_len = 0;
    store_str("Hello, RISC-V!\n");
    store_str("40 + 2 = 42\n");
    store_str("hex: dead\n");
    store_str("negative: -123\n");
    store_str("char: Z\n");
    store_str("string: world\n");
    store_str("long: 1000000000000\n");
    store_str("percent: 100%\n");
end

task store_str(input [255:0] s);
    integer i;
    reg [7:0] c;
    begin
        for (i = 31; i >= 0; i = i - 1) begin
            c = s[(i*8) +: 8];
            if (c != 0) begin
                expected[expected_len] = c;
                expected_len = expected_len + 1;
            end
        end
    end
endtask

always @(posedge clk) begin
    if (rst_n) begin
        cycle_count <= cycle_count + 1;

        if (dut.uart_tx_valid) begin
            uart_buf[uart_len] = dut.uart_tx_data;
            uart_len = uart_len + 1;
        end

        if (halt) begin
            if (dut.regs.regs[10] != 64'd0) begin
                $display("FAIL: main() returned %0d", dut.regs.regs[10]);
                $finish;
            end
            // Verify UART output matches expected
            if (uart_len != expected_len) begin
                $display("FAIL: output length %0d != expected %0d", uart_len, expected_len);
                $finish;
            end
            begin : check_block
                integer i;
                for (i = 0; i < uart_len; i = i + 1) begin
                    if (uart_buf[i] != expected[i]) begin
                        $display("FAIL: byte %0d: got 0x%02x expected 0x%02x", i, uart_buf[i], expected[i]);
                        $finish;
                    end
                end
            end
            $display("PASS");
            $finish;
        end

        if (cycle_count >= `MAX_CYCLES) begin
            $display("FAIL: timeout");
            $finish;
        end
    end
end

endmodule
