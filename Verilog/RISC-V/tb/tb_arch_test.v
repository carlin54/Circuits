`timescale 1ns / 1ps

module tb_arch_test;

`ifndef TEST_HEX
    `define TEST_HEX "test.hex"
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

always @(posedge clk) begin
    if (rst_n) begin
        cycle_count <= cycle_count + 1;

        if (halt) begin
            if (dut.regs.regs[10] == 64'd0) begin
                $display("PASS");
            end else begin
                $display("FAIL: a0 = %0d", dut.regs.regs[10]);
            end
            $finish;
        end

        if (dut.memory.out_of_bounds && (dut.ctrl.state == 3'b011)) begin
            $display("FAIL: out-of-bounds memory access at PC=%h", dut.pc_inst.pc_out);
            $finish;
        end

        if (cycle_count >= `MAX_CYCLES) begin
            $display("FAIL: timeout after %0d cycles", `MAX_CYCLES);
            $finish;
        end
    end
end

endmodule
