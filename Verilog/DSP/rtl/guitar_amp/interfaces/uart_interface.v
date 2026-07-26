// UART Interface — TX/RX with configurable baud rate
// Used for host communication, preset loading, firmware updates

module uart_interface #(
    parameter CLK_FREQ   = 100_000_000,
    parameter BAUD_RATE  = 115200,
    parameter DATA_BITS  = 8,
    parameter STOP_BITS  = 1,
    parameter PARITY     = "NONE",   // "NONE", "EVEN", "ODD"
    parameter FIFO_DEPTH = 16
)(
    input  wire                    clk,
    input  wire                    rst,

    // TX AXI-Stream (data to send)
    input  wire [DATA_BITS-1:0]    s_axis_tdata,
    input  wire                    s_axis_tvalid,
    output wire                    s_axis_tready,

    // RX AXI-Stream (received data)
    output reg  [DATA_BITS-1:0]    m_axis_tdata,
    output reg                     m_axis_tvalid,
    input  wire                    m_axis_tready,

    // UART pins
    input  wire                    uart_rxd,
    output reg                     uart_txd,

    // Status
    output wire                    tx_busy,
    output reg                     rx_frame_error,
    output reg                     rx_parity_error
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT     = CLKS_PER_BIT / 2;
    localparam CNT_WIDTH    = $clog2(CLKS_PER_BIT);

    // ==================== TX ====================
    localparam TX_IDLE  = 3'd0;
    localparam TX_START = 3'd1;
    localparam TX_DATA  = 3'd2;
    localparam TX_PAR   = 3'd3;
    localparam TX_STOP  = 3'd4;

    reg [2:0] tx_state;
    reg [CNT_WIDTH-1:0] tx_clk_cnt;
    reg [3:0] tx_bit_idx;
    reg [DATA_BITS-1:0] tx_shift;
    reg tx_parity;

    assign tx_busy = (tx_state != TX_IDLE);
    assign s_axis_tready = (tx_state == TX_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_clk_cnt <= 0;
            tx_bit_idx <= 0;
            tx_shift <= 0;
            tx_parity <= 0;
            uart_txd <= 1;  // Idle high
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    uart_txd <= 1;
                    if (s_axis_tvalid) begin
                        tx_shift <= s_axis_tdata;
                        tx_parity <= 0;
                        tx_state <= TX_START;
                        tx_clk_cnt <= 0;
                    end
                end

                TX_START: begin
                    uart_txd <= 0;  // Start bit
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        tx_bit_idx <= 0;
                        tx_state <= TX_DATA;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                TX_DATA: begin
                    uart_txd <= tx_shift[0];
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        tx_parity <= tx_parity ^ tx_shift[0];
                        tx_shift <= {1'b0, tx_shift[DATA_BITS-1:1]};
                        if (tx_bit_idx == DATA_BITS - 1) begin
                            if (PARITY != "NONE")
                                tx_state <= TX_PAR;
                            else
                                tx_state <= TX_STOP;
                            tx_bit_idx <= 0;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 1;
                        end
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                TX_PAR: begin
                    if (PARITY == "EVEN")
                        uart_txd <= tx_parity;
                    else
                        uart_txd <= ~tx_parity;
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        tx_state <= TX_STOP;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                TX_STOP: begin
                    uart_txd <= 1;  // Stop bit
                    if (tx_clk_cnt == CLKS_PER_BIT * STOP_BITS - 1) begin
                        tx_clk_cnt <= 0;
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    // ==================== RX ====================
    localparam RX_IDLE  = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA  = 3'd2;
    localparam RX_PAR   = 3'd3;
    localparam RX_STOP  = 3'd4;

    reg [2:0] rx_state;
    reg [CNT_WIDTH-1:0] rx_clk_cnt;
    reg [3:0] rx_bit_idx;
    reg [DATA_BITS-1:0] rx_shift;
    reg rx_parity;

    // Synchronize RX input
    reg [2:0] rxd_sync;
    wire rxd = rxd_sync[2];

    always @(posedge clk) begin
        if (rst) begin
            rxd_sync <= 3'b111;
            rx_state <= RX_IDLE;
            rx_clk_cnt <= 0;
            rx_bit_idx <= 0;
            rx_shift <= 0;
            rx_parity <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            rx_frame_error <= 0;
            rx_parity_error <= 0;
        end else begin
            rxd_sync <= {rxd_sync[1:0], uart_rxd};

            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            rx_frame_error <= 0;
            rx_parity_error <= 0;

            case (rx_state)
                RX_IDLE: begin
                    if (!rxd) begin
                        // Falling edge = start bit
                        rx_state <= RX_START;
                        rx_clk_cnt <= 0;
                    end
                end

                RX_START: begin
                    // Sample at middle of start bit
                    if (rx_clk_cnt == HALF_BIT - 1) begin
                        if (!rxd) begin
                            // Valid start bit
                            rx_clk_cnt <= 0;
                            rx_bit_idx <= 0;
                            rx_parity <= 0;
                            rx_state <= RX_DATA;
                        end else begin
                            // False start
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= 0;
                        rx_shift <= {rxd, rx_shift[DATA_BITS-1:1]};
                        rx_parity <= rx_parity ^ rxd;
                        if (rx_bit_idx == DATA_BITS - 1) begin
                            if (PARITY != "NONE")
                                rx_state <= RX_PAR;
                            else
                                rx_state <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                RX_PAR: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= 0;
                        if (PARITY == "EVEN")
                            rx_parity_error <= (rx_parity ^ rxd) != 0;
                        else
                            rx_parity_error <= (rx_parity ^ rxd) != 1;
                        rx_state <= RX_STOP;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= 0;
                        if (rxd) begin
                            // Valid stop bit
                            m_axis_tdata <= rx_shift;
                            m_axis_tvalid <= 1;
                        end else begin
                            rx_frame_error <= 1;
                        end
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                default: rx_state <= RX_IDLE;
            endcase
        end
    end

endmodule
