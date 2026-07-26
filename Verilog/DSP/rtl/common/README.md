# Common RTL Library

Reusable building blocks for DSP datapaths, memory, FIFOs, and AXI-Stream flow control.

## Components

### axis_interface.v

AXI-Stream pipeline register with optional skid buffer for timing closure.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Data bus width |
| `REGISTER_OUTPUT` | 1 | 1 = insert pipeline register (skid buffer), 0 = passthrough |
| `BACKPRESSURE` | 1 | 1 = support ready-based flow control, 0 = always ready |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `s_axis_tdata` | in | DATA_WIDTH (signed) | Slave data input |
| `s_axis_tvalid` | in | 1 | Slave valid |
| `s_axis_tlast` | in | 1 | Slave frame boundary |
| `s_axis_tready` | out | 1 | Ready to upstream |
| `m_axis_tdata` | out | DATA_WIDTH (signed) | Master data output |
| `m_axis_tvalid` | out | 1 | Master valid |
| `m_axis_tlast` | out | 1 | Master frame boundary |
| `m_axis_tready` | in | 1 | Downstream ready |

**Implementation:** When `REGISTER_OUTPUT=1`, implements a skid buffer design. A main output register feeds downstream; a secondary skid register captures incoming data when the output is stalled. This allows full throughput (no bubble cycles) with registered outputs. When `REGISTER_OUTPUT=0`, purely combinational passthrough.

---

### dual_port_ram.v

True dual-port RAM with synthesis attribute hints for FPGA block/distributed RAM inference.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ADDR_WIDTH` | 10 | Address width (depth = 2^ADDR_WIDTH) |
| `DATA_WIDTH` | 24 | Data bus width |
| `INIT_FILE` | `""` | Hex file for initialization |
| `RAM_STYLE` | `"block"` | Synthesis hint: `"block"` or `"distributed"` |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Single clock (shared by both ports) |
| `we_a` | in | 1 | Port A write enable |
| `addr_a` | in | ADDR_WIDTH | Port A address |
| `din_a` | in | DATA_WIDTH | Port A write data |
| `dout_a` | out | DATA_WIDTH | Port A read data |
| `we_b` | in | 1 | Port B write enable |
| `addr_b` | in | ADDR_WIDTH | Port B address |
| `din_b` | in | DATA_WIDTH | Port B write data |
| `dout_b` | out | DATA_WIDTH | Port B read data |

**Implementation:** Single-clock design with write-first semantics. Both ports share the same clock. Uses `(* ram_style *)` synthesis attribute. Optional `$readmemh` initialization from `INIT_FILE`.

---

### fifo_async.v

Asynchronous FIFO for clock domain crossing using Gray-code pointers and multi-stage synchronizers.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Data bus width |
| `DEPTH` | 16 | FIFO depth (must be power of 2) |
| `SYNC_STAGES` | 2 | Number of synchronizer flip-flop stages |

**Ports:**

| Port | Direction | Width | Clock Domain | Description |
|------|-----------|-------|--------------|-------------|
| `wr_clk` | in | 1 | Write | Write clock |
| `wr_rst` | in | 1 | Write | Write domain reset |
| `wr_data` | in | DATA_WIDTH | Write | Write data |
| `wr_en` | in | 1 | Write | Write enable |
| `wr_full` | out | 1 | Write | FIFO full flag |
| `rd_clk` | in | 1 | Read | Read clock |
| `rd_rst` | in | 1 | Read | Read domain reset |
| `rd_en` | in | 1 | Read | Read enable |
| `rd_data` | out | DATA_WIDTH | Read | Read data |
| `rd_empty` | out | 1 | Read | FIFO empty flag |

**Implementation:** Pointer width is `$clog2(DEPTH) + 1` for full/empty disambiguation. Gray-code encoding of both pointers for safe CDC. Full detection uses the inverted-top-two-bits comparison technique. Read data is combinational (first-word-fall-through behavior).

---

### fifo_sync.v

Synchronous FIFO with parameterized depth and almost-full/almost-empty thresholds.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Data bus width |
| `DEPTH` | 16 | FIFO depth (must be power of 2) |
| `ALMOST_FULL_THRESH` | DEPTH - 2 | Almost-full threshold |
| `ALMOST_EMPTY_THRESH` | 2 | Almost-empty threshold |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `wr_data` | in | DATA_WIDTH | Write data |
| `wr_en` | in | 1 | Write enable |
| `rd_en` | in | 1 | Read enable |
| `rd_data` | out | DATA_WIDTH | Read data |
| `full` | out | 1 | FIFO full |
| `almost_full` | out | 1 | Count >= ALMOST_FULL_THRESH |
| `empty` | out | 1 | FIFO empty |
| `almost_empty` | out | 1 | Count <= ALMOST_EMPTY_THRESH |
| `count` | out | $clog2(DEPTH)+1 | Current occupancy |

**Implementation:** Binary pointers with extra MSB for full/empty detection. Count derived as `wr_ptr - rd_ptr`. FWFT-style combinational read output. Writes guarded by `!full`, reads by `!empty`.

---

### fixed_point_pkg.v

Fixed-point arithmetic utilities: parameter definitions, saturation, and rounding modules.

#### Module: `fixed_point_pkg`

Defines default Q-format parameters: Q1.22 in a 24-bit word.

| Localparam | Value | Description |
|------------|-------|-------------|
| `DEFAULT_DATA_WIDTH` | 24 | Total word width |
| `DEFAULT_FRAC_BITS` | 22 | Fractional bits |
| `DEFAULT_INT_BITS` | 1 | Integer bits |

#### Module: `saturate`

Clamps a wider signed result to fit in a narrower output without wraparound.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `INPUT_WIDTH` | 48 | Input data width |
| `OUTPUT_WIDTH` | 24 | Output data width |

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `data_in` | in | INPUT_WIDTH (signed) | Wide input |
| `data_out` | out | OUTPUT_WIDTH (signed) | Saturated output |
| `overflow` | out | 1 | Saturation occurred |

#### Module: `round`

Reduces fractional precision with configurable rounding mode.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `INPUT_WIDTH` | 48 | Input width |
| `OUTPUT_WIDTH` | 24 | Output width |
| `INPUT_FRAC` | 30 | Input fractional bits |
| `OUTPUT_FRAC` | 22 | Output fractional bits |
| `ROUND_MODE` | 0 | 0 = truncate, 1 = round-half-up, 2 = banker's rounding |

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `data_in` | in | INPUT_WIDTH (signed) | Input |
| `data_out` | out | OUTPUT_WIDTH (signed) | Rounded output |

**Implementation:** Mode 0 truncates. Mode 1 adds 0.5 LSB before truncation. Mode 2 (banker's) uses guard/round/sticky bits to eliminate DC bias.

---

### pipeline_reg.v

Generic N-stage pipeline register with clock enable.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 24 | Data bus width |
| `STAGES` | 1 | Number of pipeline stages (0 = passthrough) |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset |
| `en` | in | 1 | Clock enable |
| `data_in` | in | DATA_WIDTH | Input data |
| `data_out` | out | DATA_WIDTH | Output (delayed by STAGES cycles) |

**Implementation:** Shift register chain. All stages share the enable and advance in lockstep. Reset clears all stages to zero. When `STAGES=0`, purely combinational passthrough.

---

### round_saturate.v

Combined rounding then saturation — the canonical output-formatting block for DSP datapaths.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `INPUT_WIDTH` | 48 | Input data width |
| `OUTPUT_WIDTH` | 24 | Output data width |
| `INPUT_FRAC` | 30 | Input fractional bits |
| `OUTPUT_FRAC` | 22 | Output fractional bits |
| `ROUND_MODE` | 0 | 0 = truncate, 1 = round-half-up, 2 = banker's |
| `SAT_MODE` | 1 | 0 = wrap, 1 = saturate |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `data_in` | in | INPUT_WIDTH (signed) | Wide input |
| `data_out` | out | OUTPUT_WIDTH (signed) | Formatted output |
| `overflow` | out | 1 | Saturation occurred |

**Implementation:** Two combinational stages: (1) apply rounding mode to reduce fractional bits, (2) check sign-extension consistency and saturate to max positive/negative on overflow. Used after multipliers in butterfly computations and filter outputs.

---

### single_port_ram.v

Single-port RAM with synthesis hints and optional hex initialization.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ADDR_WIDTH` | 10 | Address width (depth = 2^ADDR_WIDTH) |
| `DATA_WIDTH` | 24 | Data bus width |
| `INIT_FILE` | `""` | Hex initialization file |
| `RAM_STYLE` | `"block"` | Synthesis hint: `"block"` or `"distributed"` |

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | Clock |
| `we` | in | 1 | Write enable |
| `addr` | in | ADDR_WIDTH | Address |
| `din` | in | DATA_WIDTH | Write data |
| `dout` | out | DATA_WIDTH | Read data (1-cycle latency) |

**Implementation:** Write-first semantics (same-address read reflects new data). Registered output with 1-cycle read latency. Uses `(* ram_style *)` synthesis attribute.
