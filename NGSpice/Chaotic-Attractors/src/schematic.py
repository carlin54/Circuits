import re
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import schemdraw
import schemdraw.elements as elm

from circuits import get_circuit, load_all
from src.registry import ModelRegistry


def _parse_netlist(netlist: str):
    """Parse netlist into structured component data."""
    opamps = []
    resistors = []
    capacitors = []
    multipliers = []
    vsources = []
    bsources = []

    for line in netlist.split("\n"):
        line = line.strip()
        if not line or line.startswith("*") or line.startswith("."):
            continue
        parts = line.split()
        name = parts[0]

        if name.upper().startswith("XU"):
            # XU_ noninv inv vcc vee out MODEL
            opamps.append({
                "name": name, "noninv": parts[1], "inv": parts[2],
                "vcc": parts[3], "vee": parts[4], "out": parts[5],
                "model": parts[6],
            })
        elif name.upper().startswith("XM"):
            # XM_ x1 x2 y1 y2 z w vp vn MODEL
            multipliers.append({
                "name": name, "nodes": parts[1:-1], "model": parts[-1],
                "x1": parts[1], "y1": parts[3], "out": parts[6],
            })
        elif name[0].upper() == "R":
            resistors.append({"name": name, "n1": parts[1], "n2": parts[2], "value": parts[3]})
        elif name[0].upper() == "C":
            capacitors.append({"name": name, "n1": parts[1], "n2": parts[2], "value": parts[3]})
        elif name[0].upper() == "V" and name.upper() != "VCC" and name.upper() != "VEE":
            vsources.append({"name": name, "np": parts[1], "nn": parts[2], "value": " ".join(parts[3:])})
        elif name[0].upper() == "B":
            match = re.match(r'(\S+)\s+(\S+)\s+(\S+)\s+V\s*=\s*(.*)', line, re.IGNORECASE)
            if match:
                bsources.append({
                    "name": match.group(1), "out": match.group(2),
                    "expr": match.group(4),
                })

    return opamps, resistors, capacitors, multipliers, vsources, bsources


def _build_stages(opamps, resistors, capacitors):
    """Identify integrators and inverters from component lists."""
    # Build lookup: which cap/resistor connects to which inv node
    stages = []

    for op in opamps:
        inv_node = op["inv"]
        out_node = op["out"]

        # Find feedback cap (integrator) or feedback resistor (inverter)
        fb_cap = None
        for c in capacitors:
            if (c["n1"] == inv_node and c["n2"] == out_node) or \
               (c["n2"] == inv_node and c["n1"] == out_node):
                fb_cap = c
                break

        fb_r = None
        input_rs = []
        for r in resistors:
            connects_inv = (r["n1"] == inv_node or r["n2"] == inv_node)
            connects_out = (r["n1"] == out_node or r["n2"] == out_node)
            if connects_inv and connects_out:
                fb_r = r
            elif connects_inv:
                other = r["n1"] if r["n2"] == inv_node else r["n2"]
                input_rs.append({"name": r["name"], "value": r["value"], "signal": other})

        if fb_cap:
            stages.append({
                "type": "integrator",
                "opamp": op["name"],
                "model": op["model"],
                "output": out_node,
                "cap": fb_cap["value"],
                "inputs": input_rs,
            })
        elif fb_r:
            stages.append({
                "type": "inverter",
                "opamp": op["name"],
                "model": op["model"],
                "output": out_node,
                "fb_r": fb_r["value"],
                "inputs": input_rs,
            })

    return stages


def draw_schematic(name: str, output_path: Path):
    """Draw a fully-connected component-level circuit schematic."""
    registry = ModelRegistry()
    cls = get_circuit(name)
    circuit = cls()
    netlist = circuit.generate_netlist(registry)

    opamps, resistors, capacitors, multipliers, vsources, bsources = _parse_netlist(netlist)
    stages = _build_stages(opamps, resistors, capacitors)

    integrators = [s for s in stages if s["type"] == "integrator"]
    inverters = [s for s in stages if s["type"] == "inverter"]

    # Build net-to-source map (which component drives each net)
    net_source = {}
    for s in stages:
        net_source[s["output"]] = s
    for m in multipliers:
        net_source[m["out"]] = m
    for b in bsources:
        net_source[b["out"]] = b

    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Layout parameters
    integ_x = 0
    integ_spacing_y = 7.0
    inv_x = 12.0
    inv_spacing_y = 4.5
    mult_x = 12.0

    # Track placed component output positions for wire routing
    output_positions = {}  # net_name -> (x, y)
    input_positions = {}   # (stage_name, signal) -> (x, y)

    with schemdraw.Drawing(show=False, fontsize=9) as d:
        d.config(unit=2.5)

        # Title
        model_name = opamps[0]["model"] if opamps else "LT1057"
        d.add(elm.Label().at((6, 3.5)).label(circuit.DESCRIPTION, fontsize=13, loc='center'))
        d.add(elm.Label().at((6, 2.8)).label(
            f'Op-amps: {model_name} | Supply: ±15V | τ = 1ms',
            fontsize=8, loc='center'))

        # ===== Draw integrators =====
        for idx, integ in enumerate(integrators):
            y = -idx * integ_spacing_y
            op_cx = integ_x + 5.0

            op = d.add(elm.Opamp(leads=True).at((op_cx, y)).anchor('center'))

            # Ground non-inverting
            d.add(elm.Line().at(op.in2).left(0.4))
            d.add(elm.Ground())

            # Summing node
            sn_x = op.in1[0] - 0.2
            sn_y = op.in1[1]
            d.add(elm.Dot().at((sn_x, sn_y)))

            # Feedback cap
            d.add(elm.Line().at((sn_x, sn_y)).up(1.4))
            d.add(elm.Capacitor().right().tox(op.out).label(integ["cap"], fontsize=8, loc='top'))
            d.add(elm.Line().down().toy(op.out))
            d.add(elm.Dot())

            # Input resistors
            num_in = len(integ["inputs"])
            if num_in <= 3:
                offsets = {1: [0], 2: [0.6, -0.6], 3: [1.2, 0, -1.2]}[num_in]
            elif num_in == 4:
                offsets = [1.6, 0.55, -0.55, -1.6]
            else:
                step = 3.0 / (num_in - 1)
                offsets = [1.5 - i * step for i in range(num_in)]

            for i, inp in enumerate(integ["inputs"]):
                ry = sn_y + offsets[i]
                if abs(ry - sn_y) > 0.01:
                    d.add(elm.Line().at((sn_x, sn_y)).to((sn_x, ry)))
                    d.add(elm.Dot().at((sn_x, ry)))
                r_start_x = sn_x - 2.5
                d.add(elm.Resistor().at((r_start_x, ry)).right().to((sn_x, ry)).label(
                    inp["value"], loc='bot', fontsize=7))
                # Record input position for wire routing
                input_positions[(integ["opamp"], inp["signal"])] = (r_start_x, ry)

            # Output
            out_x = op.out[0] + 0.6
            d.add(elm.Line().at(op.out).right(0.6))
            d.add(elm.Dot().at((out_x, op.out[1])))
            output_positions[integ["output"]] = (out_x, op.out[1])

            # Labels
            d.add(elm.Label().at((out_x + 0.15, op.out[1])).label(
                integ["output"].upper(), loc='right', fontsize=10))
            d.add(elm.Label().at((op_cx, y - 1.8)).label(
                f'{integ["opamp"]} ({integ["model"]})', fontsize=7, loc='center'))

        # ===== Draw inverters =====
        for idx, inv in enumerate(inverters):
            y = -idx * inv_spacing_y
            op_cx = inv_x + 3.0

            op = d.add(elm.Opamp(leads=True).at((op_cx, y)).anchor('center'))

            # Ground non-inverting
            d.add(elm.Line().at(op.in2).left(0.4))
            d.add(elm.Ground())

            # Summing node
            sn_x = op.in1[0] - 0.2
            sn_y = op.in1[1]
            d.add(elm.Dot().at((sn_x, sn_y)))

            # Feedback resistor
            d.add(elm.Line().at((sn_x, sn_y)).up(1.1))
            d.add(elm.Resistor().right().tox(op.out).label(inv["fb_r"], fontsize=7, loc='top'))
            d.add(elm.Line().down().toy(op.out))
            d.add(elm.Dot())

            # Input resistor
            inp = inv["inputs"][0]
            r_start_x = sn_x - 2.0
            d.add(elm.Resistor().at((r_start_x, sn_y)).right().to((sn_x, sn_y)).label(
                inp["value"], loc='bot', fontsize=7))
            input_positions[(inv["opamp"], inp["signal"])] = (r_start_x, sn_y)

            # Output
            out_x = op.out[0] + 0.6
            d.add(elm.Line().at(op.out).right(0.6))
            d.add(elm.Dot().at((out_x, op.out[1])))
            output_positions[inv["output"]] = (out_x, op.out[1])

            d.add(elm.Label().at((out_x + 0.15, op.out[1])).label(
                inv["output"], loc='right', fontsize=9))
            d.add(elm.Label().at((op_cx, y - 1.4)).label(
                f'{inv["opamp"]} ({inv["model"]})', fontsize=7, loc='center'))

        # ===== Draw multipliers =====
        mult_y_start = -len(inverters) * inv_spacing_y - 2.0

        for idx, mult in enumerate(multipliers):
            my = mult_y_start - idx * 3.0
            mx = mult_x + 1.5

            ic = elm.Ic(
                pins=[
                    elm.IcPin(name='X1', side='left', slot='1/3'),
                    elm.IcPin(name='Y1', side='left', slot='2/3'),
                    elm.IcPin(name='W', side='right', slot='1/2'),
                ],
                size=(2.2, 1.8),
                label=f'{mult["name"]}\n({mult["model"]})',
                fontsize=7,
            )
            m = d.add(ic.at((mx, my)).anchor('center'))

            # Record multiplier pin positions for routing
            input_positions[(mult["name"], mult["x1"])] = (m.X1[0] - 0.5, m.X1[1])
            input_positions[(mult["name"], mult["y1"])] = (m.Y1[0] - 0.5, m.Y1[1])
            output_positions[mult["out"]] = (m.W[0] + 0.5, m.W[1])

            d.add(elm.Line().at(m.W).right(0.5))
            d.add(elm.Dot().at((m.W[0] + 0.5, m.W[1])))
            d.add(elm.Label().at((m.W[0] + 0.7, m.W[1])).label(
                mult["out"], loc='right', fontsize=8))

            d.add(elm.Line().at(m.X1).left(0.5))
            d.add(elm.Label().at((m.X1[0] - 0.7, m.X1[1])).label(
                mult["x1"], loc='left', fontsize=8))

            d.add(elm.Line().at(m.Y1).left(0.5))
            d.add(elm.Label().at((m.Y1[0] - 0.7, m.Y1[1])).label(
                mult["y1"], loc='left', fontsize=8))

        # ===== Draw behavioral sources =====
        if bsources:
            bs_y_start = mult_y_start - len(multipliers) * 3.0 - 2.0
            for idx, bs in enumerate(bsources):
                by = bs_y_start - idx * 2.0
                bx = integ_x + 1.0

                ic = elm.Ic(
                    pins=[
                        elm.IcPin(name='OUT', side='right', slot='1/2'),
                    ],
                    size=(3.5, 1.2),
                    label=f'{bs["name"]}',
                    fontsize=7,
                )
                b = d.add(ic.at((bx + 1.75, by)).anchor('center'))
                d.add(elm.Line().at(b.OUT).right(0.5))
                d.add(elm.Dot().at((b.OUT[0] + 0.5, b.OUT[1])))
                output_positions[bs["out"]] = (b.OUT[0] + 0.5, b.OUT[1])

                # Show expression below
                expr_short = bs["expr"][:55] + ("..." if len(bs["expr"]) > 55 else "")
                d.add(elm.Label().at((bx + 1.75, by - 1.0)).label(
                    expr_short, fontsize=6, loc='center'))

                d.add(elm.Label().at((b.OUT[0] + 0.7, b.OUT[1])).label(
                    bs["out"], loc='right', fontsize=8))

        # ===== Route wires connecting outputs to inputs =====
        # Use a vertical bus on the far LEFT and route outputs rightward to avoid
        # wires crossing through components.
        #
        # Strategy:
        # - Vertical bus channels on the far left (x < all components)
        # - From each output: go RIGHT then DOWN along the right edge,
        #   then across the BOTTOM to the vertical bus channel
        # - From bus channel: horizontal tap LEFT-to-RIGHT into each input
        #
        # Simplified: since inputs are already on the left side of integrators,
        # just use vertical bus channels far left that tap directly into inputs.
        # Outputs route: right, then down along right edge, then bottom corridor
        # to far left bus.

        connections_by_signal = {}
        for (stage_name, signal), (in_x, in_y) in input_positions.items():
            if signal in output_positions:
                if signal not in connections_by_signal:
                    connections_by_signal[signal] = []
                connections_by_signal[signal].append((in_x, in_y))

        if connections_by_signal:
            # Far-left vertical bus area (well clear of all components)
            all_input_xs = [ix for ix, _ in input_positions.values()]
            bus_x_start = min(all_input_xs) - 2.5
            bus_spacing = 0.5

            # Right edge for output drop-down routing
            all_output_xs = [ox for ox, _ in output_positions.values()]
            right_edge = max(all_output_xs) + 1.5

            # Bottom corridor y
            all_ys = [y for _, y in output_positions.values()] + \
                     [y for _, y in input_positions.values()]
            bottom_y = min(all_ys) - 2.5
            corridor_spacing = 0.6

            for ch_idx, (signal, sinks) in enumerate(connections_by_signal.items()):
                out_x, out_y = output_positions[signal]
                bus_x = bus_x_start - ch_idx * bus_spacing
                corridor_y = bottom_y - ch_idx * corridor_spacing

                # Route from output to bus:
                # output -> right to right_edge -> down to corridor -> left to bus_x -> up
                route_right_x = right_edge + ch_idx * 0.5

                # Output right to route column
                d.add(elm.Line().at((out_x, out_y)).to((route_right_x, out_y)))
                d.add(elm.Dot().at((out_x, out_y)))
                # Down to corridor
                d.add(elm.Line().at((route_right_x, out_y)).to((route_right_x, corridor_y)))
                # Left across corridor to bus column
                d.add(elm.Line().at((route_right_x, corridor_y)).to((bus_x, corridor_y)))
                # Bus: vertical from corridor up to highest sink
                sink_ys = [sy for _, sy in sinks]
                bus_top = max(sink_ys) + 0.2
                d.add(elm.Line().at((bus_x, corridor_y)).to((bus_x, bus_top)))

                # Tap from bus to each input
                for (in_x, in_y) in sinks:
                    d.add(elm.Line().at((bus_x, in_y)).to((in_x, in_y)))
                    d.add(elm.Dot().at((bus_x, in_y)))

        # Save
        fig = d.draw().fig
        fig.patch.set_facecolor('white')
        fig.patch.set_alpha(1.0)
        fig.savefig(str(output_path), dpi=150, facecolor='white',
                    bbox_inches='tight', pad_inches=0.3)
        plt.close(fig)


def draw_all_schematics(output_dir: Path):
    results = {}
    all_circuits = load_all()
    for cls in all_circuits:
        name = cls.NAME
        out = output_dir / f"{name}_schematic.png"
        try:
            draw_schematic(name, out)
            results[name] = True
        except Exception as e:
            print(f"  ERROR drawing {name}: {e}")
            import traceback
            traceback.print_exc()
            results[name] = False
    return results


CIRCUIT_TOPOLOGIES = {name: True for name in [
    "chua", "lorenz", "rossler", "chen", "sprott_a",
    "halvorsen", "aizawa", "thomas", "dadras", "lu",
]}
