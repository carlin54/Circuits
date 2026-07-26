# FFT Engine

Pipelined Radix-2 Decimation-in-Time FFT processor and its submodules.

## Architecture

```
Input (real, AXI-Stream)
    |
    v
bit_reversal (reorder to bit-reversed index)
    |
    v
Stage 0: buffer -> twiddle_rom -> butterfly
    |
    v
Stage 1: buffer -> twiddle_rom -> butterfly
    |
    v
  ...  (LOG2_N stages total)
    |
    v
Output (complex, AXI-Stream)
```

## Components

### fft_top.v

Top-level N-point pipelined Radix-2 DIT FFT processor. Accepts real-only input samples, performs bit-reversal reordering followed by log2(N) butterfly stages, and outputs complex frequency-domain results.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | 1024 | FFT size (number of points) |
| `DATA_WIDTH` | 24 | I/O data width |
| `TWIDDLE_WIDTH` | 16 | Twiddle factor coefficient width |
| `TWIDDLE_FRAC_BITS` | 14 | Fractional bits in twiddle factors |
| `PIPELINE` | 1 | Pipeline enable |
| `SCALING_MODE` | `"BLOCK"` | `"BLOCK"` (1/2 per stage), `"NONE"`, or `"DYNAMIC"` |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Input sample (real; imaginary = 0) |
| `s_axis_tvalid` | in | 1 | Input valid |
| `s_axis_tlast` | in | 1 | Last sample in frame |
| `s_axis_tready` | out | 1 | Ready to upstream |
| `m_axis_tdata_re` | out | DATA_WIDTH (signed) | Output frequency bin, real |
| `m_axis_tdata_im` | out | DATA_WIDTH (signed) | Output frequency bin, imaginary |
| `m_axis_tvalid` | out | 1 | Output valid |
| `m_axis_tlast` | out | 1 | Last output bin |
| `m_axis_tready` | in | 1 | Downstream ready |

**Implementation:**
- Input bit-reversal followed by LOG2_N generated butterfly stages in series.
- Each stage buffers N samples, computes butterfly pairs in-place (partner index = `rd_cnt ^ (1 << stage)`).
- Twiddle index = `(rd_cnt % (1 << stage)) * NUM_GROUPS`.
- Block scaling: arithmetic right-shift by 1 per stage (total scale = 1/N).
- Inline complex multiplication (4-multiply with `TWIDDLE_WIDTH-1` right-shift).
- Latency: approximately `2·N·LOG2_N + N` cycles end-to-end.

---

### bit_reversal.v

Reorders input samples from natural order to bit-reversed order for DIT FFT input.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | 1024 | FFT size |
| `DATA_WIDTH` | 24 | Sample width |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `data_re_in` | in | DATA_WIDTH (signed) | Input real |
| `data_im_in` | in | DATA_WIDTH (signed) | Input imaginary |
| `valid_in` | in | 1 | Input valid |
| `last_in` | in | 1 | Last sample in frame |
| `ready_out` | in | 1 | Downstream ready |
| `ready_in` | out | 1 | Backpressure to upstream |
| `data_re_out` | out | DATA_WIDTH (signed) | Output real (bit-reversed) |
| `data_im_out` | out | DATA_WIDTH (signed) | Output imaginary (bit-reversed) |
| `valid_out` | out | 1 | Output valid |
| `last_out` | out | 1 | Last output sample |

**Implementation:** Two-state FSM: WRITE (accept N samples into register arrays) then READ (emit in bit-reversed address order). A combinational `bit_reverse` function reverses the address bits. Supports backpressure during READ via `ready_out`.

---

### butterfly.v

Radix-2 butterfly computation unit: A' = A + W·B, B' = A − W·B.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | I/O data width |
| `TWIDDLE_WIDTH` | 16 | Twiddle factor width |
| `MULT_METHOD` | `"3MULT"` | `"3MULT"` (Gauss, saves 1 multiplier) or `"4MULT"` (standard) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `ar_in` | in | DATA_WIDTH (signed) | A real |
| `ai_in` | in | DATA_WIDTH (signed) | A imaginary |
| `br_in` | in | DATA_WIDTH (signed) | B real |
| `bi_in` | in | DATA_WIDTH (signed) | B imaginary |
| `wr` | in | TWIDDLE_WIDTH (signed) | Twiddle real (cosine) |
| `wi` | in | TWIDDLE_WIDTH (signed) | Twiddle imaginary (−sine) |
| `valid_in` | in | 1 | Input valid |
| `ar_out` | out | DATA_WIDTH (signed) | A' real |
| `ai_out` | out | DATA_WIDTH (signed) | A' imaginary |
| `br_out` | out | DATA_WIDTH (signed) | B' real |
| `bi_out` | out | DATA_WIDTH (signed) | B' imaginary |
| `valid_out` | out | 1 | Output valid |

**Implementation:** 2-stage pipeline (latency = 2 clocks). Stage 1: complex multiplication W·B. Stage 2: add/subtract with aligned A. Twiddle factors in Q1.(TWIDDLE_WIDTH-1) format. Products right-shifted by `TWIDDLE_WIDTH-1`. The 3MULT (Gauss) method: k1 = wr·(br+bi), k2 = bi·(wr+wi), k3 = br·(wi−wr); real = k1−k2, imag = k1+k3.

---

### twiddle_rom.v

Twiddle factor coefficient ROM with quarter-wave sine symmetry exploitation for 4× memory reduction.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | 1024 | FFT size |
| `STAGE` | 0 | FFT stage index |
| `TWIDDLE_WIDTH` | 16 | Output coefficient width |
| `SYMMETRY` | `"QUARTER"` | `"QUARTER"` (N/4 entries), `"HALF"`, or `"FULL"` |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `index` | in | $clog2(N) | Twiddle index k |
| `tw_real` | out | TWIDDLE_WIDTH (signed) | cos(2πk/N) |
| `tw_imag` | out | TWIDDLE_WIDTH (signed) | −sin(2πk/N) |

**Implementation:** Quarter-wave mode stores only N/4 sine values. Upper 2 bits of phase address select quadrant; lower bits index into the quarter table. Odd quadrants mirror the address. Sign is applied based on quadrant. Cosine derived via +1 quadrant offset. Registered output (1-cycle read latency). Fixed-point Q1.(TWIDDLE_WIDTH-1) representing [-1, 1). NUM_TWIDDLES = N >> (STAGE + 1).
