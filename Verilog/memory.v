module Memory #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 8
)(
    input wire [ADDR_WIDTH-1:0] addr,
    input wire clk,
    input wire wr,
    input wire rd,
    inout wire [DATA_WIDTH-1:0] data
);

    reg [DATA_WIDTH-1:0] ram [(1<<ADDR_WIDTH)-1:0];

    reg [DATA_WIDTH-1:0] data_out;
    wire [DATA_WIDTH-1:0] data_in = data;

    assign data = rd ? data_out : {DATA_WIDTH{1'bz}};

    always @(posedge clk) begin
        if (wr) begin
            ram[addr] <= data_in;
        end
        if (rd) begin
            data_out <= ram[addr];
        end
    end

endmodule
