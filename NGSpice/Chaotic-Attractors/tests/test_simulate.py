import struct
import tempfile
from pathlib import Path

import numpy as np
import pytest

from src.simulate import parse_raw_file, SimulationResult


def _make_raw_file(tmpdir: Path, num_vars: int, num_points: int, var_names: list[str]) -> Path:
    header = f"""Title: test
Date: Mon Jan 01 00:00:00 2024
Plotname: Transient Analysis
Flags: real
No. Variables: {num_vars}
No. Points: {num_points}
Variables:
"""
    for i, name in enumerate(var_names):
        header += f"\t{i}\t{name}\tvoltage\n"
    header += "Binary:\n"

    data = np.random.randn(num_points, num_vars).astype(np.float64)
    data[:, 0] = np.linspace(0, 1, num_points)

    raw_path = tmpdir / "test.raw"
    with open(raw_path, "wb") as f:
        f.write(header.encode("utf-8"))
        f.write(data.tobytes())

    return raw_path, data


class TestParseRawFile:
    def test_parses_valid_file(self, tmp_path):
        var_names = ["time", "v(x)", "v(y)", "v(z)"]
        raw_path, expected_data = _make_raw_file(tmp_path, 4, 1000, var_names)
        result = parse_raw_file(raw_path)

        assert result.success
        assert len(result.time) == 1000
        assert "v(x)" in result.variables
        assert "v(y)" in result.variables
        assert "v(z)" in result.variables
        np.testing.assert_array_almost_equal(result.time, expected_data[:, 0])
        np.testing.assert_array_almost_equal(result.variables["v(x)"], expected_data[:, 1])

    def test_handles_missing_binary(self, tmp_path):
        raw_path = tmp_path / "empty.raw"
        raw_path.write_text("Title: test\nNo data here\n")
        result = parse_raw_file(raw_path)
        assert not result.success

    def test_handles_zero_points(self, tmp_path):
        header = """Title: test
Plotname: Transient Analysis
Flags: real
No. Variables: 3
No. Points: 0
Variables:
\t0\ttime\ttime
\t1\tv(x)\tvoltage
\t2\tv(y)\tvoltage
Binary:
"""
        raw_path = tmp_path / "zero.raw"
        raw_path.write_bytes(header.encode("utf-8"))
        result = parse_raw_file(raw_path)
        assert not result.success

    def test_handles_truncated_binary(self, tmp_path):
        header = """Title: test
Plotname: Transient Analysis
Flags: real
No. Variables: 3
No. Points: 1000
Variables:
\t0\ttime\ttime
\t1\tv(x)\tvoltage
\t2\tv(y)\tvoltage
Binary:
"""
        data = np.random.randn(500, 3).astype(np.float64)
        data[:, 0] = np.linspace(0, 0.5, 500)

        raw_path = tmp_path / "trunc.raw"
        with open(raw_path, "wb") as f:
            f.write(header.encode("utf-8"))
            f.write(data.tobytes())

        result = parse_raw_file(raw_path)
        assert result.success
        assert len(result.time) == 500

    def test_time_variable_detected(self, tmp_path):
        var_names = ["time", "v(out)"]
        raw_path, expected_data = _make_raw_file(tmp_path, 2, 100, var_names)
        result = parse_raw_file(raw_path)
        assert result.success
        assert len(result.time) == 100
        assert "v(out)" in result.variables


class TestSimulationResult:
    def test_dataclass_fields(self):
        result = SimulationResult(
            time=np.array([0.0, 1.0]),
            variables={"v(x)": np.array([0.1, 0.2])},
            success=True,
            stderr="",
        )
        assert result.success
        assert len(result.time) == 2
        assert "v(x)" in result.variables
