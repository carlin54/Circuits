// System Top — FPGA top-level with PLL, pin assignments, reset
// Target: Lattice ECP5 (ULX3S or similar dev board)

module system_top (
    input  wire        clk_25mhz,     // 25 MHz crystal

    // I2S ADC (input from guitar)
    input  wire        i2s_adc_bclk,
    input  wire        i2s_adc_lrclk,
    input  wire        i2s_adc_sdata,

    // I2S DAC (output to speaker/headphones)
    output wire        i2s_dac_mclk,
    output wire        i2s_dac_bclk,
    output wire        i2s_dac_lrclk,
    output wire        i2s_dac_sdata,

    // SPI (control knobs via external ADC)
    input  wire        spi_clk,
    input  wire        spi_mosi,
    output wire        spi_miso,
    input  wire        spi_cs_n,

    // UART (host communication)
    input  wire        uart_rx,
    output wire        uart_tx,

    // User interface
    input  wire [3:0]  btn,            // Footswitches / buttons
    output wire [3:0]  led,            // Status LEDs

    // Reset
    input  wire        rst_n           // Active-low external reset
);

    // ==================== Clock Generation ====================
    // PLL: 25 MHz -> 100 MHz system clock
    wire clk_100mhz;
    wire pll_locked;

    // ECP5 PLL instantiation (behavioral for simulation)
    `ifdef SYNTHESIS
    // Lattice ECP5 PLL primitive
    (* FREQUENCY_PIN_CLKI="25" *)
    (* FREQUENCY_PIN_CLKOP="100" *)
    EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(1),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(6),
        .CLKOP_CPHASE(5),
        .CLKOP_FPHASE(0),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(4)
    ) u_pll (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(clk_25mhz),
        .CLKOP(clk_100mhz),
        .CLKFB(clk_100mhz),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b0),
        .PHASELOADREG(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(pll_locked)
    );
    `else
    // Simulation: pass through clock
    assign clk_100mhz = clk_25mhz;
    assign pll_locked = 1'b1;
    `endif

    // ==================== Reset Synchronizer ====================
    wire rst_raw = !rst_n || !pll_locked;
    reg [3:0] rst_shift;
    wire rst_sync = rst_shift[3];

    always @(posedge clk_100mhz or posedge rst_raw) begin
        if (rst_raw)
            rst_shift <= 4'b1111;
        else
            rst_shift <= {rst_shift[2:0], 1'b0};
    end

    // ==================== Guitar Amp Core ====================
    guitar_amp_top #(
        .DATA_WIDTH(24),
        .SAMPLE_RATE(48000),
        .SYSTEM_CLK_HZ(100_000_000),
        .OVERSAMPLE_GAIN(4),
        .MAX_DELAY_SEC(2),
        .CAB_IR_LENGTH(512),
        .NUM_CAB_SLOTS(4)
    ) u_guitar_amp (
        .clk(clk_100mhz),
        .rst(rst_sync),
        .i2s_bclk_in(i2s_adc_bclk),
        .i2s_lrclk_in(i2s_adc_lrclk),
        .i2s_sdata_in(i2s_adc_sdata),
        .i2s_mclk_out(i2s_dac_mclk),
        .i2s_bclk_out(i2s_dac_bclk),
        .i2s_lrclk_out(i2s_dac_lrclk),
        .i2s_sdata_out(i2s_dac_sdata),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .uart_rxd(uart_rx),
        .uart_txd(uart_tx),
        .footswitch(btn),
        .led(led)
    );

endmodule
