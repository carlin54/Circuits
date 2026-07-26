# Chaotic Attractors

Analog circuit implementations of chaotic attractors, simulated with ngspice and validated against scipy ODE reference solutions.

Each attractor is implemented as an op-amp circuit (using analog multipliers and integrators) that reproduces the system's characteristic phase-space trajectory.

## Available Attractors

| Attractor | Schematic | Reference |
|-----------|-----------|-----------|
| Lorenz | ![](output/lorenz_schematic.png) | ![](output/lorenz_reference.png) |
| Chua | ![](output/chua_schematic.png) | ![](output/chua_reference.png) |
| Rossler | ![](output/rossler_schematic.png) | ![](output/rossler_reference.png) |
| Chen | ![](output/chen_schematic.png) | ![](output/chen_reference.png) |
| Dadras | ![](output/dadras_schematic.png) | ![](output/dadras_reference.png) |
| Halvorsen | ![](output/halvorsen_schematic.png) | ![](output/halvorsen_reference.png) |
| Aizawa | ![](output/aizawa_schematic.png) | ![](output/aizawa_reference.png) |
| Sprott-A | ![](output/sprott_a_schematic.png) | ![](output/sprott_a_reference.png) |
| Thomas | ![](output/thomas_schematic.png) | ![](output/thomas_reference.png) |
| Lu | ![](output/lu_schematic.png) | ![](output/lu_reference.png) |

## Usage

```bash
python main.py --list              # List available circuits
python main.py lorenz              # Simulate the Lorenz attractor
python main.py --all               # Run all attractors
```

## Architecture

- `circuits/` — Attractor definitions (netlist generation per attractor)
- `src/simulate.py` — ngspice simulation runner
- `src/ode_reference.py` — scipy ODE solver for validation
- `src/plot.py` — Phase-space plotting
- `src/schematic.py` — Circuit schematic generation (schemdraw)
- `models/` — SPICE component models (AD633, TL072, LT1057)
- `tests/` — pytest test suite

## Dependencies

Python >=3.11, ngspice, numpy, scipy, matplotlib, schemdraw
