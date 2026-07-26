import struct
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np


@dataclass
class SimulationResult:
    time: np.ndarray
    variables: dict[str, np.ndarray]
    success: bool
    stderr: str


def run_ngspice(netlist: str, timeout: float = 120.0) -> SimulationResult:
    with tempfile.TemporaryDirectory() as tmpdir:
        netlist_path = Path(tmpdir) / "circuit.cir"
        raw_path = Path(tmpdir) / "output.raw"

        netlist_path.write_text(netlist)

        result = subprocess.run(
            ["ngspice", "-b", "-r", str(raw_path), str(netlist_path)],
            capture_output=True,
            text=True,
            timeout=timeout,
        )

        if not raw_path.exists():
            return SimulationResult(
                time=np.array([]),
                variables={},
                success=False,
                stderr=result.stderr,
            )

        return parse_raw_file(raw_path, result.stderr)


def parse_raw_file(path: Path, stderr: str = "") -> SimulationResult:
    with open(path, "rb") as f:
        content = f.read()

    header_end = content.find(b"Binary:\n")
    if header_end == -1:
        return SimulationResult(
            time=np.array([]),
            variables={},
            success=False,
            stderr=stderr + "\nNo binary data found in raw file",
        )

    header = content[:header_end].decode("utf-8", errors="replace")
    binary_data = content[header_end + len(b"Binary:\n"):]

    num_vars = 0
    num_points = 0
    var_names = []
    is_complex = False
    in_variables = False

    for line in header.split("\n"):
        line = line.strip()
        if line.startswith("No. Variables:"):
            num_vars = int(line.split(":")[1].strip())
        elif line.startswith("No. Points:"):
            num_points = int(line.split(":")[1].strip())
        elif line.startswith("Flags:"):
            is_complex = "complex" in line.lower()
        elif line == "Variables:":
            in_variables = True
        elif in_variables and line and line[0].isdigit():
            parts = line.split()
            if len(parts) >= 2:
                var_names.append(parts[1])
        elif in_variables and not line:
            in_variables = False

    if is_complex:
        bytes_per_point = num_vars * 16
    else:
        bytes_per_point = num_vars * 8

    expected_bytes = num_points * bytes_per_point
    actual_bytes = len(binary_data)

    if actual_bytes < expected_bytes:
        num_points = actual_bytes // bytes_per_point

    if num_points == 0 or num_vars == 0:
        return SimulationResult(
            time=np.array([]),
            variables={},
            success=False,
            stderr=stderr + "\nNo data points parsed",
        )

    if is_complex:
        data = np.frombuffer(
            binary_data[: num_points * bytes_per_point], dtype=np.float64
        ).reshape(num_points, num_vars * 2)
        data = data[:, ::2]
    else:
        data = np.frombuffer(
            binary_data[: num_points * bytes_per_point], dtype=np.float64
        ).reshape(num_points, num_vars)

    variables = {}
    time_arr = None
    for i, name in enumerate(var_names):
        if name.lower() == "time" or name.lower() == "v(time)":
            time_arr = data[:, i]
        else:
            variables[name] = data[:, i]

    if time_arr is None:
        time_arr = data[:, 0]
        variables = {name: data[:, i] for i, name in enumerate(var_names) if i > 0}

    return SimulationResult(
        time=time_arr,
        variables=variables,
        success=True,
        stderr=stderr,
    )
