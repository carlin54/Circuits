# RV64G Processor Architecture

## Overview

Multi-cycle FSM processor implementing RV64IMAFD (RV64G).
All instructions are 32 bits (no C extension). Unified memory (code + data in same array).
Configurable memory size, default 256KB. Base address `0x80000000` (standard RISC-V DRAM base).
PC resets to `0x80000000`. Stack pointer initialized to top of memory (`0x80000000 + MEM_SIZE - 8`).

---

## FSM States

| State | Encoding | Action |
|-------|----------|--------|
| `FETCH` | 3'b000 | Present PC to memory (combinational read), latch result into IR on clock edge |
| `DECODE` | 3'b001 | Decode IR, read register files, compute immediate, latch branch target (PC+imm) |
| `EXECUTE` | 3'b010 | ALU/FPU/address computation, branch condition evaluation |
| `MEMORY` | 3'b011 | Load/store/AMO data memory access |
| `WRITEBACK` | 3'b100 | Write result to register file, update PC |
| `FP_EXEC` | 3'b101 | Multi-cycle FPU operation in progress (stall here until fpu_done) |
| `MULDIV_EXEC` | 3'b110 | Multi-cycle multiply/divide in progress (stall here until muldiv_done) |

### State Transitions

```
FETCH → DECODE → EXECUTE ──┬──→ MEMORY → WRITEBACK → FETCH
                            │
                            ├──→ WRITEBACK → FETCH  (no memory access needed)
                            │
                            ├──→ FP_EXEC ─(loop until done)─→ WRITEBACK → FETCH
                            │
                            └──→ MULDIV_EXEC ─(loop until done)─→ WRITEBACK → FETCH
```

Instructions that skip MEMORY state: all arithmetic, logic, shifts, branches, jumps, CSR ops, FENCE, ECALL/EBREAK.
Instructions that need MEMORY state: loads, stores.
Instructions that need AMO sequence: AMO (MEMORY_READ → AMO_COMPUTE → MEMORY_WRITE, handled as sub-states within MEMORY).
Instructions that go to FP_EXEC: FDIV, FSQRT (iterative, multi-cycle).
Instructions that go to MULDIV_EXEC: MUL*, DIV*, REM* (iterative, multi-cycle).

Note: FMADD/FMUL/FADD complete in EXECUTE (combinational). Only FDIV and FSQRT are iterative.

AMO sequencing: The control FSM uses a 2-bit `mem_cycle` counter (internal to `control.v`,
reset to 0 on entering MEMORY state) to manage multi-cycle MEMORY operations:

| mem_cycle | Action (AMO) | Action (LR) | Action (SC) |
|-----------|-------------|-------------|-------------|
| 0 | mem_read=1, addr=ALU_OUT → latch MEM_DATA | mem_read=1, set reservation → WRITEBACK | check reservation; mem_write=1 only if valid → WRITEBACK |
| 1 | amo.result ready, mem_write=1, wdata=amo.result | — | — |
| 2 | → WRITEBACK (rd = MEM_DATA, old value) | — | — |

For non-AMO loads/stores: single cycle in MEMORY, then transition to WRITEBACK.
  (`mem_cycle` is irrelevant — FSM transitions unconditionally after 1 clock.)
For LR: same as a normal load — single cycle in MEMORY (read + set reservation),
  then transition to WRITEBACK (rd = loaded value via MEM_DATA).
For SC: single cycle in MEMORY (check reservation, conditional write),
  then transition to WRITEBACK.
  SC writeback: MEM_DATA latch is loaded with 0 (success) or 1 (failure) by control logic —
  NOT from mem.rdata. The `wb_src=001` path then delivers this to rd. This is a special case:
  `MEM_DATA = reservation_valid && (reservation_addr == ALU_OUT) ? 64'd0 : 64'd1;`
For AMO: 2 cycles in MEMORY (read, then write), then WRITEBACK (rd = old value from MEM_DATA).

---

## Module Port Specifications

### `top.v` — Top Level

```verilog
module top #(
    parameter MEM_SIZE  = 262144,       // 256KB in bytes
    parameter BASE_ADDR = 64'h80000000  // memory and PC reset base address
)(
    input  wire        clk,
    input  wire        rst_n,     // active-low reset
    output wire        halt       // ECALL/EBREAK detected
);
```

### `pc.v` — Program Counter

```verilog
module pc #(
    parameter RESET_ADDR = 64'h80000000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pc_write,   // enable (0 = stall)
    input  wire [63:0] next_pc,
    output reg  [63:0] pc_out      // resets to RESET_ADDR
);
```

### `ir.v` — Instruction Register

```verilog
module ir (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ir_write,   // enable (0 = hold)
    input  wire [31:0] instr_in,
    output reg  [31:0] instr_out
);
```

### `mem.v` — Unified Memory

```verilog
module mem #(
    parameter SIZE      = 262144,        // bytes (256KB default)
    parameter BASE_ADDR = 64'h80000000   // memory base address
)(
    input  wire        clk,
    input  wire [63:0] addr,             // absolute address (base subtracted internally)
    input  wire [63:0] wdata,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  mem_size,         // 3'b000=byte, 001=half, 010=word, 011=double
    input  wire        mem_unsigned,     // 1=zero-extend, 0=sign-extend (loads only)
    input  wire        mem_fetch,        // 1=instruction fetch (always 32-bit read), from control.mem_fetch
    output wire [31:0] instr,            // instruction output (FETCH state)
    output wire [63:0] rdata,            // data output (MEMORY state)
    output wire        out_of_bounds     // (addr - BASE_ADDR) >= SIZE
);
```

Address translation: `offset = addr - BASE_ADDR`. All internal array indexing uses `offset`.
`out_of_bounds` is true when `addr < BASE_ADDR` or `offset >= SIZE`.
This signal is NOT consumed by the processor RTL (no exception mechanism). It is exposed for
the testbench to detect errant memory accesses and report them as test failures.

Byte ordering: **little-endian** (RISC-V standard). LSB at lowest address.
Storage: `reg [7:0] mem [0:SIZE-1]` — byte-addressed array.

Unaligned access: **supported**. The module assembles/disassembles bytes regardless of alignment.
No alignment exceptions (consistent with no-exception design).

Reads are combinational (output available same cycle address is presented).
Writes are synchronous (committed on posedge clk when `mem_write` asserted).

Initialization: `$readmemh(HEX_FILE, mem)` where `HEX_FILE` is a string parameter.
The testbench sets this parameter from a preprocessor define: the testbench receives
`-DTEST_HEX="program.hex"` from iverilog and passes it to mem.v as a parameter override.
The hex file uses `@` address annotations relative to 0 (i.e., address 0 in the file maps to `mem[0]`,
which corresponds to physical address `BASE_ADDR`).

`mem_size` encoding:
| Value | Access |
|-------|--------|
| 3'b000 | Byte (8-bit) |
| 3'b001 | Halfword (16-bit) |
| 3'b010 | Word (32-bit) |
| 3'b011 | Doubleword (64-bit) |

### `decoder.v` — Instruction Decoder

```verilog
module decoder (
    input  wire [31:0] instr,
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rs3,         // R4-type (FMADD etc), same bits as funct5
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire [1:0]  fmt,         // FP format: 00=S, 01=D (instr[26:25])
    output wire [4:0]  funct5,      // instr[31:27] — for OP-FP; same bits as rs3 for R4-type
    output wire [63:0] imm,         // sign-extended immediate (format auto-detected from opcode)
    output wire [11:0] imm_i        // raw I-type immediate (instr[31:20]), used by control for ECALL/EBREAK/CSR addr
);
```

Immediate generation per format:
| Type | Bits | Sign-extended from |
|------|------|--------------------|
| I-type | instr[31:20] | bit 31 |
| S-type | {instr[31:25], instr[11:7]} | bit 31 |
| B-type | {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0} | bit 31 |
| U-type | {instr[31:12], 12'b0} | bit 31 |
| J-type | {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0} | bit 31 |

### `control.v` — Control FSM

```verilog
module control (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire [4:0]  funct5,
    input  wire [1:0]  fmt,
    input  wire [11:0] imm_i,          // I-type immediate (for ECALL/EBREAK distinction)
    input  wire        branch_taken,
    input  wire        fpu_done,
    input  wire        muldiv_done,
    input  wire [2:0]  frm,            // current rounding mode from CSR (for DYN resolution)

    output reg  [2:0]  state,
    output reg         pc_write,
    output reg         ir_write,
    output reg         reg_write,      // integer rd write enable
    output reg         fp_reg_write,   // fp rd write enable
    output reg  [3:0]  alu_op,
    output reg  [1:0]  alu_src_a,      // 00=rs1, 01=pc, 10=zero
    output reg         alu_src_b,      // 0=rs2, 1=imm
    output reg         is_word_op,     // W-suffix instruction
    output reg         mem_read,
    output reg         mem_write,
    output reg  [2:0]  mem_size,
    output reg         mem_unsigned,
    output reg         mem_fetch,      // 1=instruction fetch (FETCH state)
    output reg  [2:0]  wb_src,         // 000=alu, 001=mem, 010=fpu, 011=pc+4, 100=csr, 101=muldiv
    output reg  [1:0]  pc_src,         // 00=pc+4, 01=branch_target, 10=alu(jalr)
    output reg         muldiv_start,   // start multiply/divide operation
    output reg  [3:0]  muldiv_op,     // which mul/div operation (passed to muldiv.v)
    output reg  [4:0]  fpu_op,
    output reg         fpu_start,
    output reg  [2:0]  fpu_rm,         // rounding mode (resolved: if instr rm=111, use frm input)
    output reg         fpu_single,     // 1=single precision, 0=double
    output reg  [3:0]  amo_op,
    output reg         amo_en,
    output reg         amo_word,       // 1=.W (32-bit AMO), 0=.D (64-bit AMO)
    output reg         csr_write,
    output reg  [1:0]  csr_op,         // 00=RW, 01=RS, 10=RC
    output reg         fflags_write,   // asserted in WRITEBACK for FP instructions (OR flags into CSR)
    output reg         halt
);
```

### `regfile.v` — Integer Register File

```verilog
module regfile (
    input  wire        clk,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [63:0] rd_data,
    input  wire        reg_write,    // from control.reg_write
    output wire [63:0] rs1_data,
    output wire [63:0] rs2_data
);
// x0 always reads as 0. Writes to x0 are ignored.
// Synchronous write (posedge clk), asynchronous read.
```

### `fp_regfile.v` — Floating-Point Register File

```verilog
module fp_regfile (
    input  wire        clk,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rs3_addr,     // for FMADD/FMSUB/etc
    input  wire [4:0]  rd_addr,
    input  wire [63:0] rd_data,
    input  wire        fp_reg_write,  // from control.fp_reg_write
    output wire [63:0] rs1_data,
    output wire [63:0] rs2_data,
    output wire [63:0] rs3_data
);
// All registers are 64 bits.
// Single-precision values are NaN-boxed: upper 32 bits = 0xFFFFFFFF.
// On read, if upper 32 bits != 0xFFFFFFFF and operation is .S, input is canonical NaN.
```

### `alu.v` — Integer ALU

```verilog
module alu (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [3:0]  alu_op,
    input  wire        is_word_op,  // operate on lower 32 bits, sign-extend
    output wire [63:0] result
);
```

`alu_op` encoding:
| Value | Operation |
|-------|-----------|
| 4'b0000 | ADD |
| 4'b0001 | SUB |
| 4'b0010 | AND |
| 4'b0011 | OR |
| 4'b0100 | XOR |
| 4'b0101 | SLL (shift left logical) |
| 4'b0110 | SRL (shift right logical) |
| 4'b0111 | SRA (shift right arithmetic) |
| 4'b1000 | SLT (set less than, signed) |
| 4'b1001 | SLTU (set less than, unsigned) |
| 4'b1010 | PASS_B (pass input B through — for LUI) |

When `is_word_op=1`: inputs truncated to 32 bits, result sign-extended from bit 31 to 64 bits.

### `muldiv.v` — Multiply/Divide Unit

```verilog
module muldiv (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [3:0]  op,          // which mul/div operation
    input  wire        is_word_op,  // W-variant (32-bit operands)
    output wire [63:0] result,
    output wire        done,        // operation complete
    output wire        busy         // not consumed by FSM (uses done only); available for debug
);
```

`op` encoding:
| Value | Operation |
|-------|-----------|
| 4'b0000 | MUL (lower 64 bits of product) |
| 4'b0001 | MULH (upper 64 bits, signed×signed) |
| 4'b0010 | MULHSU (upper 64 bits, signed×unsigned) |
| 4'b0011 | MULHU (upper 64 bits, unsigned×unsigned) |
| 4'b0100 | DIV (signed division) |
| 4'b0101 | DIVU (unsigned division) |
| 4'b0110 | REM (signed remainder) |
| 4'b0111 | REMU (unsigned remainder) |

### `fpu.v` — Floating-Point Unit

```verilog
module fpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] a,           // operand 1 (from fp_regfile or int_regfile)
    input  wire [63:0] b,           // operand 2
    input  wire [63:0] c,           // operand 3 (for FMADD)
    input  wire [4:0]  op,          // FPU operation
    input  wire        single,      // 1=single(.S), 0=double(.D)
    input  wire [2:0]  rm,          // rounding mode
    output wire [63:0] result,
    output wire [4:0]  fflags,      // exception flags: NV|DZ|OF|UF|NX
    output wire        done,
    output wire        busy         // not consumed by FSM (uses done only); available for debug
);
```

`op` encoding:
| Value | Operation |
|-------|-----------|
| 5'b00000 | FADD |
| 5'b00001 | FSUB |
| 5'b00010 | FMUL |
| 5'b00011 | FDIV (multi-cycle) |
| 5'b00100 | FSQRT (multi-cycle) |
| 5'b00101 | FMADD (a×b + c) |
| 5'b00110 | FMSUB (a×b - c) |
| 5'b00111 | FNMADD (-(a×b) - c) |
| 5'b01000 | FNMSUB (-(a×b) + c) |
| 5'b01001 | FSGNJ (sign inject) |
| 5'b01010 | FSGNJN (sign inject negate) |
| 5'b01011 | FSGNJX (sign inject xor) |
| 5'b01100 | FMIN |
| 5'b01101 | FMAX |
| 5'b01110 | FCVT.W (float → signed 32-bit int) |
| 5'b01111 | FCVT.WU (float → unsigned 32-bit int) |
| 5'b10000 | FCVT.L (float → signed 64-bit int) |
| 5'b10001 | FCVT.LU (float → unsigned 64-bit int) |
| 5'b10010 | FCVT.S/D.W (signed 32-bit int → float) |
| 5'b10011 | FCVT.S/D.WU (unsigned 32-bit int → float) |
| 5'b10100 | FCVT.S/D.L (signed 64-bit int → float) |
| 5'b10101 | FCVT.S/D.LU (unsigned 64-bit int → float) |
| 5'b10110 | FCVT.S.D / FCVT.D.S (single ↔ double) |
| 5'b10111 | FMV.X.W / FMV.X.D (fp reg → int reg, bitwise) |
| 5'b11000 | FMV.W.X / FMV.D.X (int reg → fp reg, bitwise) |
| 5'b11001 | FEQ |
| 5'b11010 | FLT |
| 5'b11011 | FLE |
| 5'b11100 | FCLASS |

Rounding modes (`rm`):
| Value | Mode | Description |
|-------|------|-------------|
| 3'b000 | RNE | Round to nearest, ties to even |
| 3'b001 | RTZ | Round towards zero |
| 3'b010 | RDN | Round down (towards -∞) |
| 3'b011 | RUP | Round up (towards +∞) |
| 3'b100 | RMM | Round to nearest, ties to max magnitude |
| 3'b111 | DYN | Use frm register (dynamic) |

Exception flags (`fflags`):
| Bit | Flag | Meaning |
|-----|------|---------|
| 4 | NV | Invalid operation |
| 3 | DZ | Divide by zero |
| 2 | OF | Overflow |
| 1 | UF | Underflow |
| 0 | NX | Inexact |

### `branch.v` — Branch Evaluation

```verilog
module branch (
    input  wire [63:0] a,           // rs1 value
    input  wire [63:0] b,           // rs2 value
    input  wire [2:0]  branch_type, // which comparison
    output wire        taken
);
```

`branch_type` encoding (matches funct3 directly — wired from decoder.funct3 in top.v):
| Value | Condition |
|-------|-----------|
| 3'b000 | BEQ (a == b) |
| 3'b001 | BNE (a != b) |
| 3'b100 | BLT (signed a < b) |
| 3'b101 | BGE (signed a >= b) |
| 3'b110 | BLTU (unsigned a < b) |
| 3'b111 | BGEU (unsigned a >= b) |

Values 3'b010 and 3'b011 are unused (no RISC-V branch uses these funct3 codes).
Default output for unused values: `taken = 0`.

### `amo.v` — Atomic Memory Operations

```verilog
module amo (
    input  wire [63:0] rs2_data,    // value to combine
    input  wire [63:0] mem_data,    // value read from memory
    input  wire [3:0]  amo_op,
    input  wire        is_word,     // .W vs .D (driven by control.amo_word)
    output wire [63:0] result       // value to write back to memory
);
// Combinational: computes new value for memory write.
// The FSM handles the read-modify-write sequence.
```

`amo_op` encoding:
| Value | Operation |
|-------|-----------|
| 4'b0000 | AMOSWAP (result = rs2) |
| 4'b0001 | AMOADD (result = mem + rs2) |
| 4'b0010 | AMOAND (result = mem & rs2) |
| 4'b0011 | AMOOR (result = mem \| rs2) |
| 4'b0100 | AMOXOR (result = mem ^ rs2) |
| 4'b0101 | AMOMAX (result = max(mem, rs2) signed) |
| 4'b0110 | AMOMIN (result = min(mem, rs2) signed) |
| 4'b0111 | AMOMAXU (result = max(mem, rs2) unsigned) |
| 4'b1000 | AMOMINU (result = min(mem, rs2) unsigned) |


LR and SC do not use `amo.v` — they are handled directly by the FSM and reservation
registers in `top.v`. See "LR/SC Reservation" section below.

### `csr.v` — CSR Registers (FP only)

```verilog
module csr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] csr_addr,    // from decoder.imm_i (wired directly in top.v)
    input  wire [63:0] wdata,       // from CSR wdata MUX (register value or zero-extended uimm)
    input  wire [1:0]  csr_op,      // 00=RW, 01=RS(set bits), 10=RC(clear bits)
    input  wire        csr_write,   // from control.csr_write
    input  wire [4:0]  fflags_in,   // from FPU output flags
    input  wire        fflags_write, // from control.fflags_write
    output wire [63:0] rdata,       // old CSR value → wb_src=100 path
    output wire [2:0]  frm_out      // current rounding mode → control.frm input
);
// Implements: fcsr(0x003), frm(0x002), fflags(0x001)
// Unimplemented addresses: reads return 0, writes ignored (no exception)
// fflags are sticky (OR'd in, never cleared except by CSR write)
```

---

## Datapath MUXes (wired in `top.v`)

### ALU Input A MUX (`alu_src_a`)
| Select | Source | Used by |
|--------|--------|---------|
| 2'b00 | rs1_data | Most ALU ops |
| 2'b01 | pc | AUIPC |
| 2'b10 | 64'b0 | LUI (zero + imm = imm) |

### ALU Input B MUX (`alu_src_b`)
| Select | Source | Used by |
|--------|--------|---------|
| 1'b0 | rs2_data | R-type ops |
| 1'b1 | imm | I-type ops, loads, stores, AUIPC, LUI |

### Writeback Data MUX (`wb_src`)
| Select | Source | Used by |
|--------|--------|---------|
| 3'b000 | alu_result | Arithmetic, logic, shifts |
| 3'b001 | MEM_DATA latch | Loads (integer and FP), AMO (old mem value) |
| 3'b010 | fpu_result | FP operations |
| 3'b011 | pc + 4 | JAL, JALR (return address) |
| 3'b100 | csr_rdata | CSR reads (old value to rd) |
| 3'b101 | muldiv_result | MUL/DIV/REM operations |

### Next PC MUX (`pc_src`)
| Select | Source | Used by |
|--------|--------|---------|
| 2'b00 | pc + 4 | Sequential execution |
| 2'b01 | branch_target (pc + imm) | Taken branches, JAL |
| 2'b10 | alu_result (rs1 + imm) | JALR |

### Memory Address MUX (`mem_addr_src`)

The `mem.addr` input is driven by a MUX controlled by the FSM state:

| State | Source | Purpose |
|-------|--------|---------|
| FETCH | pc_out | Instruction fetch at current PC |
| MEMORY | ALU_OUT latch | Data address (rs1+imm computed in EXECUTE) |

This MUX is implicit in `top.v` wiring — no dedicated module needed.

### Memory Write Data MUX (`mem_wdata_src`)

The `mem.wdata` input is driven by:

| Condition | Source | Purpose |
|-----------|--------|---------|
| Normal store (STORE, STORE-FP) | B latch | rs2 data (int or FP, selected in DECODE) |
| AMO write (mem_cycle 1) | amo.result | Computed new value from amo.v |

Control signal `amo_en` selects between these in `top.v`.

### Dedicated Adders (non-ALU)

Two hardwired adders exist outside the ALU for values needed independently:

| Adder | Computed in | Formula | Used by |
|-------|-------------|---------|---------|
| Branch target | DECODE | pc_out + IMM (sign-extended) | BRANCH_TARGET latch, pc_src=01 |
| PC+4 | WRITEBACK (combinational) | pc_out + 4 | wb_src=011 (link address), pc_src=00 |

These are simple `assign` statements in `top.v`, not separate modules.
The ALU is NOT used for branch target or PC+4 — it is free for address computation (JALR)
and arithmetic during EXECUTE.

### DECODE Latch Source MUX (`reg_src`)

During DECODE, latches A/B/C are loaded from either integer or FP register file:

| Signal | Condition | A (rs1) source | B (rs2) source | C (rs3) source |
|--------|-----------|---------------|---------------|---------------|
| FP arithmetic (OP-FP, MADD/MSUB) | opcode ∈ {1010011, 100x011} AND reads FP rs1 | fp_regfile.rs1 | fp_regfile.rs2 | fp_regfile.rs3 |
| FP store (STORE-FP) | opcode = 0100111 | int_regfile.rs1 (address) | fp_regfile.rs2 (data) | — |
| FP load (LOAD-FP) | opcode = 0000111 | int_regfile.rs1 (address) | — | — |
| FMV/FCVT int→fp | opcode=1010011, funct5 ∈ {11110, 11010} | int_regfile.rs1 | — | — |
| Everything else | — | int_regfile.rs1 | int_regfile.rs2 | — |

Determining whether an OP-FP instruction reads from int vs FP register file:
- Reads integer rs1: FMV.W.X (funct5=11110), FMV.D.X (funct5=11110), FCVT.S.W/WU/L/LU (funct5=11010), FCVT.D.W/WU/L/LU (funct5=11010)
- Pattern: `funct5[4:3] == 2'b11 && funct5[1] == 1'b1` → read from int_regfile
- All other OP-FP instructions read from fp_regfile

### Memory Size Derivation (`mem_size`)

| Instruction type | mem_size source |
|-----------------|-----------------|
| Integer loads/stores (LOAD, STORE) | funct3[1:0] directly (000→byte, 001→half, 010→word, 011→double) |
| FP loads/stores (FLW/FSW) | 3'b010 (word, 32-bit) |
| FP loads/stores (FLD/FSD) | 3'b011 (doubleword, 64-bit) |
| AMO .W operations | 3'b010 (word) |
| AMO .D operations | 3'b011 (doubleword) |

`mem_unsigned` is funct3[2] for integer loads (LBU/LHU/LWU set it). Always 0 for AMO.
For FP loads: control forces `mem_unsigned=1` (override, since FLW funct3=010 has funct3[2]=0). FLW produces a 32-bit value
zero-extended to 64 bits. The writeback path then NaN-boxes single-precision FP loads:

```verilog
// In top.v, for FLW writeback (fp_reg_write=1 and mem_size==word):
wb_data = {32'hFFFFFFFF, MEM_DATA[31:0]};  // NaN-box the single-precision value
```

FLD loads a full 64-bit double — no NaN-boxing needed (written directly to fp_regfile).

### Muldiv Operation Derivation (`muldiv_op`)

Passed directly from funct3 (zero-extended to 4 bits). The control FSM sets `muldiv_op = {1'b0, funct3}` for 64-bit ops. For W-variants, the `is_word_op` signal tells muldiv.v to truncate operands.

### AMO Operation Derivation (`amo_op`)

Remapped from `funct7[6:2]` (instruction encoding) to a compact 4-bit value in control.v:

| funct7[6:2] | amo_op | Operation |
|-------------|--------|-----------|
| 00001 | 4'b0000 | AMOSWAP |
| 00000 | 4'b0001 | AMOADD |
| 01100 | 4'b0010 | AMOAND |
| 01000 | 4'b0011 | AMOOR |
| 00100 | 4'b0100 | AMOXOR |
| 10100 | 4'b0101 | AMOMAX |
| 10000 | 4'b0110 | AMOMIN |
| 11100 | 4'b0111 | AMOMAXU |
| 11000 | 4'b1000 | AMOMINU |

This is NOT a direct pass-through — control.v must implement a case statement or lookup.
LR (funct7[6:2]=00010) and SC (funct7[6:2]=00011) do not use `amo_op` — they are handled
directly by the FSM.

### FPU Flags Accumulation

`fflags_write` is asserted in WRITEBACK whenever an FP instruction completes (either from FP_EXEC or single-cycle FP ops in EXECUTE). The CSR module OR's the FPU's output flags into the sticky fflags register on that signal.

---

## Testbench Access to Memory (tohost mechanism)

The testbench detects pass/fail by directly accessing the memory array via hierarchical reference:

```verilog
wire [63:0] tohost = {
    dut.memory.mem[TOHOST_ADDR+7], dut.memory.mem[TOHOST_ADDR+6],
    dut.memory.mem[TOHOST_ADDR+5], dut.memory.mem[TOHOST_ADDR+4],
    dut.memory.mem[TOHOST_ADDR+3], dut.memory.mem[TOHOST_ADDR+2],
    dut.memory.mem[TOHOST_ADDR+1], dut.memory.mem[TOHOST_ADDR+0]
};

always @(posedge clk) begin
    if (tohost != 0) begin
        if (tohost == 1) $display("PASS");
        else $display("FAIL: test case %0d", tohost >> 1);
        $finish;
    end
end
```

TOHOST_ADDR is extracted from the compiled ELF's symbol table during the build process:
`riscv64-unknown-elf-nm test.elf | grep ' tohost' | awk '{print $1}'`

The extracted address is an absolute address (e.g., 0x80001000). Since the memory array is
indexed from 0 (base address subtracted internally by mem.v), the testbench must subtract
BASE_ADDR to get the array offset:
```
TOHOST_OFFSET = TOHOST_ADDR - BASE_ADDR
```
This offset is passed to iverilog as a decimal integer: `-DTOHOST_ADDR=4096` (array index, not physical address).

---

## Opcode Map (for decoder → control)

| Opcode [6:0] | Name | Type | Instructions |
|-------------|------|------|--------------|
| 0110011 | OP | R | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| 0111011 | OP-32 | R | ADDW, SUBW, SLLW, SRLW, SRAW |
| 0010011 | OP-IMM | I | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU |
| 0011011 | OP-IMM-32 | I | ADDIW, SLLIW, SRLIW, SRAIW |
| 0110111 | LUI | U | LUI |
| 0010111 | AUIPC | U | AUIPC |
| 1101111 | JAL | J | JAL |
| 1100111 | JALR | I | JALR |
| 1100011 | BRANCH | B | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| 0000011 | LOAD | I | LB, LBU, LH, LHU, LW, LWU, LD |
| 0100011 | STORE | S | SB, SH, SW, SD |
| 0110011 | OP (M) | R | MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU (funct7=0000001) |
| 0111011 | OP-32 (M) | R | MULW, DIVW, DIVUW, REMW, REMUW (funct7=0000001) |
| 0101111 | AMO | R | LR, SC, AMOSWAP, AMOADD, ... |
| 0000111 | LOAD-FP | I | FLW, FLD |
| 0100111 | STORE-FP | S | FSW, FSD |
| 1000011 | MADD | R4 | FMADD.S, FMADD.D |
| 1000111 | MSUB | R4 | FMSUB.S, FMSUB.D |
| 1001011 | NMSUB | R4 | FNMSUB.S, FNMSUB.D |
| 1001111 | NMADD | R4 | FNMADD.S, FNMADD.D |
| 1010011 | OP-FP | R | FADD, FSUB, FMUL, FDIV, FSQRT, FCVT, FCMP, FCLASS, FMOV, FSGNJ |
| 0001111 | MISC-MEM | I | FENCE (funct3=000), FENCE.I (funct3=001) — both NOP |
| 1110011 | SYSTEM | I | ECALL, EBREAK, CSRRxx |

---

## Control Signal Table (per instruction group)

### Instruction-dependent signals by opcode:

These signals are determined by the opcode (available from IR in all states after FETCH).
The control FSM asserts them in the appropriate state:
- `alu_op`, `alu_src_a/b`, `is_word_op`: used in EXECUTE
- `mem_r`, `mem_w`: asserted in MEMORY state (not EXECUTE)
- `wb_src`, `reg_w`, `fp_w`: used in WRITEBACK state
- `pc_src`: used in WRITEBACK state (control.v holds the value from EXECUTE through WRITEBACK
  since IR is stable and branch_taken is combinational from latched A/B)

| Opcode | alu_op | alu_src_a | alu_src_b | is_word_op | mem_r | mem_w | wb_src | reg_w | fp_w | pc_src | notes |
|--------|--------|-----------|-----------|---------|-------|-------|--------|-------|------|--------|-------|
| OP | from funct | 00(rs1) | 0(rs2) | 0 | 0 | 0 | 000(alu) | 1 | 0 | 00(+4) | funct7≠0000001 |
| OP (M-ext) | — | 00(rs1) | 0(rs2) | 0 | 0 | 0 | 101(muldiv) | 1 | 0 | 00(+4) | funct7=0000001, → MULDIV_EXEC |
| OP-32 | from funct | 00(rs1) | 0(rs2) | 1 | 0 | 0 | 000(alu) | 1 | 0 | 00(+4) | funct7≠0000001 |
| OP-32 (M-ext) | — | 00(rs1) | 0(rs2) | 1 | 0 | 0 | 101(muldiv) | 1 | 0 | 00(+4) | funct7=0000001, → MULDIV_EXEC |
| OP-IMM | from funct | 00(rs1) | 1(imm) | 0 | 0 | 0 | 000(alu) | 1 | 0 | 00(+4) | |
| OP-IMM-32 | from funct | 00(rs1) | 1(imm) | 1 | 0 | 0 | 000(alu) | 1 | 0 | 00(+4) | |
| LUI | PASS_B | 10(zero) | 1(imm) | 0 | 0 | 0 | 000(alu) | 1 | 0 | 00(+4) | |
| AUIPC | ADD | 01(pc) | 1(imm) | 0 | 0 | 0 | 000(alu) | 1 | 0 | 00(+4) | |
| JAL | — | — | — | 0 | 0 | 0 | 011(pc+4) | 1 | 0 | 01(brn) | target from DECODE latch |
| JALR | ADD | 00(rs1) | 1(imm) | 0 | 0 | 0 | 011(pc+4) | 1 | 0 | 10(alu) | bit 0 cleared in pc_mux |
| BRANCH | — | — | — | 0 | 0 | 0 | — | 0 | 0 | 01 if taken, 00 if not | branch.v evaluates A,B; target from DECODE latch |
| LOAD | ADD | 00(rs1) | 1(imm) | 0 | 1 | 0 | 001(mem) | 1 | 0 | 00(+4) | addr = rs1+imm |
| STORE | ADD | 00(rs1) | 1(imm) | 0 | 0 | 1 | — | 0 | 0 | 00(+4) | addr = rs1+imm |
| LOAD-FP | ADD | 00(rs1) | 1(imm) | 0 | 1 | 0 | 001(mem) | 0 | 1 | 00(+4) | mem data → fp_regfile |
| STORE-FP | ADD | 00(rs1) | 1(imm) | 0 | 0 | 1 | — | 0 | 0 | 00(+4) | fp_regfile rs2 → mem wdata |
| OP-FP (arith) | — | — | — | — | 0 | 0 | 010(fpu) | 0 | 1 | 00(+4) | FADD,FSUB,FMUL,etc → fp_regfile |
| OP-FP (cmp/class/mv.x) | — | — | — | — | 0 | 0 | 010(fpu) | 1 | 0 | 00(+4) | FEQ,FLT,FLE,FCLASS,FMV.X → int_regfile |
| OP-FP (mv.wx/cvt.s) | — | — | — | — | 0 | 0 | 010(fpu) | 0 | 1 | 00(+4) | FMV.W.X,FCVT.S.W,etc → fp_regfile |
| MADD/MSUB/etc | — | — | — | — | 0 | 0 | 010(fpu) | 0 | 1 | 00(+4) | FPU handles |
| AMO | ADD | 00(rs1) | 1(imm=0) | 0 | — | — | 001(mem) | 1 | 0 | 00(+4) | addr=rs1+0, sequenced in MEMORY state |
| FENCE/FENCE.I | — | — | — | — | 0 | 0 | — | 0 | 0 | 00(+4) | NOP: no mem access, no reg write, skips MEMORY → goes EXECUTE→WRITEBACK |
| SYSTEM (CSR) | — | — | — | — | 0 | 0 | 100(csr) | 1 | 0 | 00(+4) | CSR old value → rd |
| SYSTEM (ECALL/EBREAK) | — | — | — | — | 0 | 0 | — | 0 | 0 | — | halt=1, pc_write=0 in WRITEBACK |

Notes:
- `reg_w` and `fp_w` are asserted in WRITEBACK state (not EXECUTE). Shown here for reference.
- BRANCH and JAL do not use the ALU. The branch target (pc+imm) is pre-computed in DECODE and stored in the BRANCH_TARGET latch. The branch module evaluates the condition from latched A/B values.
- JALR uses the ALU to compute rs1+imm. The Next PC MUX clears bit 0 of the ALU result before writing to PC.
- AMO signals (mem_read, mem_write) are sequenced across multiple cycles within the MEMORY state, not asserted simultaneously. The control FSM manages the read-modify-write sub-states.
- OP-FP is split into three rows because the destination register file depends on the specific operation. The control FSM determines `reg_write` vs `fp_reg_write` from the funct7/funct5 fields.
- SYSTEM (ECALL/EBREAK) is detected in EXECUTE via opcode + funct3 + imm_i. It follows the normal EXECUTE→WRITEBACK path but with halt=1 and no register write.
- CSR address (`csr.csr_addr`) is wired from `decoder.imm_i` directly in top.v (same bits as instr[31:20]).
- FENCE/FENCE.I: opcode 0001111, treated as NOP. Skips MEMORY, goes directly EXECUTE→WRITEBACK with no register write. Single-core with no cache/pipeline makes these no-ops.

### Per-State Control Signals (`pc_write`, `ir_write`, `mem_fetch`)

These signals are asserted based on FSM state, not opcode:

| State | pc_write | ir_write | mem_fetch | mem_read | Notes |
|-------|----------|----------|-----------|----------|-------|
| FETCH | 0 | 1 | 1 | 1 | Fetch instruction, latch into IR |
| DECODE | 0 | 0 | 0 | 0 | Decode, read regs, compute branch target |
| EXECUTE | 0 | 0 | 0 | 0 | ALU/FPU/branch evaluation |
| MEMORY | 0 | 0 | 0 | per opcode | Data access (mem_read/mem_write set per instruction) |
| WRITEBACK | 1* | 0 | 0 | 0 | Write register, advance PC (*0 when halt=1) |
| FP_EXEC | 0 | 0 | 0 | 0 | Wait for fpu_done |
| MULDIV_EXEC | 0 | 0 | 0 | 0 | Wait for muldiv_done |

`pc_write` is only asserted in WRITEBACK (and suppressed when halt=1).
`ir_write` is only asserted in FETCH (IR holds instruction for all subsequent states).
`mem_fetch` is only asserted in FETCH (distinguishes instruction fetch from data access).

---

## Internal Latches (registered between states)

The multi-cycle design requires latching intermediate values:

| Register | Width | Loaded in | Used in | Content |
|----------|-------|-----------|---------|---------|
| IR | 32 | FETCH | DECODE+ | Current instruction |
| A | 64 | DECODE | EXECUTE | rs1 data (int or fp) |
| B | 64 | DECODE | EXECUTE | rs2 data (int or fp) |
| C | 64 | DECODE | EXECUTE | rs3 data (fp, for FMADD) |
| IMM | 64 | DECODE | EXECUTE | Sign-extended immediate |
| ALU_OUT | 64 | EXECUTE | MEMORY/WB | ALU result / address |
| MEM_DATA | 64 | MEMORY | WRITEBACK | Data read from memory (latched when mem_read=1 OR by SC control logic) |
| BRANCH_TARGET | 64 | DECODE | EXECUTE | PC + immediate |

Note: FPU and muldiv results do NOT need external latches. Both modules are clocked and hold
their `result` output stable from the cycle `done=1` until a new `start` is asserted. Since
`start` is only asserted in EXECUTE and the result is consumed in WRITEBACK (the very next
state after done), the output is guaranteed stable during WRITEBACK.

---

## Testbench Interface

Testbenches access internal DUT state via Verilog hierarchical references. The following
instance names are fixed in `top.v` and used by both `tb_isa_test.v` and `tb_c_test.v`:

| Reference | Purpose |
|-----------|---------|
| `dut.halt` | Halt signal (ECALL/EBREAK detected) — output port |
| `dut.memory.mem[N]` | Memory array byte at offset N (0-based, after base subtraction) |
| `dut.regs.regs[N]` | Integer register x[N] value (for reading a0=x10 on halt) |
| `dut.pc_inst.pc_out` | Current PC value |
| `dut.ctrl.state` | Current FSM state (for timeout/debug) |

Module instance names in top.v: `memory` (mem.v), `regs` (regfile.v), `fp_regs` (fp_regfile.v),
`pc_inst` (pc.v), `ir_inst` (ir.v), `ctrl` (control.v), `alu_inst` (alu.v), `decode` (decoder.v),
`fpu_inst` (fpu.v), `muldiv_inst` (muldiv.v), `branch_inst` (branch.v), `amo_inst` (amo.v),
`csr_inst` (csr.v).

Testbench cycle limit: `parameter MAX_CYCLES = 10_000_000;` (sufficient for all ISA tests;
configurable via iverilog define `-DMAX_CYCLES=N`).

---

## Schematic Generation

Architecture diagram is generated directly from the Verilog source using Yosys + netlistsvg:

```bash
make schematic
# Runs: yosys → read_verilog rtl/*.v → prep -top top → write_json build/top.json
# Then: netlistsvg build/top.json -o docs/architecture.svg
```

No hand-maintained diagrams. The image always reflects the actual source.

---

## Reset Behavior

On `rst_n` going low:
- PC → `0x0000_0000_8000_0000` (configurable via RESET_ADDR parameter)
- All integer registers → 0 (including x0)
- All FP registers → 0
- FSM state → FETCH
- All control signals → 0
- fcsr/frm/fflags → 0

---

## Halt Condition

ECALL or EBREAK detected in EXECUTE state (opcode=1110011, funct3=000, imm_i=0x000 or 0x001).
The FSM transitions directly to WRITEBACK with `halt=1` (skipping MEMORY).
No register write occurs (reg_write=0). PC is NOT advanced: `pc_write` is deasserted in
WRITEBACK when `halt=1`. The FSM self-loops in WRITEBACK: `if (halt) next_state = WRITEBACK`
(the state register stays in WRITEBACK indefinitely, no re-fetch of the ECALL instruction).

In testbench: `always @(posedge clk) if (halt) $finish;`

For C programs, the convention is:
- `main()` returns into a trampoline that executes ECALL
- Return value of main is in register a0 (x10) — testbench checks this

---

## WRITEBACK State Behavior

Every instruction passes through WRITEBACK. Actions in WRITEBACK:
1. If `reg_write`: write `wb_data` to `int_regfile[rd]`
2. If `fp_reg_write`: write `wb_data` to `fp_regfile[rd]`
3. If neither: no register write (stores, branches)
4. Update PC based on `pc_src`
5. If FP instruction completed: OR FPU fflags into CSR fflags (`fflags_write` asserted)
6. Transition to FETCH

---

## FPU Start/Done Protocol

- **Single-cycle ops** (FADD, FSUB, FMUL, FMADD, FSGNJ, FCMP, FCLASS, FCVT, FMV, FMIN, FMAX):
  `fpu_start` asserted in EXECUTE. `done` goes high in the same cycle (combinational path).
  FSM sees `done=1` immediately and transitions to WRITEBACK next cycle.

- **Multi-cycle ops** (FDIV, FSQRT):
  `fpu_start` asserted in EXECUTE. `done` stays low. FSM transitions to FP_EXEC.
  FSM loops in FP_EXEC (checking `done` each cycle) until the iterative computation finishes.
  When `done` goes high, FSM transitions to WRITEBACK.

---

## DYN Rounding Mode Resolution

The control FSM resolves the rounding mode before passing it to the FPU:
```
fpu_rm = (instr_rm == 3'b111) ? frm : instr_rm;
```
Where `instr_rm` is funct3 of the FP instruction and `frm` is the CSR frm register value
(routed from `csr.frm_out` through `control.frm` input).

---

## CSR Data Path

For CSR instructions, the write data to the CSR module comes from two sources:

| Instruction type | CSR wdata source |
|-----------------|-----------------|
| CSRRW, CSRRS, CSRRC | rs1_data (integer register value, from latch A) |
| CSRRWI, CSRRSI, CSRRCI | zero-extended rs1 field: `{59'b0, instr[19:15]}` |

The control FSM distinguishes these via funct3[2]: if set, use the 5-bit immediate (rs1 field);
if clear, use the register value. A MUX in `top.v` selects between `A` (register data)
and `{59'b0, rs1_addr}` (immediate) based on this bit.

CSR op mapping from funct3: `csr_op = funct3[1:0] - 2'b01` (funct3 01→RW=00, 10→RS=01, 11→RC=10).

The CSR read value (old CSR contents) is written to integer rd through `wb_src=100(csr)`.
The CSR read data bypasses the ALU entirely — `csr.rdata` feeds directly into the writeback MUX
as the 5th source.

### CSR Read/Write Suppression

Control.v must implement these suppression rules (required for compliance tests):
- CSRRS/CSRRC with rs1=x0 (or CSRRSI/CSRRCI with uimm=0): `csr_write=0` (read-only, no write)
- CSRRW with rd=x0 (or CSRRWI with rd=x0): `reg_write=0` (write-only, no read to rd)

Detection in control.v: `rs1_addr == 5'b00000` for the write suppression, `rd == 5'b00000` for
the read suppression. Both fields come from decoder output (available from IR in DECODE+).

---

## CSR Unimplemented Address Behavior

Only addresses 0x001 (fflags), 0x002 (frm), 0x003 (fcsr) are implemented.
Reads from any other CSR address return 0. Writes to any other address are ignored (no-op).
No illegal instruction exception (consistent with no-exception design).

---

## Memory Write Data Path

The `mem.wdata` input is driven by the Memory Write Data MUX (see Datapath MUXes section):
- For integer stores (SB/SH/SW/SD): B latch holds `int_regfile[rs2]` (loaded in DECODE)
- For FP stores (FSW/FSD): B latch holds `fp_regfile[rs2]` (loaded in DECODE, per DECODE Latch Source MUX)
- For AMO writes (mem_cycle 1): `amo.result` (computed from MEM_DATA and B, selected by `amo_en`)

The DECODE stage selects the correct register file for B. The `amo_en` signal from control.v
gates the wdata MUX between B (normal stores) and amo.result (AMO write-back).

---

## LR/SC Reservation

The reservation state is a single register in `top.v` (not in `amo.v` which is combinational):

```verilog
reg        reservation_valid;
reg [63:0] reservation_addr;
```

- LR: sets `reservation_valid=1`, `reservation_addr=addr`. Loads data normally.
- SC: checks `reservation_valid && (reservation_addr == addr)`.
  - If check passes: writes data to memory, sets `x[rd] = 0` (success), clears `reservation_valid`.
  - If check fails: does NOT write memory, sets `x[rd] = 1` (failure), clears `reservation_valid`.

SC can fail even in single-core if:
- SC targets a different address than the preceding LR
- SC is executed without a preceding LR (`reservation_valid == 0`)
- Another SC already consumed the reservation

The reservation is cleared by any SC (pass or fail), and on reset.

---

## JALR Bit-0 Clear

The Next PC MUX for `pc_src=10(alu)` clears bit 0 of the ALU result before writing to PC:
```verilog
next_pc = (pc_src == 2'b10) ? {alu_result[63:1], 1'b0} : ...;
```
This implements the RISC-V spec requirement that JALR targets are aligned to 2-byte boundaries.

---

## Stack Pointer Initialization

The register file hardware resets all registers to 0. The stack pointer (x2/sp) is initialized
by software in `crt0.s` before calling main:
```asm
la sp, _stack_top    # set by linker script to BASE_ADDR + MEM_SIZE - 8
```
This is standard bare-metal practice — hardware does not set SP.
