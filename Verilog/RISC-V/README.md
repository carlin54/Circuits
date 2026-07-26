# RV64G Processor

A minimal multi-cycle RV64G (RV64IMAFD) processor in Verilog.
Executes any compiled C code (including floating-point) on bare metal.

## Architecture

Architecture diagram can be generated with `make schematic` (requires yosys + netlistsvg).

## Quick Start

```bash
# Compile and simulate a C program
make sim SRC=test/c/factorial.c

# Run all tests in order (unit → ISA → arch → C)
make test

# Regenerate architecture diagram from source
make schematic
```

## Toolchain Requirements

All free/open-source:

| Tool | Purpose | Install |
|------|---------|---------|
| `riscv64-unknown-elf-gcc` | C cross-compiler | [riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) |
| `iverilog` | Verilog simulation | [Icarus Verilog](http://iverilog.icarus.com/) |
| `vvp` | Simulation runtime | (included with iverilog) |
| `yosys` | Synthesis + schematic gen | [Yosys](https://github.com/YosysHQ/yosys) |
| `netlistsvg` | SVG schematic renderer | `npm install -g netlistsvg` |
| `spike` | Reference ISA simulator | [riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim) |
| `sail_riscv_sim` | Reference model (arch-test) | [sail-riscv](https://github.com/riscv/sail-riscv/releases) |
| `mise` | Tool version manager (arch-test) | [mise](https://mise.jdx.dev) |
| `make` | Build system | (system default) |

## Design

- **ISA**: RV64IMAFD (156 instructions) — no compressed (C) extension
- **Microarchitecture**: Multi-cycle FSM (FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK)
- **FPU**: Hand-coded IEEE 754, single + double precision, all 5 rounding modes
- **Memory**: Unified (code + data), configurable size (default 256KB), base address `0x80000000`
- **No cache, no pipeline, no virtual memory, no OS**

## Project Structure

```
rtl/            Verilog source (~2800 lines)
tb/             Module testbenches
test/
  riscv-tests/  Git submodule (official ISA tests)
  riscv-arch-test/  Git submodule (ACT4 compliance framework)
  arch-test-config/ Our DUT config for riscv-arch-test
  c/            C integration tests
tools/          Linker script, startup code
docs/           Spec, architecture doc, generated diagrams
Makefile        Build, simulate, test, generate schematic
run_tests.sh    Runs all tests in order, stops on failure
```

## Testing (correctness first, always)

Functional correctness is verified before anything else. A performance number from a buggy core is worthless.

### Level 1: Module Unit Tests
Each RTL module has its own testbench in `tb/`. Tests run in isolation.

```bash
make test_unit       # Run all module unit tests
```

### Level 2: ISA Compliance (riscv-tests)
The official riscv-tests suite runs against the RTL in simulation.

```bash
make test_isa        # Run riscv-tests suite (rv64ui, rv64um, rv64ua, rv64uf, rv64ud)
```

Each ISA test writes pass/fail to the `tohost` memory location.
Testbench checks: tohost == 1 (pass), else reports which test case failed.

**Any ISA test failure = stop and fix before proceeding.**

### Level 3: Architecture Compliance (riscv-arch-test)
Stricter than riscv-tests. Self-checking ELFs verify full architectural state against Sail model.

```bash
make test_arch       # Run riscv-arch-test compliance suite
```

### Level 4: C Integration Tests
Only after all ISA and arch tests pass. Compile C programs, run on processor, verify output.

```bash
make test_c          # Run all C integration tests
```

Each test in `test/c/` is a self-contained C file that:
1. Gets compiled with `riscv64-unknown-elf-gcc`
2. Loads into memory
3. Runs on the simulated processor
4. Exits via ECALL with return value in register a0
5. Testbench checks a0 against expected value (0 = pass)

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — Module ports, FSM states, control signals, wiring
- [Instruction Spec](docs/SPEC.md) — Complete behavioral spec for all 156 instructions
- [Project Plan](PROJECT_PLAN.md) — Implementation roadmap

## Make Targets

| Target | Description |
|--------|-------------|
| `make sim SRC=file.c` | Compile + simulate one C program |
| `make test` | Run ALL tests in order (unit → ISA → arch → C) |
| `make test_unit` | Module unit tests only |
| `make test_isa` | riscv-tests ISA compliance only |
| `make test_arch` | riscv-arch-test compliance only |
| `make test_c` | C integration tests only |
| `make schematic` | Generate architecture SVG from Verilog source |
| `make clean` | Remove build artifacts |

## Verification Flow

```
Module unit tests (tb/*.v)
         │ all pass
         ▼
riscv-tests ISA suite (rv64ui/um/ua/uf/ud)
         │ all pass
         ▼
riscv-arch-test compliance
         │ all pass
         ▼
C program integration tests
         │ all pass
         ▼
Processor is correct
```
