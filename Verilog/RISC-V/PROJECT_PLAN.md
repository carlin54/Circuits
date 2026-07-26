# RISC-V Processor Project Plan

## Goal

Build a multi-cycle RV64G (RV64IMAFD) processor in Verilog that can execute any compiled C program including floating-point. Functional correctness is the only metric — verified against the official RISC-V ISA test suites (riscv-tests + riscv-arch-test) before anything else.

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ISA | RV64G (RV64IMAFD) | Run ALL C code including float/double |
| No C extension | Compile with `-march=rv64imafd` | All instructions 32-bit, simpler decoder |
| Control | Multi-cycle FSM | FETCH→DECODE→EXECUTE→MEMORY→WRITEBACK state machine |
| FPU | Hand-coded IEEE 754 | Full spec compliance, all 5 rounding modes |
| FPU div/sqrt | Iterative, multi-cycle | Stall FSM until done |
| Memory | Single unified, configurable, default 256KB | Verilog parameter, one memory for code+data |
| Schematic | Yosys + netlistsvg from Verilog source | `make schematic` generates architecture SVG for README |
| Correctness only | No timing/frequency targets | Combinational FPU is fine, we only care about correct results |
| Stack pointer | 0x80000000 + MEM_SIZE - 8 | Standard bare-metal convention: code at base, stack grows down from top |
| Tests | Git submodules (riscv-tests, riscv-arch-test) | Not checked into this repo, fetched on demand |
| Test runner | `run_tests.sh` | Runs all tests in order, stops on failure |
| Simulation | Icarus Verilog (iverilog/vvp) | Free, standard |
| Cross-compiler | riscv64-unknown-elf-gcc | Bare-metal, no OS |
| Reference | spike (riscv-isa-sim) | Golden model for debugging (run same binary, compare traces) |
| No cache | Direct memory access | Verilog array |
| No virtual memory | Physical addresses only | No MMU/TLB |
| No interrupts | No external interrupt handling | Bare-metal to completion |
| No trap vector | ECALL/EBREAK detected by FSM as halt (no mtvec/mepc/mcause) | Simplifies control, no exception vector |
| No exceptions | Illegal instr/misalign don't trap | Undefined opcodes = undefined behavior |
| Unaligned access | Supported (byte assembly) | No alignment exceptions, simpler for C structs |
| Endianness | Little-endian | RISC-V standard |
| Bad CSR access | Returns 0, writes ignored | No illegal instruction trap; compatible with test probes |
| Branch target | Pre-computed in DECODE (PC+imm latch) | ALU is free during branch EXECUTE |
| Base address | 0x80000000 | Matches riscv-tests DRAM base expectation |
| No OS | Programs start at 0x80000000, run to halt | Linker script + crt0.s |

---

## Target ISA: RV64G (RV64IMAFD) — 156 Instructions

Compiler flags: `-march=rv64imafd -mabi=lp64d -nostdlib -nostartfiles`

### RV64I Base Integer (59 instructions, includes Zicsr + Zifencei)

| Category | Instructions |
|----------|-------------|
| Arithmetic | ADD, ADDI, SUB, ADDW, ADDIW, SUBW |
| Logical | AND, ANDI, OR, ORI, XOR, XORI |
| Shift | SLL, SLLI, SRL, SRLI, SRA, SRAI, SLLW, SLLIW, SRLW, SRLIW, SRAW, SRAIW |
| Compare | SLT, SLTI, SLTU, SLTIU |
| Load | LB, LBU, LH, LHU, LW, LWU, LD |
| Store | SB, SH, SW, SD |
| Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Jump | JAL, JALR |
| Upper Imm | LUI, AUIPC |
| System | ECALL, EBREAK, FENCE, FENCE.I |
| CSR | CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI |

### M Extension (13 instructions)

| Category | Instructions |
|----------|-------------|
| Multiply | MUL, MULH, MULHSU, MULHU, MULW |
| Divide | DIV, DIVU, REM, REMU, DIVW, DIVUW, REMW, REMUW |

### F Extension — Single-Precision (30 instructions)

| Category | Instructions |
|----------|-------------|
| Arithmetic | FADD.S, FSUB.S, FMUL.S, FDIV.S, FSQRT.S |
| Fused Mul-Add | FMADD.S, FMSUB.S, FNMADD.S, FNMSUB.S |
| Sign Inject | FSGNJ.S, FSGNJN.S, FSGNJX.S |
| Compare | FEQ.S, FLT.S, FLE.S |
| Convert int↔fp | FCVT.W.S, FCVT.WU.S, FCVT.L.S, FCVT.LU.S, FCVT.S.W, FCVT.S.WU, FCVT.S.L, FCVT.S.LU |
| Move | FMV.X.W, FMV.W.X |
| Classify | FCLASS.S |
| Min/Max | FMIN.S, FMAX.S |
| Load/Store | FLW, FSW |

### D Extension — Double-Precision (32 instructions)

| Category | Instructions |
|----------|-------------|
| Arithmetic | FADD.D, FSUB.D, FMUL.D, FDIV.D, FSQRT.D |
| Fused Mul-Add | FMADD.D, FMSUB.D, FNMADD.D, FNMSUB.D |
| Sign Inject | FSGNJ.D, FSGNJN.D, FSGNJX.D |
| Compare | FEQ.D, FLT.D, FLE.D |
| Convert int↔fp | FCVT.W.D, FCVT.WU.D, FCVT.L.D, FCVT.LU.D, FCVT.D.W, FCVT.D.WU, FCVT.D.L, FCVT.D.LU |
| Convert S↔D | FCVT.S.D, FCVT.D.S |
| Move | FMV.X.D, FMV.D.X |
| Classify | FCLASS.D |
| Min/Max | FMIN.D, FMAX.D |
| Load/Store | FLD, FSD |

### A Extension — Atomics (22 instructions)

| Category | Instructions |
|----------|-------------|
| Load Reserved | LR.W, LR.D |
| Store Conditional | SC.W, SC.D |
| AMO Word | AMOSWAP.W, AMOADD.W, AMOAND.W, AMOOR.W, AMOXOR.W, AMOMAX.W, AMOMIN.W, AMOMAXU.W, AMOMINU.W |
| AMO Double | AMOSWAP.D, AMOADD.D, AMOAND.D, AMOOR.D, AMOXOR.D, AMOMAX.D, AMOMIN.D, AMOMAXU.D, AMOMINU.D |

All AMO operations trivially complete in single-core (no contention). LR/SC uses a reservation register — SC can fail if address mismatches or no prior LR.

---

## Architecture: Multi-Cycle FSM

### Memory Model

Single unified memory (code + data in same address space). Base address `0x80000000` (matches standard RISC-V DRAM base and riscv-tests expectations). Multi-cycle FSM naturally serializes access — only one memory operation per state, so no structural hazard.

```
Memory layout (256KB = 0x40000 bytes):
0x80000000 ┌──────────────┐
           │   Code       │  ← PC starts here
           │   (.text)    │
           ├──────────────┤
           │   Data       │
           │   (.data)    │
           ├──────────────┤
           │   .tohost    │  ← ISA test pass/fail signal
           ├──────────────┤
           │              │
           │   (free)     │
           │              │
           ├──────────────┤
           │   Stack      │  ← SP = 0x8003FFF8, grows down
0x8003FFFF └──────────────┘  ← last valid byte (BASE + SIZE - 1)
```

### FSM States

```
FETCH → DECODE → EXECUTE ──┬──→ MEMORY → WRITEBACK → FETCH
                            ├──→ WRITEBACK → FETCH         (no mem access)
                            ├──→ FP_EXEC ─(loop)─→ WRITEBACK → FETCH
                            └──→ MULDIV_EXEC ─(loop)─→ WRITEBACK → FETCH
```

| State | Encoding | Action |
|-------|----------|--------|
| FETCH | 3'b000 | Read memory at PC, latch into IR |
| DECODE | 3'b001 | Decode IR, read registers, compute immediate + branch target |
| EXECUTE | 3'b010 | ALU/branch/address computation. Branch module evaluates condition. |
| MEMORY | 3'b011 | Load/store data memory access. AMO: 2-cycle read-then-write sequence. |
| WRITEBACK | 3'b100 | Write result to register file, update PC |
| FP_EXEC | 3'b101 | Multi-cycle FPU (div/sqrt), loop until fpu_done |
| MULDIV_EXEC | 3'b110 | Multi-cycle mul/div, loop until muldiv_done |

### Module Breakdown

| Module | Description | Est. Lines |
|--------|-------------|-----------|
| `top.v` | Top-level wiring + MUXes | ~80 |
| `pc.v` | 64-bit program counter | ~50 |
| `ir.v` | 32-bit instruction register latch | ~20 |
| `mem.v` | Unified memory (code+data, byte/half/word/double, sign/zero extend, $readmemh) | ~80 |
| `decoder.v` | Opcode/funct decode + immediate generation | ~350 |
| `control.v` | FSM state machine + all control signals | ~250 |
| `regfile.v` | Integer register file (32×64, x0=0) | ~50 |
| `fp_regfile.v` | FP register file (32×64, NaN-boxing, 3 read ports) | ~50 |
| `alu.v` | 64-bit ALU + W-variant support | ~180 |
| `muldiv.v` | Iterative 64-bit multiply/divide | ~300 |
| `fpu.v` | IEEE 754 FPU (F+D, all ops, 5 rounding modes) | ~1,100 |
| `branch.v` | Branch condition evaluation | ~60 |
| `amo.v` | Atomic read-modify-write | ~150 |
| `csr.v` | FP CSRs (fcsr/frm/fflags) + CSR instructions | ~80 |
| **Total RTL** | | **~2,800** |

### Internal Latches (between FSM states)

| Register | Width | Loaded in | Used in | Content |
|----------|-------|-----------|---------|---------|
| IR | 32 | FETCH | DECODE+ | Current instruction |
| A | 64 | DECODE | EXECUTE | rs1 data |
| B | 64 | DECODE | EXECUTE | rs2 data |
| C | 64 | DECODE | EXECUTE | rs3 data (FMADD) |
| IMM | 64 | DECODE | EXECUTE | Sign-extended immediate |
| ALU_OUT | 64 | EXECUTE | MEMORY/WB | ALU result / computed address |
| MEM_DATA | 64 | MEMORY | WRITEBACK | Loaded data from memory |
| BRANCH_TARGET | 64 | DECODE | EXECUTE | PC + immediate |

### Datapath MUXes (in top.v)

| MUX | Select Signal | Options |
|-----|---------------|---------|
| ALU input A | `alu_src_a` | 00=rs1, 01=pc, 10=zero |
| ALU input B | `alu_src_b` | 0=rs2, 1=imm |
| Writeback data | `wb_src` | 000=alu, 001=mem, 010=fpu, 011=pc+4, 100=csr, 101=muldiv |
| Next PC | `pc_src` | 00=pc+4, 01=branch_target, 10=alu_result(jalr) |

---

## Toolchain (all free)

| Tool | Purpose | Source |
|------|---------|--------|
| riscv64-unknown-elf-gcc | C cross-compiler | riscv-gnu-toolchain |
| iverilog / vvp | Verilog simulation | Icarus Verilog |
| yosys | Synthesis + schematic generation | YosysHQ/yosys |
| netlistsvg | SVG schematic renderer | nturley/netlistsvg |
| spike | Reference ISA simulator | riscv-software-src/riscv-isa-sim |
| sail_riscv_sim | Reference model for arch-test | riscv/sail-riscv (binary release) |
| mise | Tool version manager (for arch-test) | mise.jdx.dev |
| GTKWave | Waveform viewer (debugging) | gtkwave.sourceforge.net |
| make | Build system | system |

### Schematic Generation (from Verilog source)

The architecture diagram in the README is always generated from the actual Verilog:

```makefile
schematic: rtl/*.v
    yosys -p "read_verilog rtl/*.v; prep -top top; write_json build/top.json"
    netlistsvg build/top.json -o docs/architecture.svg
```

No hand-drawn diagrams. The image is always a true representation of the current source.

---

## Verification Strategy (correctness first, always)

Functional correctness is verified before anything else. A number from a buggy core is meaningless.

### Verification Flow (strict order)

```
1. Module unit tests (tb/*.v)
         │ all pass
         ▼
2. riscv-tests ISA suite (rv64ui, rv64um, rv64ua, rv64uf, rv64ud)
         │ all pass
         ▼
3. riscv-arch-test compliance
         │ all pass
         ▼
4. C program integration tests
         │ all pass
         ▼
   Processor is correct
```

**Any failure at any level = stop and fix before proceeding.**

### Level 1: Module Unit Tests

Each module gets a testbench in `tb/tb_<module>.v`:
- ALU: every operation, 64-bit edge cases, W-instruction sign extension
- Register file: read/write all registers, x0 hardwired zero
- FP register file: NaN-boxing, 3-port reads
- Decoder: all instruction formats (R/I/S/B/U/J/R4)
- FPU: rounding modes, NaN/Inf/denormal/zero, all operations
- Branch: all 6 conditions, signed vs unsigned
- Muldiv: overflow, divide-by-zero, INT64_MIN/-1
- Mem: byte/half/word/double access, sign/zero extension, out-of-bounds detection

### Level 2: ISA Compliance Tests

Source: `test/riscv-tests` (git submodule → github.com/riscv-software-src/riscv-tests)

Test groups:
- `rv64ui` — base integer
- `rv64um` — multiply/divide
- `rv64ua` — atomics
- `rv64uf` — single-precision float
- `rv64ud` — double-precision float

Each test is compiled individually from the riscv-tests source tree:
```bash
# Compile one ISA test (e.g., rv64ui-p-add):
riscv64-unknown-elf-gcc -march=rv64imafd -mabi=lp64d -nostdlib -nostartfiles \
  -I test/riscv-tests/env/p -I test/riscv-tests/isa/macros/scalar \
  -T test/riscv-tests/env/p/link.ld \
  -o build/rv64ui-p-add.elf test/riscv-tests/isa/rv64ui/add.S

# Convert to hex (subtract base address for array indexing):
riscv64-unknown-elf-objcopy -O verilog --change-addresses=-0x80000000 \
  build/rv64ui-p-add.elf build/rv64ui-p-add.hex

# Extract tohost address (subtract base for array offset):
TOHOST_ABS=$(riscv64-unknown-elf-nm build/rv64ui-p-add.elf | grep ' tohost' | awk '{print $1}')
TOHOST=$((16#$TOHOST_ABS - 16#80000000))

# Simulate (TOHOST_ADDR is a decimal integer, valid in Verilog defines):
iverilog -o build/sim.vvp -I rtl rtl/*.v tb/tb_isa_test.v \
  -DTEST_HEX=\"build/rv64ui-p-add.hex\" -DTOHOST_ADDR=$TOHOST
vvp build/sim.vvp
```

The riscv-tests use their own linker script (`env/p/link.ld`) and macros. We do NOT use our
`tools/linker.ld` or `tools/crt0.s` for ISA tests — those are only for our C programs.

Pass/fail mechanism:
- Test writes to `tohost` memory location (defined by the test's linker script)
- Testbench watches this address: value 1 = pass, other = fail (test_num = value >> 1)

### Level 3: Architecture Compliance Tests

Source: `test/riscv-arch-test` (git submodule → github.com/riscv-non-isa/riscv-arch-test, main branch)

Uses the ACT4 framework. Stricter than riscv-tests: generates self-checking ELFs that embed
expected architectural state (computed by the Sail reference model). Each test compares register/memory
values against expectations at runtime and reports pass/fail directly.

Covers: I, M, F, D, Zaamo (AMO ops), Zalrsc (LR/SC), Zicsr, Zifencei.

**Additional toolchain dependencies (beyond Level 2):**
- `mise` (tool version manager) — manages Python/Ruby tooling
- `sail_riscv_sim` v0.10+ (Sail reference model) — computes golden signatures

**How ACT4 works:**

The framework generates test assembly, compiles it, runs on the Sail model to capture expected results,
then re-compiles into self-checking ELFs that assert correctness internally.

We provide a DUT configuration in `test/arch-test-config/` (in our repo, not inside the submodule):

```
test/arch-test-config/
├── test_config.yaml      # Framework config (paths to compiler, Sail, UDB, linker script)
├── rv64g-mc.yaml         # UDB config (supported extensions and parameters)
├── rvmodel_macros.h      # DUT-specific asm macros (halt, I/O stubs)
├── link.ld               # Linker script (entry=rvtest_entry_point, .text.init/.text.rvtest/.data/.text.rvmodel)
├── sail.json             # Sail model memory map config
├── rvtest_config.svh     # SV header (extension defines)
└── rvtest_config.h       # C header (extension defines)
```

**rvmodel_macros.h** defines:
- `RVMODEL_HALT_PASS`: trigger ECALL (testbench detects halt, checks a0=0)
- `RVMODEL_HALT_FAIL`: trigger ECALL with a0≠0
- `RVMODEL_IO_*`: NOP (no console I/O in our target)
- `RVMODEL_BOOT`: NOP (no special boot sequence)

**test_config.yaml** contents:
```yaml
name: rv64g-mc
compiler_exe: riscv64-unknown-elf-gcc
objdump_exe: riscv64-unknown-elf-objdump
ref_model_exe: sail_riscv_sim
udb_config: rv64g-mc.yaml
linker_script: link.ld
dut_include_dir: .
include_priv_tests: false
```

**Build and run sequence:**
```bash
# Install Sail reference model (one-time):
curl --location https://github.com/riscv/sail-riscv/releases/download/0.10/sail-riscv-$(uname)-$(arch).tar.gz \
  | tar xvz --directory=$HOME/.local --strip-components=1

# From repo root, generate self-checking ELFs:
cd test/riscv-arch-test
mise trust .mise.toml
CONFIG_FILES=../../test/arch-test-config/test_config.yaml make --jobs $(nproc)
# Output: work/rv64g-mc/elfs/*.elf
```

**Running generated ELFs on our RTL:**
Each self-checking ELF is treated like a C integration test:
1. Convert: `riscv64-unknown-elf-objcopy -O verilog --change-addresses=-0x80000000 test.elf test.hex`
2. Simulate: `iverilog -o build/sim.vvp -I rtl rtl/*.v tb/tb_arch_test.v -DTEST_HEX=\"test.hex\" && vvp build/sim.vvp`
3. Testbench halts on ECALL, checks pass/fail via halt mechanism
4. The ELF itself prints PASS/FAIL internally; testbench reports based on halt status

**Pass/fail:** The ELF asserts correctness internally. If all checks pass, it calls
`RVMODEL_HALT_PASS` (ECALL with a0=0). If any check fails, it calls `RVMODEL_HALT_FAIL` (a0≠0).
Our `tb/tb_arch_test.v` detects halt and checks a0, same as `tb_c_test.v`.

### Level 4: C Integration Tests

Our own C programs in `test/c/`. Each is self-contained, compiled bare-metal:
1. Compiled: `riscv64-unknown-elf-gcc -march=rv64imafd -mabi=lp64d -nostdlib -nostartfiles -T tools/linker.ld tools/crt0.s test.c`
2. Converted to hex: `riscv64-unknown-elf-objcopy -O verilog --change-addresses=-0x80000000`
   The `--change-addresses` strips the base address so hex file addresses start at 0,
   matching the `mem[0:SIZE-1]` array indexing in `mem.v`. Without this, `$readmemh` would
   try to write at index 0x80000000 (out of range for a 256KB array).
3. Loaded into sim via `$readmemh`, run until ECALL
4. Return value in a0 (x10): 0 = pass

Example C tests:
- Integer: factorial, fibonacci, bubble sort, linked list, bitwise ops
- Float: matrix multiply, Newton-Raphson sqrt, polynomial eval
- Double: ray tracer, FFT, numeric integration
- Mixed: struct packing, union type punning, varargs

### Halt / Completion Mechanism

Three mechanisms:

1. **tohost** (for ISA tests): A memory address defined as a symbol in the linker script (`.tohost` section). The testbench watches this address every cycle. When the test program writes to it:
   - Value `1` = all test cases in the binary passed
   - Any other value = failure (encodes which test case: `test_num = value >> 1`)
   
   The testbench implements: `always @(posedge clk) if (mem[TOHOST_ADDR] != 0) check_result();`
   
   The TOHOST_ADDR is exported from the compiled ELF symbol table so the testbench knows where to watch.

2. **ECALL** (for C programs): triggers halt signal. crt0.s calls main(), then executes ECALL with return value in a0 (x10). Testbench checks: a0 == 0 means pass.

3. **Out-of-bounds memory access**: testbench detects any address >= MEM_SIZE and reports FAIL immediately.

### C Test Correctness

A C test passes when:
- It does NOT access out-of-bounds memory
- It halts (doesn't infinite loop)
- main() returns 0
- The program's computed results are correct (e.g., `factorial(5) == 120`)

Each C test is self-checking: it computes a result, compares against the known-correct answer, and returns 0 if correct or non-zero if wrong.

---

## Test Infrastructure

### Git Submodules (not our code, not checked in)

```
test/riscv-tests     → github.com/riscv-software-src/riscv-tests
test/riscv-arch-test → github.com/riscv-non-isa/riscv-arch-test
```

Fetch with: `git submodule update --init --recursive`

### run_tests.sh

Single script that runs all tests in order:

```
./run_tests.sh
```

Flow:
1. Compile and run all module unit tests (tb/*.v)
2. Compile and run all ISA tests (rv64ui, rv64um, rv64ua, rv64uf, rv64ud)
3. Compile and run riscv-arch-test compliance tests
4. Compile and run all C integration tests (test/c/*.c)
5. Print summary: PASS/FAIL counts
6. Exit 0 if all pass, exit 1 if any fail

Each test:
- Compiled with iverilog
- Run with vvp
- Checks stdout for PASS/FAIL
- Times out after 30s (ISA) or 60s (C programs)
- Reports which specific test case failed

### Makefile Targets

```makefile
make test           # run_tests.sh (everything in order: unit → ISA → arch → C)
make test_unit      # module unit tests only
make test_isa       # riscv-tests ISA compliance only
make test_arch      # riscv-arch-test compliance only
make test_c         # C integration only
make sim SRC=x.c   # compile + simulate one C program
make schematic      # generate architecture SVG from Verilog
make clean          # remove build artifacts
```

### ISA Test Testbench (tb/tb_isa_test.v)

Generic testbench for running any ISA test binary:
- Loads hex from compile-time parameter
- Instantiates top module
- Watches `tohost` memory location every cycle
- On write to tohost: if value==1 → PASS, else FAIL (test case = value>>1)
- Times out after N cycles → FAIL (infinite loop)

### Arch Test Testbench (tb/tb_arch_test.v)

Generic testbench for running riscv-arch-test self-checking ELFs:
- Loads hex from compile-time parameter
- Instantiates top module
- Watches for halt signal (ECALL)
- On halt: reads x10 (a0 register) → 0 means PASS (all checks passed)
- Times out → FAIL
- Functionally identical to tb_c_test.v (kept separate for clarity in test output)

### C Test Testbench (tb/tb_c_test.v)

Generic testbench for running compiled C programs:
- Loads hex from compile-time parameter
- Instantiates top module
- Watches for ECALL instruction (halt signal)
- On halt: reads x10 (a0 register) → 0 means PASS
- Times out → FAIL

---

## Build System (Makefile)

```makefile
# === Tools ===
RISCV_GCC      = riscv64-unknown-elf-gcc
RISCV_OBJCOPY  = riscv64-unknown-elf-objcopy
IVERILOG       = iverilog
VVP            = vvp
YOSYS          = yosys

# === Flags ===
MARCH          = rv64imafd
MABI           = lp64d
CFLAGS         = -march=$(MARCH) -mabi=$(MABI) -nostdlib -nostartfiles -T tools/linker.ld

# === Compile C → hex ===
# 1. gcc → .elf
# 2. objcopy → .hex (verilog format for $readmemh)

# === Simulate ===
# iverilog -o build/sim.vvp -I rtl rtl/*.v tb/tb_isa_test.v -DTEST_HEX="..." -DTOHOST_ADDR=...
# iverilog -o build/sim.vvp -I rtl rtl/*.v tb/tb_c_test.v -DTEST_HEX="..."
# vvp build/sim.vvp

# === Schematic ===
# yosys: read_verilog → prep → write_json
# netlistsvg: json → svg
```

---

## File Structure

```
RISC-V/
├── PROJECT_PLAN.md              # This file (single source of truth)
├── README.md                    # Overview + generated architecture image
├── Makefile                     # Build, sim, test, schematic
├── run_tests.sh                 # Runs all tests in order
├── rtl/                         # Verilog source (~2,800 lines)
│   ├── top.v
│   ├── pc.v
│   ├── ir.v
│   ├── mem.v
│   ├── decoder.v
│   ├── control.v
│   ├── regfile.v
│   ├── fp_regfile.v
│   ├── alu.v
│   ├── muldiv.v
│   ├── fpu.v
│   ├── branch.v
│   ├── amo.v
│   └── csr.v
├── tb/                          # Testbenches
│   ├── tb_alu.v
│   ├── tb_regfile.v
│   ├── tb_fp_regfile.v
│   ├── tb_decoder.v
│   ├── tb_fpu.v
│   ├── tb_muldiv.v
│   ├── tb_branch.v
│   ├── tb_mem.v
│   ├── tb_isa_test.v           # Generic harness for ISA tests
│   ├── tb_arch_test.v          # Generic harness for arch-test ELFs
│   └── tb_c_test.v             # Generic harness for C programs
├── test/
│   ├── riscv-tests/            # Git submodule (official ISA tests)
│   ├── riscv-arch-test/        # Git submodule (ACT4 compliance framework)
│   ├── arch-test-config/       # Our DUT config for riscv-arch-test
│   └── c/                      # Our C integration tests (self-checking, return 0 = pass)
│       ├── factorial.c
│       ├── fibonacci.c
│       ├── float_math.c
│       ├── sorting.c
│       └── ...
├── tools/
│   ├── linker.ld               # Bare-metal linker script (for C tests only)
│   └── crt0.s                  # Startup (for C tests only)
```

#### tools/linker.ld contents:
```ld
ENTRY(_start)
SECTIONS {
    . = 0x80000000;
    .text : { *(.text .text.*) }
    .rodata : { *(.rodata .rodata.*) }
    .data : { *(.data .data.*) }
    .bss : {
        __bss_start = .;
        *(.bss .bss.* COMMON)
        __bss_end = .;
    }
    .tohost : { *(.tohost) }
    _stack_top = 0x80000000 + 0x40000 - 8;
}
```

#### tools/crt0.s contents:
```asm
.section .text
.globl _start
_start:
    la sp, _stack_top       # set stack pointer
    # zero BSS
    la t0, __bss_start
    la t1, __bss_end
1:  bge t0, t1, 2f
    sd zero, 0(t0)
    addi t0, t0, 8
    j 1b
2:  call main               # call C main()
    # a0 holds return value (0 = pass)
    ecall                   # halt — testbench reads a0
```

#### Bootstrap test (Step 3 first-light):
Before ISA tests are available, use a hand-written hex file to test basic execution:
```
// build/bootstrap.hex — ADDI x1, x0, 42 then ECALL
// Address 0x00000000 (array offset for 0x80000000):
@00000000
93 00 A0 02  // ADDI x1, x0, 42  (0x02A00093)
73 00 00 00  // ECALL             (0x00000073)
```
This tests: instruction fetch, decode, ADDI execution, halt detection.

```
├── docs/
│   ├── ARCHITECTURE.md         # Module ports, FSM, control signals
│   ├── SPEC.md                 # Full instruction behavioral spec
│   └── architecture.svg        # Generated from Verilog source by `make schematic`
├── build/                       # Build artifacts (gitignored)
├── riscv-unprivileged.pdf      # RISC-V spec reference
└── riscv-privileged.pdf        # RISC-V privileged spec reference
```

---

## Implementation Order

### Step 1: Skeleton + Infrastructure
- [ ] Makefile with all targets
- [ ] run_tests.sh
- [ ] tools/linker.ld and tools/crt0.s
- [ ] tb/tb_isa_test.v (generic ISA test harness)
- [ ] tb/tb_arch_test.v (generic arch-test harness)
- [ ] tb/tb_c_test.v (generic C test harness)
- [ ] rtl/ stub files (module declarations, empty bodies)

### Step 2: Integer Datapath
- [ ] pc.v, ir.v, mem.v (unified memory)
- [ ] regfile.v (32×64, x0=0)
- [ ] decoder.v (all formats, immediate gen)
- [ ] alu.v (all integer ops + W variants)
- [ ] branch.v
- [ ] Unit test each module

### Step 3: Control FSM + Wiring
- [ ] control.v (full FSM)
- [ ] top.v (wire everything, all MUXes)
- [ ] csr.v (CSR read/write mechanism — stub registers, reads return 0 for unimplemented)
- [ ] Get ADDI executing end-to-end
- [ ] Get all RV64I instructions working (including CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI, FENCE=NOP)
- [ ] Run rv64ui ISA tests → all pass

### Step 4: Multiply/Divide
- [ ] muldiv.v (iterative, multi-cycle, stall signal)
- [ ] Integrate stall into control FSM
- [ ] Run rv64um ISA tests → all pass

### Step 5: Floating Point
- [ ] fp_regfile.v (NaN-boxing, 3 read ports)
- [ ] Add FP CSR registers to csr.v (fcsr/frm/fflags — mechanism already exists from Step 3)
- [ ] fpu.v: FADD/FSUB (align, add, normalize, round)
- [ ] fpu.v: FMUL (mantissa multiply, normalize, round)
- [ ] fpu.v: FDIV/FSQRT (iterative, multi-cycle)
- [ ] fpu.v: FMADD/FMSUB/FNMADD/FNMSUB (single rounding)
- [ ] fpu.v: conversions (int↔float, single↔double)
- [ ] fpu.v: compare, classify, sign-inject, min/max, move
- [ ] Both single (.S) and double (.D) for all ops
- [ ] Run rv64uf ISA tests → all pass
- [ ] Run rv64ud ISA tests → all pass

### Step 6: Atomics
- [ ] amo.v (combinational compute, FSM handles sequencing)
- [ ] LR/SC (reservation register — SC fails if addr mismatch or no prior LR)
- [ ] Run rv64ua ISA tests → all pass

### Step 7: C Integration
- [ ] Compile and run integer C programs
- [ ] Compile and run float/double C programs
- [ ] All C tests pass
- [ ] Full `run_tests.sh` passes clean

---

## Success Criteria

1. All 156 RV64IMAFD instructions pass riscv-tests ISA suite
2. riscv-arch-test compliance passes for rv64imafd
3. Compiled C programs produce correct results (self-checking, return 0)
4. Processor RTL is under 3,000 lines of Verilog
5. `run_tests.sh` passes with zero failures
6. FPU produces bit-exact IEEE 754 results across all rounding modes
7. `make schematic` generates architecture diagram from Verilog source
8. Can compile arbitrary C code (no OS calls) and run it correctly
