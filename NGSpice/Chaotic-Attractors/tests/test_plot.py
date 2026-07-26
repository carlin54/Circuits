import tempfile
from pathlib import Path

import numpy as np
import pytest

from src.plot import plot_phase_space


class TestPlotPhaseSpace:
    def _make_data(self, n=500):
        t = np.linspace(0, 10, n)
        return {
            "v(x)": np.sin(t),
            "v(y)": np.cos(t),
            "time": t,
        }

    def test_creates_output_file(self, tmp_path):
        data = self._make_data()
        out = tmp_path / "test_plot.png"
        plot_phase_space(data, "v(x)", "v(y)", "Test", out)
        assert out.exists()
        assert out.stat().st_size > 1000

    def test_creates_parent_dirs(self, tmp_path):
        data = self._make_data()
        out = tmp_path / "sub" / "dir" / "plot.png"
        plot_phase_space(data, "v(x)", "v(y)", "Test", out)
        assert out.exists()

    def test_with_reference_data(self, tmp_path):
        data = self._make_data()
        ref_data = {
            "v(x)": np.sin(np.linspace(0, 10, 300)),
            "v(y)": np.cos(np.linspace(0, 10, 300)),
        }
        out = tmp_path / "compare.png"
        plot_phase_space(data, "v(x)", "v(y)", "Test", out, reference_data=ref_data)
        assert out.exists()

    def test_skip_fraction(self, tmp_path):
        data = self._make_data(1000)
        out = tmp_path / "skip.png"
        plot_phase_space(data, "v(x)", "v(y)", "Test", out, skip_fraction=0.2)
        assert out.exists()

    def test_handles_small_data(self, tmp_path):
        data = self._make_data(10)
        out = tmp_path / "small.png"
        plot_phase_space(data, "v(x)", "v(y)", "Test", out)
        assert out.exists()
