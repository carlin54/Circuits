import argparse
import sys
from pathlib import Path

from circuits import get_circuit, load_all
from src.registry import ModelRegistry
from src.simulate import run_ngspice
from src.ode_reference import solve_attractor, ATTRACTORS
from src.plot import plot_phase_space
from src.schematic import draw_schematic, draw_all_schematics, CIRCUIT_TOPOLOGIES


def list_circuits():
    all_circuits = load_all()
    print("Available circuits:")
    for cls in all_circuits:
        print(f"  {cls.NAME:12s} - {cls.DESCRIPTION}")


def run_circuit(name: str, output_dir: Path, compare: bool = True, skip_sim: bool = False):
    registry = ModelRegistry()
    cls = get_circuit(name)
    circuit = cls()

    print(f"Running: {circuit.DESCRIPTION}")

    if not skip_sim:
        netlist = circuit.generate_netlist(registry)
        print(f"  Simulating with ngspice...")
        result = run_ngspice(netlist)

        if not result.success:
            print(f"  Simulation FAILED:")
            print(f"    {result.stderr[-500:]}")
            return False

        x_var, y_var = circuit.get_plot_variables()
        sim_data = result.variables
        sim_data["time"] = result.time

        print(f"  Simulation OK: {len(result.time)} points, "
              f"{result.time[-1]*1000:.1f}ms simulated")
    else:
        sim_data = None

    ref_data = None
    if compare and name in ATTRACTORS:
        print(f"  Computing ODE reference...")
        ref_data = solve_attractor(name)
        ref_info = ATTRACTORS[name]
        ref_x_var, ref_y_var = ref_info["plot_axes"]
        print(f"  Reference OK: {len(ref_data['time'])} points")

    if sim_data is not None:
        x_var, y_var = circuit.get_plot_variables()
        output_path = output_dir / f"{name}_attractor.png"

        plot_ref = None
        if ref_data is not None:
            ref_info = ATTRACTORS[name]
            ref_x, ref_y = ref_info["plot_axes"]
            plot_ref = {x_var: ref_data[ref_x], y_var: ref_data[ref_y]}

        plot_phase_space(
            data=sim_data,
            x_var=x_var,
            y_var=y_var,
            title=circuit.DESCRIPTION,
            output_path=output_path,
            reference_data=plot_ref,
        )
        print(f"  Plot saved: {output_path}")

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Chaotic attractor analog circuit simulator"
    )
    parser.add_argument("command", choices=["list", "run", "run-all", "reference", "schematic"],
                        help="Command to execute")
    parser.add_argument("--circuit", "-c", help="Circuit name (for 'run')")
    parser.add_argument("--output", "-o", default="output",
                        help="Output directory (default: output)")
    parser.add_argument("--no-compare", action="store_true",
                        help="Skip ODE reference comparison")

    args = parser.parse_args()
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    if args.command == "list":
        list_circuits()

    elif args.command == "run":
        if not args.circuit:
            parser.error("--circuit required for 'run' command")
        success = run_circuit(args.circuit, output_dir, compare=not args.no_compare)
        sys.exit(0 if success else 1)

    elif args.command == "run-all":
        all_circuits = load_all()
        results = {}
        for cls in all_circuits:
            success = run_circuit(cls.NAME, output_dir, compare=not args.no_compare)
            results[cls.NAME] = success
        print("\n--- Summary ---")
        for name, ok in results.items():
            status = "OK" if ok else "FAIL"
            print(f"  {name:12s}: {status}")
        if not all(results.values()):
            sys.exit(1)

    elif args.command == "reference":
        if args.circuit:
            names = [args.circuit]
        else:
            names = list(ATTRACTORS.keys())
        for name in names:
            print(f"Solving ODE reference for {name}...")
            ref = solve_attractor(name)
            info = ATTRACTORS[name]
            x_var, y_var = info["plot_axes"]
            output_path = output_dir / f"{name}_reference.png"
            plot_phase_space(
                data={x_var: ref[x_var], y_var: ref[y_var]},
                x_var=x_var,
                y_var=y_var,
                title=f"{name} (ODE reference)",
                output_path=output_path,
            )
            print(f"  Saved: {output_path}")

    elif args.command == "schematic":
        if args.circuit:
            print(f"Drawing schematic for {args.circuit}...")
            out = output_dir / f"{args.circuit}_schematic.png"
            draw_schematic(args.circuit, out)
            print(f"  Saved: {out}")
        else:
            print("Drawing schematics for all circuits...")
            results = draw_all_schematics(output_dir)
            for name, ok in results.items():
                status = "OK" if ok else "FAIL"
                print(f"  {name:12s}: {status}")


if __name__ == "__main__":
    main()
