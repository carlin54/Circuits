# System Top

FPGA top-level targeting a Lattice ECP5 board (ULX3S or similar).

## Components

### system_top.v

Top-level module. Generates 100 MHz system clock from 25 MHz crystal via PLL, implements synchronous reset, and instantiates the guitar amp core.

**Parameters:** None (top-level, no parameterization).

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk_25mhz` | in | 1 | 25 MHz crystal oscillator |
| `rst_n` | in | 1 | Active-low external reset |
| `i2s_adc_bclk` | in | 1 | I2S ADC bit clock |
| `i2s_adc_lrclk` | in | 1 | I2S ADC left/right clock |
| `i2s_adc_sdata` | in | 1 | I2S ADC serial data |
| `i2s_dac_mclk` | out | 1 | I2S DAC master clock |
| `i2s_dac_bclk` | out | 1 | I2S DAC bit clock |
| `i2s_dac_lrclk` | out | 1 | I2S DAC left/right clock |
| `i2s_dac_sdata` | out | 1 | I2S DAC serial data |
| `spi_clk` | in | 1 | SPI clock |
| `spi_mosi` | in | 1 | SPI MOSI |
| `spi_cs_n` | in | 1 | SPI chip select (active low) |
| `spi_miso` | out | 1 | SPI MISO |
| `uart_rx` | in | 1 | UART receive |
| `uart_tx` | out | 1 | UART transmit |
| `btn` | in | 4 | Footswitches / buttons |
| `led` | out | 4 | Status LEDs |

**Implementation:**

- **PLL:** Lattice ECP5 `EHXPLLL` primitive (synthesis only, bypassed in simulation). CLKI_DIV=1, CLKFB_DIV=4, CLKOP_DIV=6 → 25 MHz × 4 / 1 = 100 MHz output.
- **Reset Synchronizer:** Combines `!rst_n` and `!pll_locked` into raw reset. 4-bit shift register (async assert, sync deassert) produces glitch-free `rst_sync`. Reset held for 4 system clocks after raw reset deasserts.
- **Core:** Instantiates `guitar_amp_top` with DATA_WIDTH=24, SAMPLE_RATE=48000, SYSTEM_CLK_HZ=100MHz, OVERSAMPLE_GAIN=4, MAX_DELAY_SEC=2, CAB_IR_LENGTH=512, NUM_CAB_SLOTS=4.
- All external pins routed directly to the guitar amp core.

## Block Diagram

```
             +------------------+
clk_25mhz-->|  PLL (EHXPLLL)   |---> sys_clk (100 MHz)
             +------------------+
                     |
rst_n -----> [Reset Synchronizer] ---> rst_sync
                     |
                     v
         +------------------------+
         |    guitar_amp_top      |
         |                        |
I2S ADC->|  i2s_receiver          |
         |  amp_channel (effects) |
         |  i2s_transmitter       |->I2S DAC
         |  spi_slave             |<->SPI
         |  uart_interface        |<->UART
btn[3:0]->|  footswitch logic     |
         |  LED driver            |->led[3:0]
         +------------------------+
```
