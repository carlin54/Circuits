// Parameterized single-port RAM
// Infers block RAM or distributed RAM based on RAM_STYLE hint
// Supports optional initialization from hex file

module single_port_ram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 24,
    parameter INIT_FILE  = "",
    parameter RAM_STYLE  = "block"  // "block" or "distributed"
)(
    input  wire                    clk,
    input  wire                    we,
    input  wire [ADDR_WIDTH-1:0]  addr,
    input  wire [DATA_WIDTH-1:0]  din,
    output reg  [DATA_WIDTH-1:0]  dout
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    (* ram_style = RAM_STYLE *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Optional initialization
    generate
        if (INIT_FILE != "") begin : gen_init
            initial begin
                $readmemh(INIT_FILE, mem);
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end

endmodule
