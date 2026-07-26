// Synchronous FIFO
// Single clock domain, parameterized depth (must be power of 2) and width

module fifo_sync #(
    parameter DATA_WIDTH = 24,
    parameter DEPTH      = 16,   // Must be power of 2
    parameter ALMOST_FULL_THRESH  = DEPTH - 2,
    parameter ALMOST_EMPTY_THRESH = 2
)(
    input  wire                    clk,
    input  wire                    rst,

    // Write interface
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                    wr_en,
    output wire                    full,
    output wire                    almost_full,

    // Read interface
    output wire [DATA_WIDTH-1:0]  rd_data,
    input  wire                    rd_en,
    output wire                    empty,
    output wire                    almost_empty,

    // Status
    output wire [$clog2(DEPTH):0] count
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0]   wr_ptr;
    reg [ADDR_WIDTH:0]   rd_ptr;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    assign count = wr_ptr - rd_ptr;
    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    assign almost_full  = (count >= ALMOST_FULL_THRESH);
    assign almost_empty = (count <= ALMOST_EMPTY_THRESH);

    assign rd_data = mem[rd_addr];

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_addr] <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule
