# Interfaces

Communication peripherals for audio I/O and host control.

## Components

### i2s_receiver.v

Deserializes I2S audio data from an external ADC. Synchronizes signals from the audio clock domain into the system clock domain and outputs samples via AXI-Stream.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio sample bit width |
| `NUM_CHANNELS` | 2 | Number of audio channels |
| `BIT_ORDER` | `"MSB_FIRST"` | Bit serialization order |
| `JUSTIFICATION` | `"I2S"` | Format: `"I2S"`, `"LEFT"`, or `"RIGHT"` |
| `FIFO_DEPTH` | 4 | Internal FIFO depth |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst` | in | 1 | Synchronous reset |
| `bclk` | in | 1 | I2S bit clock (audio domain) |
| `lrclk` | in | 1 | I2S left/right clock (word select) |
| `sdata` | in | 1 | I2S serial data |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Audio sample output |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Last beat of stereo pair (right channel) |
| `m_axis_channel` | out | 1 | Channel: 0=left, 1=right |
| `m_axis_tready` | in | 1 | Downstream ready |

**Implementation:** 3-stage synchronizers for all I2S signals (bclk, lrclk, sdata) for CDC. Rising edge detection on bclk for data capture. I2S format skips 1 BCLK after LRCLK transition; LEFT skips 0; RIGHT skips (32 − DATA_WIDTH) bits. Supports MSB-first and LSB-first shift-in. `m_axis_tlast` marks end of right channel (complete stereo frame).

---

### i2s_transmitter.v

Serializes audio data and drives an I2S DAC. Generates MCLK, BCLK, and LRCLK from the system clock.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio sample bit width |
| `NUM_CHANNELS` | 2 | Number of channels |
| `BIT_ORDER` | `"MSB_FIRST"` | Serialization order |
| `JUSTIFICATION` | `"I2S"` | Format: `"I2S"` or `"LEFT"` |
| `MCLK_DIVIDE` | 8 | System clock → BCLK divider |
| `LRCLK_DIVIDE` | 64 | BCLK → LRCLK divider |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Audio sample input |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | End of frame |
| `s_axis_tready` | out | 1 | Can accept data |
| `mclk` | out | 1 | Master clock to DAC |
| `bclk` | out | 1 | Bit clock |
| `lrclk` | out | 1 | Left/right clock |
| `sdata` | out | 1 | Serial data |

**Implementation:** Clock generation via divider counters. MCLK = sys_clk / (MCLK_DIVIDE/2). BCLK derived with half-period counter. LRCLK toggles every LRCLK_HALF BCLK cycles. Double-buffer scheme: left and right samples buffered independently for AXI-Stream decoupling from serialization timing. Data shifted out on BCLK rising edges. I2S inserts 1 skip bit after LRCLK transition.

---

### spi_slave.v

SPI slave providing register read/write for parameter control. Supports all four CPOL/CPHA modes and multi-byte auto-incrementing transactions.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Register data width |
| `ADDR_WIDTH` | 8 | Register address width |
| `CPOL` | 0 | Clock polarity |
| `CPHA` | 0 | Clock phase |
| `NUM_REGS` | 64 | Register count |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst` | in | 1 | Synchronous reset |
| `spi_clk` | in | 1 | SPI clock from master |
| `spi_mosi` | in | 1 | Master out slave in |
| `spi_cs_n` | in | 1 | Chip select (active low) |
| `spi_miso` | out | 1 | Master in slave out |
| `reg_rdata` | in | DATA_WIDTH | Register read data |
| `reg_addr` | out | ADDR_WIDTH | Register address |
| `reg_wdata` | out | DATA_WIDTH | Register write data |
| `reg_we` | out | 1 | Register write enable |

**Implementation:** 3-stage synchronizers for SPI clock, MOSI, and CS_n. Capture/launch edge selected by `CPOL ^ CPHA`. Protocol: first byte = address (MSB = R/W), subsequent bytes = data. Three states: ST_ADDR → ST_DATA → ST_MULTI (auto-increment). For reads, TX shift register preloaded with `reg_rdata` after address byte. Write enable pulses for one clock per received data byte. CS deassertion resets state.

---

### uart_interface.v

Full-duplex UART with configurable baud rate, data bits, stop bits, and parity. AXI-Stream interfaces for TX and RX.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CLK_FREQ` | 100_000_000 | System clock (Hz) |
| `BAUD_RATE` | 115200 | Baud rate |
| `DATA_BITS` | 8 | Data bits per frame |
| `STOP_BITS` | 1 | Stop bits |
| `PARITY` | `"NONE"` | `"NONE"`, `"EVEN"`, or `"ODD"` |
| `FIFO_DEPTH` | 16 | FIFO depth |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_BITS | TX data |
| `s_axis_tvalid` | in | 1 | TX valid |
| `s_axis_tready` | out | 1 | TX ready (idle) |
| `m_axis_tdata` | out | DATA_BITS | RX data |
| `m_axis_tvalid` | out | 1 | RX valid |
| `m_axis_tready` | in | 1 | RX downstream ready |
| `uart_rxd` | in | 1 | UART receive pin |
| `uart_txd` | out | 1 | UART transmit pin |
| `tx_busy` | out | 1 | TX active |
| `rx_frame_error` | out | 1 | Stop bit not detected |
| `rx_parity_error` | out | 1 | Parity check failed |

**Implementation:** Derived constants: CLKS_PER_BIT = CLK_FREQ / BAUD_RATE. TX: IDLE → START → DATA → (PAR) → STOP, shifts LSB-first. RX: samples at mid-bit (HALF_BIT from start-bit edge, then full-bit periods). 3-stage synchronizer on uart_rxd. Parity computed via XOR accumulator. Frame error flagged if stop bit is not high. Configurable stop bit count.
