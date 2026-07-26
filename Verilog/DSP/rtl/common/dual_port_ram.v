// Parameterized true dual-port RAM
// Infers block RAM or distributed RAM based on RAM_STYLE hint
// Supports optional initialization from hex file

module dual_port_ram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 24,
    parameter INIT_FILE  = "",
    parameter RAM_STYLE  = "block"  // "block" or "distributed"
)(
    input  wire                    clk,

    // Port A
    input  wire                    we_a,
    input  wire [ADDR_WIDTH-1:0]  addr_a,
    input  wire [DATA_WIDTH-1:0]  din_a,
    output reg  [DATA_WIDTH-1:0]  dout_a,

    // Port B
    input  wire                    we_b,
    input  wire [ADDR_WIDTH-1:0]  addr_b,
    input  wire [DATA_WIDTH-1:0]  din_b,
    output reg  [DATA_WIDTH-1:0]  dout_b
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

    // Port A
    always @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    // Port B
    always @(posedge clk) begin
        if (we_b)
            mem[addr_b] <= din_b;
        dout_b <= mem[addr_b];
    end

endmodule
