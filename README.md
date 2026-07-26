# Circuits

A collection of digital and analog circuit designs spanning processor architecture, DSP, and analog simulation.

## Highlights

- **RV64IMAFD Processor** — Multi-cycle RISC-V processor supporting 156 instructions, with a 4-level verification infrastructure (unit → ISA → architecture compliance → C integration)
- **DSP IP Library** — 12-block Verilog DSP library (FFT, FIR, IIR, CORDIC, NCO, decimator, interpolator) with a guitar amplifier FPGA application
- **Chaotic Attractor Circuits** — Analog circuit implementations of 10 chaotic attractors, validated against scipy ODE solvers

## Repository Structure

| Directory | Description |
|-----------|-------------|
| [Verilog/](Verilog/) | Verilog HDL projects — RISC-V processor, DSP library, GPS, MD5, and more |
| [SysVerilog/](SysVerilog/) | SystemVerilog design and verification — VeriRISC CPU with testbenches |
| [NGSpice/](NGSpice/) | ngspice-based analog circuit simulations |
| [LTSpice/](LTSpice/) | LTSpice analog circuit designs with equations and analysis |
| [Falstad/](Falstad/) | Falstad online simulator circuits |

## Technologies

Verilog, SystemVerilog, Python, ngspice, LTSpice, Icarus Verilog, cocotb, Yosys, Xilinx Vivado
