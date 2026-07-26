// SPI Slave — Register interface for control parameters
// Supports CPOL/CPHA modes, multi-byte writes with atomic latch

module spi_slave #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter CPOL       = 0,
    parameter CPHA       = 0,
    parameter NUM_REGS   = 64
)(
    input  wire                    clk,
    input  wire                    rst,

    // SPI interface
    input  wire                    spi_clk,
    input  wire                    spi_mosi,
    output reg                     spi_miso,
    input  wire                    spi_cs_n,

    // Register interface (system clock domain)
    output reg  [ADDR_WIDTH-1:0]   reg_addr,
    output reg  [DATA_WIDTH-1:0]   reg_wdata,
    output reg                     reg_we,
    input  wire [DATA_WIDTH-1:0]   reg_rdata
);

    // Synchronize SPI signals to system clock
    reg [2:0] sclk_sync;
    reg [2:0] mosi_sync;
    reg [2:0] cs_sync;

    wire sclk_sys = sclk_sync[2];
    wire mosi_sys = mosi_sync[2];
    wire cs_sys   = cs_sync[2];

    // Edge detection
    wire sclk_rise = sclk_sync[2] && !sclk_sync[1];
    wire sclk_fall = !sclk_sync[2] && sclk_sync[1];
    wire cs_active = !cs_sys;
    wire cs_deassert = cs_sync[2] && !cs_sync[1];

    // Capture/launch edge selection based on CPOL/CPHA
    wire capture_edge = (CPOL ^ CPHA) ? sclk_fall : sclk_rise;
    wire launch_edge  = (CPOL ^ CPHA) ? sclk_rise : sclk_fall;

    // Shift registers
    reg [DATA_WIDTH-1:0] rx_shift;
    reg [DATA_WIDTH-1:0] tx_shift;
    reg [3:0] bit_cnt;
    reg [1:0] byte_cnt;  // Byte position in transaction

    // Transaction state
    localparam ST_ADDR  = 2'd0;
    localparam ST_DATA  = 2'd1;
    localparam ST_MULTI = 2'd2;

    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] current_addr;
    reg rw_bit;  // 0=write, 1=read

    always @(posedge clk) begin
        if (rst) begin
            sclk_sync <= {3{CPOL[0]}};
            mosi_sync <= 0;
            cs_sync <= 3'b111;
            rx_shift <= 0;
            tx_shift <= 0;
            bit_cnt <= 0;
            byte_cnt <= 0;
            state <= ST_ADDR;
            current_addr <= 0;
            rw_bit <= 0;
            reg_addr <= 0;
            reg_wdata <= 0;
            reg_we <= 0;
            spi_miso <= 0;
        end else begin
            // Synchronize
            sclk_sync <= {sclk_sync[1:0], spi_clk};
            mosi_sync <= {mosi_sync[1:0], spi_mosi};
            cs_sync <= {cs_sync[1:0], spi_cs_n};

            reg_we <= 0;

            if (!cs_active) begin
                // CS deasserted — reset transaction
                bit_cnt <= 0;
                byte_cnt <= 0;
                state <= ST_ADDR;
                rx_shift <= 0;
            end else begin
                // Capture data from master on capture edge
                if (capture_edge) begin
                    rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi_sys};
                    bit_cnt <= bit_cnt + 1;

                    if (bit_cnt == DATA_WIDTH - 1) begin
                        bit_cnt <= 0;

                        case (state)
                            ST_ADDR: begin
                                // First byte: R/W bit + address
                                rw_bit <= rx_shift[DATA_WIDTH-2];  // MSB of received is R/W
                                current_addr <= {rx_shift[DATA_WIDTH-3:0], mosi_sys};
                                state <= ST_DATA;

                                // For reads, load tx data
                                if (rx_shift[DATA_WIDTH-2]) begin
                                    reg_addr <= {rx_shift[DATA_WIDTH-3:0], mosi_sys};
                                end
                            end

                            ST_DATA: begin
                                if (!rw_bit) begin
                                    // Write: commit data
                                    reg_addr <= current_addr;
                                    reg_wdata <= {rx_shift[DATA_WIDTH-2:0], mosi_sys};
                                    reg_we <= 1;
                                end
                                // Auto-increment for multi-byte
                                current_addr <= current_addr + 1;
                                state <= ST_MULTI;
                            end

                            ST_MULTI: begin
                                if (!rw_bit) begin
                                    reg_addr <= current_addr;
                                    reg_wdata <= {rx_shift[DATA_WIDTH-2:0], mosi_sys};
                                    reg_we <= 1;
                                end
                                current_addr <= current_addr + 1;
                            end

                            default: state <= ST_ADDR;
                        endcase
                    end
                end

                // Launch data to master on launch edge
                if (launch_edge) begin
                    if (rw_bit) begin
                        spi_miso <= tx_shift[DATA_WIDTH-1];
                        tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                    end
                end

                // Load TX shift register when address byte is complete (for reads)
                // Pre-drive MSB on MISO so it's ready before first rising edge
                if (state == ST_DATA && rw_bit && bit_cnt == 0) begin
                    tx_shift <= {reg_rdata[DATA_WIDTH-2:0], 1'b0};
                    spi_miso <= reg_rdata[DATA_WIDTH-1];
                end
            end
        end
    end

endmodule
