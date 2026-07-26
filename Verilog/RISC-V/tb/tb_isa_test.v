`timescale 1ns / 1ps

module tb_isa_test;

`ifndef TEST_HEX
    `define TEST_HEX "test.hex"
`endif

`ifndef TOHOST_ADDR
    `define TOHOST_ADDR 0
`endif

`ifndef MAX_CYCLES
    `define MAX_CYCLES 100000
`endif

reg clk, rst_n;
integer cycle_count;
reg [63:0] tohost_val;
integer i;
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

always @(posedge clk) begin
    if (rst_n) begin
        cycle_count <= cycle_count + 1;

        // Check tohost memory location
        tohost_val = 64'b0;
        for (i = 0; i < 8; i = i + 1) begin
            tohost_val = tohost_val | ({56'b0, dut.memory.mem[`TOHOST_ADDR + i]} << (i * 8));
        end

        if (tohost_val != 0) begin
            if (tohost_val == 64'd1) begin
                $display("PASS");
                $finish;
            end else begin
                $display("FAIL: test case %0d", tohost_val >> 1);
                $finish;
            end
        end

        // Also check halt (ecall) — RVTEST_PASS ends with ecall after writing tohost
        if (halt) begin
            // Re-check tohost one more time (write may have landed this cycle)
            tohost_val = 64'b0;
            for (i = 0; i < 8; i = i + 1)
                tohost_val = tohost_val | ({56'b0, dut.memory.mem[`TOHOST_ADDR + i]} << (i * 8));
            if (tohost_val == 64'd1 || dut.regs.regs[10] == 64'd0) begin
                $display("PASS");
            end else begin
                $display("FAIL: test case %0d", tohost_val >> 1);
            end
            $finish;
        end

        if (cycle_count >= `MAX_CYCLES) begin
            $display("FAIL: timeout after %0d cycles", `MAX_CYCLES);
            $finish;
        end
    end
end

endmodule
