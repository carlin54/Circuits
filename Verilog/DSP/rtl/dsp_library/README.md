# DSP Library

Digital signal processing modules: filters, sample rate converters, oscillators, CORDIC, and spectral analysis utilities.

## Components

### cordic.v

CORDIC (COordinate Rotation DIgital Computer) processor using the iterative shift-and-add algorithm. Multiplier-free. Supports rotation mode (rotate a vector by an angle) and vectoring mode (compute magnitude and angle of a vector).

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 16 | I/O data width |
| `NUM_ITERATIONS` | 16 | Number of CORDIC iterations (precision) |
| `MODE` | `"ROTATION"` | `"ROTATION"` or `"VECTORING"` |
| `PIPELINE` | 1 | 1 = fully pipelined, 0 = iterative (shared logic) |
| `COMPENSATION` | 1 | 1 = compensate for CORDIC gain (~1.6468) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `x_in` | in | DATA_WIDTH (signed) | X input coordinate |
| `y_in` | in | DATA_WIDTH (signed) | Y input coordinate |
| `z_in` | in | DATA_WIDTH (signed) | Angle input |
| `valid_in` | in | 1 | Input valid |
| `ready_in` | out | 1 | Backpressure (always 1 if pipelined) |
| `x_out` | out | DATA_WIDTH (signed) | X output (or magnitude in vectoring) |
| `y_out` | out | DATA_WIDTH (signed) | Y output (or ~0 in vectoring) |
| `z_out` | out | DATA_WIDTH (signed) | Residual angle |
| `valid_out` | out | 1 | Output valid |

**Implementation:** Pipelined mode: `NUM_ITERATIONS+1` pipeline stages, 1 sample/clock throughput. Iterative mode: single register set reused across iterations, 1 sample per `NUM_ITERATIONS` clocks. Rotation mode drives Z toward 0; vectoring mode drives Y toward 0. Arctangent LUT generated in an initial block.

---

### correlator.v

Cross-correlator computing R_xy[lag] = Σ x[n] · y[n-lag]. Supports streaming, matched filter, and block modes.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Input sample width |
| `OUTPUT_WIDTH` | 48 | Correlation output width |
| `MAX_LAG` | 256 | Maximum lag / pattern length / block size |
| `MODE` | `"STREAMING"` | `"STREAMING"`, `"BLOCK"`, or `"MATCHED_FILTER"` |
| `NORMALIZE` | 0 | Normalization enable (placeholder) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `a_data` | in | DATA_WIDTH (signed) | Signal A input |
| `a_valid` | in | 1 | Signal A valid |
| `b_data` | in | DATA_WIDTH (signed) | Signal B input |
| `b_valid` | in | 1 | Signal B valid |
| `ref_we` | in | 1 | Reference pattern write enable |
| `ref_addr` | in | $clog2(MAX_LAG) | Reference pattern address |
| `ref_data` | in | DATA_WIDTH (signed) | Reference pattern data |
| `lag_select` | in | $clog2(MAX_LAG) | Selected lag (STREAMING) |
| `frame_start` | in | 1 | Start frame capture (BLOCK) |
| `corr_out` | out | OUTPUT_WIDTH (signed) | Correlation result |
| `corr_valid` | out | 1 | Output valid |
| `frame_done` | out | 1 | Frame complete (BLOCK) |

**Implementation:**
- **STREAMING:** Maintains delay lines, accumulates product of a_data with b_delay[lag_select] over MAX_LAG samples.
- **MATCHED_FILTER:** Programmable reference pattern; full MAC across all taps per input sample.
- **BLOCK:** Buffers MAX_LAG samples of both signals, then computes R[lag] for each lag sequentially.

---

### decimator.v

Sample rate decimator (input_rate / FACTOR). Supports CIC (multiplier-free) and FIR (anti-alias filtered) architectures.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | I/O data width |
| `FACTOR` | 4 | Decimation factor |
| `FILTER_TYPE` | `"CIC"` | `"CIC"` or `"FIR"` |
| `CIC_ORDER` | 4 | Number of CIC stages |
| `CIC_DIFF_DELAY` | 1 | Comb differential delay |
| `FIR_TAPS` | 31 | Number of FIR taps |
| `FIR_COEFF_FILE` | `""` | Hex file for FIR coefficients |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input data (high rate) |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | End of frame |
| `s_axis_tready` | out | 1 | Input ready |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output data (low rate) |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Output end of frame |
| `m_axis_tready` | in | 1 | Downstream ready |

**Implementation:** CIC mode computes bit growth as `CIC_ORDER * clog2(FACTOR * CIC_DIFF_DELAY)`. Integrators run at full rate, combs at decimated rate. FIR mode uses sequential MAC (one tap per clock) with Q15 coefficients.

---

### fir_filter.v

Parameterized FIR filter with three structural forms, runtime coefficient reload, and configurable multiply style.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Input sample width |
| `COEFF_WIDTH` | 16 | Coefficient bit width |
| `OUTPUT_WIDTH` | 24 | Output width |
| `NUM_TAPS` | 63 | Number of filter taps |
| `FRAC_BITS` | 15 | Fractional bits in coefficients |
| `STRUCTURE` | `"TRANSPOSED"` | `"DIRECT"`, `"TRANSPOSED"`, or `"SYMMETRIC"` |
| `COEFF_RELOAD` | 1 | Enable runtime coefficient write |
| `COEFF_FILE` | `""` | Hex file for static coefficients |
| `MULT_STYLE` | `"DSP"` | Synthesis hint: `"DSP"`, `"FABRIC"`, or `"AUTO"` |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input sample |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | End of frame |
| `s_axis_tready` | out | 1 | Input ready |
| `coeff_we` | in | 1 | Coefficient write enable |
| `coeff_addr` | in | $clog2(NUM_TAPS) | Coefficient address |
| `coeff_data` | in | COEFF_WIDTH (signed) | Coefficient data |
| `m_axis_tdata` | out | OUTPUT_WIDTH (signed) | Filtered output |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tready` | in | 1 | Downstream ready |
| `m_axis_tlast` | out | 1 | End of frame |

**Implementation:**
- **TRANSPOSED:** Fully pipelined, 1 sample/clock, uses NUM_TAPS multipliers. 2-clock latency.
- **DIRECT:** Sequential MAC, one multiplier, NUM_TAPS clocks per sample.
- **SYMMETRIC:** Pre-add of symmetric tap pairs, halving multipliers to (NUM_TAPS+1)/2. Fully pipelined.

All forms implement round-half-up and signed saturation on output. ACC_WIDTH = DATA_WIDTH + COEFF_WIDTH + clog2(NUM_TAPS).

---

### iir_biquad.v

IIR biquad filter — Direct Form II Transposed. Supports cascading multiple second-order sections with runtime coefficient reload.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | I/O data width |
| `COEFF_WIDTH` | 18 | Coefficient bit width |
| `INTERNAL_WIDTH` | 40 | Internal accumulator width |
| `FRAC_BITS` | 16 | Fractional bits |
| `NUM_SECTIONS` | 1 | Number of cascaded biquad sections |
| `COEFF_RELOAD` | 1 | Enable runtime coefficient reload |
| `FORM` | `"DF2T"` | Filter form (only DF2T implemented) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input sample |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | End of frame |
| `s_axis_tready` | out | 1 | Input ready |
| `coeff_we` | in | 1 | Coefficient write enable |
| `coeff_addr` | in | 3 | Coefficient index (0=b0..4=a2) |
| `coeff_data` | in | COEFF_WIDTH (signed) | Coefficient value |
| `coeff_section` | in | $clog2(NUM_SECTIONS) | Target section |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Filtered output |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tready` | in | 1 | Downstream ready |
| `m_axis_tlast` | out | 1 | End of frame |

**Implementation:** Processes one section per clock cycle (latency = NUM_SECTIONS clocks/sample). DF2T equations: y[n] = b0·x[n] + w1; w1 = b1·x[n] − a1·y[n] + w2; w2 = b2·x[n] − a2·y[n]. Coefficients initialized to unity passthrough. Output saturated between sections. 40-bit internal state for precision.

---

### interpolator.v

Sample rate interpolator (input_rate × FACTOR). Supports CIC and FIR (polyphase) architectures.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | I/O data width |
| `FACTOR` | 4 | Interpolation factor |
| `FILTER_TYPE` | `"CIC"` | `"CIC"` or `"FIR"` |
| `CIC_ORDER` | 4 | Number of CIC stages |
| `FIR_TAPS` | 31 | Number of FIR taps |
| `FIR_COEFF_FILE` | `""` | Hex file for FIR coefficients |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input (low rate) |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | End of frame |
| `s_axis_tready` | out | 1 | Input ready |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Output (high rate) |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tready` | in | 1 | Downstream ready |
| `m_axis_tlast` | out | 1 | End of frame |

**Implementation:** CIC mode runs combs at input rate and integrators at output rate. Produces FACTOR output samples per input. FIR mode uses polyphase decomposition with 16-bit coefficients. Both modes block input until all interpolated outputs are emitted.

---

### magnitude.v

Complex magnitude calculator: |I + jQ| = √(I² + Q²). Three selectable methods.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Input I/Q width |
| `OUTPUT_WIDTH` | 24 | Output width |
| `METHOD` | `"CORDIC"` | `"CORDIC"`, `"ALPHA_BETA"`, or `"SQUARED"` |
| `CORDIC_ITERS` | 16 | CORDIC iterations |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `i_in` | in | DATA_WIDTH (signed) | In-phase (real) |
| `q_in` | in | DATA_WIDTH (signed) | Quadrature (imaginary) |
| `valid_in` | in | 1 | Input valid |
| `mag_out` | out | OUTPUT_WIDTH (signed) | Magnitude result |
| `valid_out` | out | 1 | Output valid |

**Implementation:**
- **CORDIC:** Pre-conditions to first quadrant, uses vectoring mode. Latency = CORDIC_ITERS + pipeline stages.
- **ALPHA_BETA:** max(|I|,|Q|) + 0.4·min(|I|,|Q|). Single-clock, ~3% max error.
- **SQUARED:** I² + Q², no square root. Single-clock. Good for relative power comparisons.

---

### nco.v

Numerically Controlled Oscillator — phase accumulator with sine/cosine generation via quarter-wave LUT or CORDIC.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PHASE_WIDTH` | 32 | Phase accumulator width |
| `OUTPUT_WIDTH` | 16 | Sine/cosine output width |
| `LUT_DEPTH` | 10 | Quarter-wave LUT address bits (1024 entries) |
| `METHOD` | `"LUT"` | `"LUT"` or `"CORDIC"` |
| `DITHER` | 0 | Phase dither for spur reduction |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `freq_word` | in | PHASE_WIDTH | Phase increment (tuning word) |
| `phase_offset` | in | PHASE_WIDTH | Static phase offset |
| `sin_out` | out | OUTPUT_WIDTH (signed) | Sine output |
| `cos_out` | out | OUTPUT_WIDTH (signed) | Cosine output |
| `valid` | out | 1 | Output valid |

**Implementation:** Output frequency = freq_word × f_clk / 2^PHASE_WIDTH. LUT method stores a quarter-wave (exploits symmetry for 4× storage reduction). Quadrant bits select sign/address mirroring. 2-clock pipeline. CORDIC method rotates a pre-scaled unit vector by the accumulated phase.

---

### peak_detector.v

Streaming peak detector — finds the maximum value and its index within a frame. Used for FFT peak bin identification.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Input magnitude width |
| `NUM_BINS` | 512 | Number of bins per frame |
| `INDEX_WIDTH` | 9 | Bin index output width |
| `STREAMING` | 1 | 1 = process one bin per clock |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `data_in` | in | DATA_WIDTH (unsigned) | Input magnitude |
| `valid_in` | in | 1 | Input valid |
| `last_in` | in | 1 | End of frame |
| `peak_mag` | out | DATA_WIDTH | Peak magnitude |
| `peak_index` | out | INDEX_WIDTH | Peak bin index |
| `done` | out | 1 | Frame processing complete |

**Implementation:** Compare-and-track design. Maintains running maximum and its index. Frame boundary detected by `last_in` or counter reaching NUM_BINS-1. Output registered and held for one clock after frame completion.

---

### windowing.v

Window function applicator — point-by-point multiplication with stored coefficients for spectral leakage reduction before FFT.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | 1024 | Window length |
| `DATA_WIDTH` | 24 | Input/output data width |
| `COEFF_WIDTH` | 16 | Window coefficient width |
| `WINDOW_TYPE` | `"HANN"` | `"HANN"`, `"HAMMING"`, `"BLACKMAN"`, `"KAISER"`, `"CUSTOM"` |
| `COEFF_FILE` | `""` | Hex file for custom coefficients |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input sample |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | End of frame |
| `s_axis_tready` | out | 1 | Input ready |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Windowed output |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tready` | in | 1 | Downstream ready |
| `m_axis_tlast` | out | 1 | End of frame |

**Implementation:** Coefficients stored in ROM (N entries, Q1.(COEFF_WIDTH-1) format representing [0, 1]). 2-stage pipeline: multiply with round-half-up, then register output. Counter auto-resets on `tlast` or at N-1. Actual window values expected from `gen_window.py`.

---

## Subdirectory

- [`fft/`](fft/) — N-point pipelined FFT processor and its submodules
