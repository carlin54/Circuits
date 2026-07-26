module pc #(
    parameter RESET_ADDR = 64'h80000000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pc_write,
    input  wire [63:0] next_pc,
    output reg  [63:0] pc_out
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pc_out <= RESET_ADDR;
    else if (pc_write)
        pc_out <= next_pc;
end

endmodule
