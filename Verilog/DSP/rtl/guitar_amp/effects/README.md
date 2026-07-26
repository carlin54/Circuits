# Guitar Amp Effects

Individual audio effect modules. All share a common interface pattern:
- AXI-Stream input/output (tdata/tvalid/tready/tlast)
- 24-bit signed audio data
- 8-bit control parameters (0–255 range)
- Designed for 48 kHz sample rate at 100 MHz system clock

## Signal Chain Order

```
noise_gate -> wah -> compressor -> gain_stage -> tone_stack -> eq_parametric
  -> [chorus/flanger/pitch_shift] -> tremolo -> delay_line -> reverb -> cab_sim -> limiter
```

## Components

### noise_gate.v

Silences the signal when it falls below a threshold. 5-state FSM: CLOSED → ATTACK → OPEN → HOLD → RELEASE → CLOSED.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `ENV_WIDTH` | 32 | Envelope detector width |
| `HYSTERESIS_DB` | 6 | Built-in hysteresis |
| `HOLD_SAMPLES` | 2400 | Default hold time (50ms @ 48kHz) |
| `ATTACK_COEFF` | 16 | Attack speed |
| `RELEASE_COEFF` | 16 | Release speed |
| `RANGE_DB` | 80 | Gate attenuation range |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `open_threshold` | in | 8 | Level to open gate |
| `close_threshold` | in | 8 | Level to close gate |
| `hold_time` | in | 16 | Hold time in samples |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Peak envelope follower with fast attack (>>2) and slow release (>>6). Gate gain ramps: attack ramps up by 16/sample (~16 samples to open), release ramps down by 4/sample (~64 samples to close). Separate open/close thresholds provide hysteresis to prevent chatter. Hold state keeps gate open for configurable time after signal drops.

---

### compressor.v

Dynamic range compressor with peak envelope detection, gain computation, smoothing, and makeup gain.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `ENV_WIDTH` | 32 | Envelope width |
| `ATTACK_WIDTH` | 16 | Attack coefficient width |
| `RELEASE_WIDTH` | 16 | Release coefficient width |
| `DETECTION` | `"PEAK"` | Detection mode |
| `KNEE` | `"HARD"` | Knee type |
| `KNEE_WIDTH` | 6 | Soft knee width (placeholder) |
| `LOOKAHEAD` | 0 | Lookahead enable (placeholder) |
| `SIDECHAIN_EXT` | 0 | External sidechain (placeholder) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `threshold` | in | 8 | Compression threshold |
| `ratio` | in | 8 | Compression ratio |
| `attack` | in | 16 | Attack coefficient |
| `release_coeff` | in | 16 | Release coefficient |
| `makeup` | in | 8 | Makeup gain (128 = unity) |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Asymmetric attack/release envelope follower. Gain reduction computed in linear domain: when envelope exceeds threshold, reduction ∝ overshoot/ratio. Unity gain_reduction = 255. Application: `compressed = input × gain_reduction >>> 8`, then `output = compressed × makeup >>> 7`.

---

### gain_stage.v

Overdrive/distortion via waveshaping LUT. Signal flow: input → 4× upsample → pre-gain → LUT waveshape → post-gain → 4× downsample. Oversampling prevents aliasing from generated harmonics.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `TABLE_ADDR_WIDTH` | 10 | LUT address bits (1024 entries) |
| `TABLE_WIDTH` | 16 | LUT data width |
| `NUM_CURVES` | 5 | Number of waveshape curves |
| `OVERSAMPLE` | 4 | Oversampling factor |
| `PRE_GAIN_WIDTH` | 16 | Pre-gain multiplier width |
| `INTERP` | 1 | Linear interpolation enable |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `drive` | in | 16 | Pre-gain (drive amount) |
| `level` | in | 16 | Output level |
| `curve_sel` | in | 3 | Waveshape curve selector |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** 4-state FSM: IDLE → UPSAMPLE → PROCESS → DOWNSAMPLE. Upsampling via linear interpolation across 4 phases. 5 selectable curves in a single LUT (5 × 1024 entries). LUT addressed by saturated/gained sample MSBs. Downsampling by averaging 4 oversampled outputs. LUT data from `gen_waveshape_lut.py`.

---

### tone_stack.v

3-band EQ (bass, mid, treble) plus presence and resonance. Implemented as cascaded IIR biquad sections.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `COEFF_WIDTH` | 18 | Biquad coefficient width |
| `INTERNAL_WIDTH` | 40 | Internal precision |
| `NUM_BANDS` | 3 | Number of EQ bands |
| `PRESENCE` | 1 | Presence filter enabled |
| `RESONANCE` | 1 | Resonance filter enabled |
| `COEFF_SETS` | 16 | Pre-computed coefficient sets per knob |
| `FRAC_BITS` | 16 | Fractional bits |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `bass` | in | 8 | Bass control |
| `mid` | in | 8 | Mid control |
| `treble` | in | 8 | Treble control |
| `presence` | in | 8 | Presence control |
| `resonance` | in | 8 | Resonance control |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Total 5 cascaded `iir_biquad` sections (3 bands + presence + resonance). Generated via `generate` loop. Each biquad has `COEFF_RELOAD` capability — an external controller writes coefficients based on knob positions (selecting from 16 pre-computed sets per position). Knob inputs are for an external coefficient update controller.

---

### chorus.v

Chorus effect using a modulated delay line mixed with dry signal. Triangle-wave LFO modulates the read pointer of a circular buffer.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `BASE_DELAY` | 1200 | Base delay (~25ms @ 48kHz) |
| `MAX_DEPTH` | 480 | Max modulation depth (±10ms) |
| `LFO_WIDTH` | 32 | LFO phase accumulator width |
| `NUM_VOICES` | 1 | Number of chorus voices |
| `STEREO` | 0 | Stereo output enable |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `rate` | in | 8 | LFO rate |
| `depth` | in | 8 | Modulation depth |
| `mix` | in | 8 | Wet/dry mix (0=dry, 255=wet) |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Buffer size = BASE_DELAY + MAX_DEPTH + 1 = 1681 samples. 32-bit phase accumulator with triangle wave (fold at midpoint). LFO increment = `rate << 8`. Depth clamped to MAX_DEPTH. Circular buffer with explicit wrap check. Mix: `output = (delayed × mix + input × (255 − mix)) >>> 8`.

---

### flanger.v

Flanger effect using a short modulated delay with signed feedback. Creates a sweeping comb-filter sound.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `BASE_DELAY` | 100 | Base delay (~2ms) |
| `MAX_DEPTH` | 200 | Max sweep (~4ms) |
| `LFO_WIDTH` | 32 | LFO phase accumulator width |
| `FEEDBACK_WIDTH` | 16 | Feedback precision |
| `NEGATIVE_FB` | 1 | Allow negative feedback |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `rate` | in | 8 | LFO rate |
| `depth` | in | 8 | Modulation depth |
| `feedback` | in | 8 (signed) | Feedback (signed for negative FB) |
| `mix` | in | 8 | Wet/dry mix |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Buffer size = 301 samples. LFO increment = `rate << 6` (slower than chorus). Signed feedback allows inverting the comb filter peaks/nulls for different tonal character. Feedback: `write = input + (delayed × feedback >>> 7)`. Circular buffer with explicit wrap.

---

### delay_line.v

Digital delay (echo) using a RAM-based circular buffer with feedback and wet/dry mix.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `MAX_DELAY_SAMPLES` | 96000 | Max delay (2 seconds @ 48kHz) |
| `NUM_TAPS` | 1 | Number of delay taps (placeholder) |
| `MODULATION` | 0 | Modulation enable (placeholder) |
| `MOD_DEPTH_BITS` | 8 | Modulation depth bits |
| `INTERPOLATION` | `"LINEAR"` | Interpolation mode (placeholder) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `delay_time` | in | 17 | Delay time in samples |
| `feedback` | in | 8 | Feedback gain (0–255) |
| `mix` | in | 8 | Wet/dry mix |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Circular buffer with pointer subtraction for read address: `rd_ptr = wr_ptr − delay_time`. Feedback with saturation: `write = input + (delayed × feedback >>> 8)`. Mix: `output = (delayed × mix + input × (255 − mix)) >>> 8`. Block RAM inferred for the 96000-sample buffer.

---

### reverb.v

Schroeder reverb: parallel comb filters followed by series allpass filters. Comb filters create density; allpass filters smooth without altering frequency response.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `MAX_COMB_DELAY` | 2048 | Comb filter max delay |
| `MAX_AP_DELAY` | 1024 | Allpass max delay |
| `NUM_COMBS` | 4 | Number of parallel comb filters |
| `NUM_ALLPASS` | 2 | Number of series allpass filters |
| `PREDELAY_MAX` | 4800 | Pre-delay max (placeholder) |
| `DAMPING` | 1 | Damping LP filter enabled |
| `EARLY_REF` | 1 | Early reflections (placeholder) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `decay` | in | 8 | Feedback/decay |
| `damping_ctrl` | in | 8 | LP filter coefficient |
| `mix` | in | 8 | Wet/dry mix |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Comb filter delays are mutually prime (1557, 1617, 1491, 1422 samples) for natural-sounding reverb. Allpass delays: 225, 556. Damping: 1-pole LP in each comb feedback path. Allpass coefficient ≈ 0.3. Comb outputs summed and averaged, then passed through cascaded allpass filters. Wet/dry mix applied at output.

---

### cab_sim.v

Cabinet impulse response (IR) simulation via long FIR convolution. Single resource-shared multiplier, one tap per clock. Supports multiple IR slots with crossfading on IR changes.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `COEFF_WIDTH` | 16 | IR coefficient width |
| `IR_LENGTH` | 512 | IR length (taps) |
| `NUM_IR_SLOTS` | 4 | Number of IR presets |
| `IR_MEM_TYPE` | `"BLOCK_RAM"` | Memory type hint |
| `CROSSFADE` | 1 | Crossfade on IR change |
| `CROSSFADE_LEN` | 64 | Crossfade length (samples) |
| `INTERNAL_WIDTH` | 48 | Internal accumulator width |
| `IR_INIT_FILE` | `""` | Hex file for IR data |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `ir_select` | in | 2 | Active IR slot |
| `bypass` | in | 1 | Bypass processing |
| `ir_we` | in | 1 | IR write enable |
| `ir_slot` | in | 2 | IR write target slot |
| `ir_addr` | in | 9 | IR write address |
| `ir_wdata` | in | 16 (signed) | IR coefficient data |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** 3-state MAC engine: IDLE → RUNNING (512 taps, one multiply-accumulate per clock) → DONE. At 100 MHz / 48 kHz = ~2083 clocks per sample, comfortably processes 512 taps. Circular buffer for recent samples. Crossfade: on IR change, computes both old and new IRs for 64 samples, linearly blending. Output saturated.

---

### wah.v

Wah pedal — sweepable resonant bandpass filter. Controlled by expression pedal position or auto-wah (envelope following). Implemented using a state-variable filter (SVF).

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `COEFF_WIDTH` | 18 | Internal coefficient width |
| `INTERNAL_WIDTH` | 40 | Internal precision |
| `FRAC_BITS` | 16 | Fractional bits |
| `MODE` | `"MANUAL"` | `"MANUAL"` (pedal) or `"AUTO"` (envelope) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `pedal_pos` | in | 8 | Pedal position (0=toe up/low, 255=toe down/high) |
| `resonance` | in | 8 | Q factor (0=mild, 255=sharp peak) |
| `range_lo` | in | 8 | Low frequency bound |
| `range_hi` | in | 8 | High frequency bound |
| `sensitivity` | in | 8 | Auto-wah envelope sensitivity |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** State-variable filter (SVF) providing simultaneous LP, BP, HP. Outputs the bandpass response for the characteristic wah sound. Pedal position linearly interpolates the cutoff frequency between range_lo and range_hi. Auto mode uses a peak envelope follower to sweep frequency based on input dynamics.

---

### tremolo.v

Tremolo — amplitude modulation via LFO with selectable waveform shape.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `LFO_WIDTH` | 32 | LFO phase accumulator width |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `rate` | in | 8 | LFO speed |
| `depth` | in | 8 | Modulation depth (0=none, 255=full) |
| `shape` | in | 2 | 0=sine, 1=triangle, 2=square, 3=sawtooth |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** 32-bit phase accumulator with 4 selectable waveform shapes. Sine uses a quadratic approximation. Gain ranges from `(255-depth)` to `255`, ensuring signal is never fully muted unless depth=255. Output: `input × gain >>> 8`.

---

### eq_parametric.v

Multi-band fully parametric equalizer. Each band has adjustable frequency, gain, and Q. Implemented as cascaded IIR biquad sections with runtime coefficient reload.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `COEFF_WIDTH` | 18 | Coefficient width |
| `INTERNAL_WIDTH` | 40 | Internal precision |
| `FRAC_BITS` | 16 | Fractional bits |
| `NUM_BANDS` | 4 | Number of EQ bands |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `band_freq` | in | 8×NUM_BANDS | Packed frequency per band |
| `band_gain` | in | 8×NUM_BANDS | Packed gain per band (128=unity) |
| `band_q` | in | 8×NUM_BANDS | Packed Q per band |
| `coeff_we` | in | 1 | Coefficient write enable |
| `coeff_band` | in | $clog2(NUM_BANDS) | Target band |
| `coeff_addr` | in | 3 | Coefficient index (b0..a2) |
| `coeff_data` | in | COEFF_WIDTH (signed) | Coefficient value |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** NUM_BANDS cascaded `iir_biquad` instances generated via `generate`. Each band has independent coefficient reload. An external controller computes biquad coefficients from the frequency/gain/Q knob values and writes them via the coefficient interface.

---

### limiter.v

Brickwall output limiter with lookahead. Prevents clipping with very fast attack.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `LOOKAHEAD` | 32 | Lookahead delay in samples |
| `ATTACK_COEFF` | 1 | Attack speed (lower=faster) |
| `RELEASE_COEFF` | 12 | Release speed (higher=slower) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `threshold` | in | 8 | Limiting threshold (255=0dBFS) |
| `release_ctrl` | in | 8 | Release time |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Lookahead delay buffer allows the limiter to see peaks before they arrive at the output. Peak envelope tracker computes gain reduction when envelope exceeds threshold. Gain = threshold/envelope (division approximation). Minimum gain floor at -24dB. Output delayed by LOOKAHEAD samples to align with the computed gain curve.

---

### tuner.v

Chromatic guitar tuner using zero-crossing period measurement. Outputs detected note, octave, and cents deviation.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio input width |
| `SAMPLE_RATE` | 48000 | Sample rate for frequency calculation |
| `COUNTER_WIDTH` | 20 | Period counter width |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `audio_in` | in | DATA_WIDTH (signed) | Audio input (tapped from signal path) |
| `audio_valid` | in | 1 | Audio sample valid |
| `noise_floor` | in | 8 | Minimum detection level |
| `enable` | in | 1 | Tuner enable |
| `note` | out | 4 | Detected note (0=C, 1=C#, ... 11=B) |
| `octave` | out | 3 | Octave number (2–6) |
| `cents` | out | 8 (signed) | Deviation from pitch (-50 to +50) |
| `valid` | out | 1 | Detection stable |
| `in_tune` | out | 1 | Within ±5 cents |

**Implementation:** Zero-crossing detector with hysteresis (only counts crossings above noise floor). Period measured between negative-to-positive crossings. IIR averaging for stability. Octave determined by shifting measured period into reference octave range. Note lookup from period boundaries. Requires multiple stable periods before reporting valid.

---

### pitch_shift.v

Granular time-domain pitch shifter. Uses two overlapping grains with crossfade. Range: -12 to +12 semitones.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Audio data width |
| `GRAIN_SIZE` | 1024 | Grain length (~21ms @ 48kHz) |
| `BUFFER_SIZE` | 4096 | Circular buffer size (power of 2) |
| `CROSSFADE_LEN` | 128 | Crossfade overlap in samples |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input audio |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Input last |
| `s_axis_tready` | out | 1 | Input ready |
| `shift` | in | 8 (signed) | Pitch shift (-128=-12st, 0=unity, +127=+12st) |
| `mix` | in | 8 | Wet/dry mix |
| `grain_size_ctrl` | in | 8 | Grain size adjust |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output audio |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output last |
| `m_axis_tready` | in | 1 | Output ready |

**Implementation:** Two read pointers (grains A and B) advance through a circular buffer at a rate determined by the shift amount. Grains are offset by half a grain period and crossfaded with triangular windows at boundaries to avoid clicks. Read rate = 1.0 + shift/128 (positive = faster = pitch up). Fractional read pointers (16-bit fractional) for smooth rate control.
