# Guitar Amp

Digital guitar amplifier processing core. Mono signal path at 48 kHz / 24-bit with SPI parameter control and I2S audio I/O.

## Signal Flow

```
I2S ADC -> noise_gate -> wah -> compressor -> gain_stage -> tone_stack -> eq_parametric
  -> [chorus/flanger/pitch_shift] -> tremolo -> delay_line -> reverb -> cab_sim -> limiter -> master_volume -> I2S DAC
```

Each effect can be individually bypassed via the 16-bit `fx_bypass` register. A chromatic tuner is tapped from the input and runs in parallel without affecting the signal path.

## Components

### guitar_amp_top.v

Top-level system integration. Connects I2S receiver to the effects chain to I2S transmitter. Includes SPI slave for parameter control, UART for host communication, footswitch GPIO, and LED status.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `SAMPLE_RATE` | 48000 | Audio sample rate (Hz) |
| `SYSTEM_CLK_HZ` | 100_000_000 | System clock frequency |
| `NUM_CHANNELS` | 1 | Number of audio channels |
| `OVERSAMPLE_GAIN` | 4 | Gain stage oversampling factor |
| `MAX_DELAY_SEC` | 2 | Maximum delay time (seconds) |
| `MAX_COMB_DELAY` | 2048 | Reverb comb filter max delay |
| `NUM_COMBS` | 4 | Number of reverb comb filters |
| `NUM_ALLPASS` | 2 | Number of reverb allpass filters |
| `CAB_IR_LENGTH` | 512 | Cabinet IR length (taps) |
| `NUM_CAB_SLOTS` | 4 | Cabinet IR preset slots |
| `NUM_PRESETS` | 8 | Total preset count |
| `BAUD_RATE` | 115200 | UART baud rate |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | System clock (100 MHz) |
| `rst` | in | 1 | Reset |
| `i2s_bclk_in` | in | 1 | I2S ADC bit clock |
| `i2s_lrclk_in` | in | 1 | I2S ADC L/R clock |
| `i2s_sdata_in` | in | 1 | I2S ADC serial data |
| `i2s_mclk_out` | out | 1 | I2S DAC master clock |
| `i2s_bclk_out` | out | 1 | I2S DAC bit clock |
| `i2s_lrclk_out` | out | 1 | I2S DAC L/R clock |
| `i2s_sdata_out` | out | 1 | I2S DAC serial data |
| `spi_clk` | in | 1 | SPI clock |
| `spi_mosi` | in | 1 | SPI MOSI |
| `spi_cs_n` | in | 1 | SPI chip select (active low) |
| `spi_miso` | out | 1 | SPI MISO |
| `uart_rxd` | in | 1 | UART receive |
| `uart_txd` | out | 1 | UART transmit |
| `footswitch` | in | 4 | Footswitch inputs |
| `led` | out | 4 | Status LEDs |

**Implementation:** 64 × 8-bit register file addressed via SPI. Register map covers all effect parameters (gate, compressor, gain, tone, modulation, delay, reverb, cabinet, master volume, bypass). Processes left (mono) channel only from I2S. Footswitches have 3-stage synchronizer with edge detection. LEDs indicate: signal present, gate bypass, drive active, footswitch state.

**Register Map (128 × 8-bit registers):**

| Address | Parameter |
|---------|-----------|
| 0x01 | Gate open threshold |
| 0x02 | Gate hold time |
| 0x03–0x06 | Wah (pedal position, resonance, range_lo, range_hi) |
| 0x08–0x0C | Compressor (threshold, ratio, attack, release, makeup) |
| 0x10–0x12 | Gain (drive, level, clip type) |
| 0x14–0x18 | Tone stack (bass, mid, treble, presence, resonance) |
| 0x19–0x24 | Parametric EQ (4 bands × freq/gain/Q) |
| 0x25–0x27 | Chorus (rate, depth, mix) |
| 0x28–0x29 | Delay time (high byte, low byte) |
| 0x2A–0x2D | Flanger (rate, depth, feedback, mix) |
| 0x2E–0x2F | Pitch shift (amount, mix) |
| 0x30–0x32 | Tremolo (rate, depth, shape) |
| 0x34–0x35 | Delay (feedback, mix) |
| 0x38–0x3A | Reverb (decay, damping, mix) |
| 0x3C–0x3D | Cabinet (select, bypass) |
| 0x40 | Master volume |
| 0x42–0x43 | Limiter (threshold, release) |
| 0x44–0x45 | FX bypass bitmask (16-bit, low/high) |
| 0x46 | Modulation mode select (0=chorus, 1=flanger, 2=pitch) |
| 0x48–0x49 | Tuner (enable, noise floor) |

---

### amp_channel.v

Configurable effects chain. Instantiates all effect modules and wires them in series with per-effect bypass muxes.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `COEFF_WIDTH` | 18 | IIR coefficient width |
| `INTERNAL_WIDTH` | 40 | IIR internal precision |
| `OVERSAMPLE` | 4 | Gain stage oversampling |
| `MAX_DELAY` | 96000 | Max delay samples (2s @ 48kHz) |
| `MAX_COMB_DELAY` | 2048 | Reverb comb max delay |
| `NUM_COMBS` | 4 | Reverb comb filter count |
| `NUM_ALLPASS` | 2 | Reverb allpass count |
| `CAB_IR_LENGTH` | 512 | Cabinet IR taps |
| `NUM_CAB_SLOTS` | 4 | Cabinet IR slots |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |
| `fx_bypass` | in | 8 | Per-effect bypass bits |
| (control ports) | in | various | Effect parameters (gate, comp, gain, tone, chorus, flanger, delay, reverb, cab) |

**Implementation:** Each effect stage has a bypass bit in `fx_bypass[7:0]`: bit 0=gate, 1=compressor, 2=gain, 3=tone, 4=modulation, 5=delay, 6=reverb, 7=cab. Master volume applied as final step: `output = data × master_vol >>> 8`.

---

## Subdirectories

- [`effects/`](effects/) — Individual audio effect modules
- [`interfaces/`](interfaces/) — I2S, SPI, and UART communication modules
