module ir (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ir_write,
    input  wire [31:0] instr_in,
    output reg  [31:0] instr_out
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        instr_out <= 32'b0;
    else if (ir_write)
        instr_out <= instr_in;
end

endmodule
