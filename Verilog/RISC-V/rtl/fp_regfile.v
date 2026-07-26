module fp_regfile (
    input  wire        clk,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rs3_addr,
    input  wire [4:0]  rd_addr,
    input  wire [63:0] rd_data,
    input  wire        fp_reg_write,
    output wire [63:0] rs1_data,
    output wire [63:0] rs2_data,
    output wire [63:0] rs3_data
);

reg [63:0] regs [0:31];

assign rs1_data = regs[rs1_addr];
assign rs2_data = regs[rs2_addr];
assign rs3_data = regs[rs3_addr];

always @(posedge clk) begin
    if (fp_reg_write)
        regs[rd_addr] <= rd_data;
end

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1)
        regs[i] = 64'b0;
end

endmodule
