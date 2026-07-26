// Asynchronous FIFO for clock domain crossing
// Uses Gray-code pointers and multi-stage synchronizers
// Depth must be power of 2

module fifo_async #(
    parameter DATA_WIDTH  = 24,
    parameter DEPTH       = 16,    // Must be power of 2
    parameter SYNC_STAGES = 2      // Synchronizer depth (2 or 3)
)(
    // Write domain
    input  wire                    wr_clk,
    input  wire                    wr_rst,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                    wr_en,
    output wire                    wr_full,

    // Read domain
    input  wire                    rd_clk,
    input  wire                    rd_rst,
    output wire [DATA_WIDTH-1:0]  rd_data,
    input  wire                    rd_en,
    output wire                    rd_empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write domain pointers (binary and Gray)
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    reg [ADDR_WIDTH:0] wr_ptr_gray;
    wire [ADDR_WIDTH:0] wr_ptr_bin_next  = wr_ptr_bin + (wr_en & ~wr_full);
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    // Read domain pointers (binary and Gray)
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_gray;
    wire [ADDR_WIDTH:0] rd_ptr_bin_next  = rd_ptr_bin + (rd_en & ~rd_empty);
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    // Synchronized pointers
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync [0:SYNC_STAGES-1];
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync [0:SYNC_STAGES-1];

    // Full and empty generation
    assign wr_full  = (wr_ptr_gray == {~rd_ptr_gray_sync[SYNC_STAGES-1][ADDR_WIDTH:ADDR_WIDTH-1],
                                         rd_ptr_gray_sync[SYNC_STAGES-1][ADDR_WIDTH-2:0]});
    assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync[SYNC_STAGES-1]);

    // Read data
    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // Write domain logic
    always @(posedge wr_clk) begin
        if (wr_rst) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            if (wr_en && !wr_full)
                mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end

    // Read domain logic
    always @(posedge rd_clk) begin
        if (rd_rst) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // Synchronize read pointer into write domain
    integer i;
    always @(posedge wr_clk) begin
        if (wr_rst) begin
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                rd_ptr_gray_sync[i] <= 0;
        end else begin
            rd_ptr_gray_sync[0] <= rd_ptr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                rd_ptr_gray_sync[i] <= rd_ptr_gray_sync[i-1];
        end
    end

    // Synchronize write pointer into read domain
    always @(posedge rd_clk) begin
        if (rd_rst) begin
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                wr_ptr_gray_sync[i] <= 0;
        end else begin
            wr_ptr_gray_sync[0] <= wr_ptr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                wr_ptr_gray_sync[i] <= wr_ptr_gray_sync[i-1];
        end
    end

endmodule
