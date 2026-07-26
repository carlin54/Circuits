import numpy as np
import pytest
from src.ode_reference import solve_attractor, ATTRACTORS, lorenz, rossler, chua


class TestAttractorDefinitions:
    def test_all_attractors_have_required_keys(self):
        required = {"func", "ic", "t_span", "plot_axes", "var_names"}
        for name, info in ATTRACTORS.items():
            missing = required - set(info.keys())
            assert not missing, f"{name} missing keys: {missing}"

    def test_all_attractors_have_3_vars(self):
        for name, info in ATTRACTORS.items():
            assert len(info["var_names"]) == 3, f"{name} should have 3 variables"
            assert len(info["ic"]) == 3, f"{name} should have 3 initial conditions"

    def test_plot_axes_reference_valid_vars(self):
        for name, info in ATTRACTORS.items():
            ax, ay = info["plot_axes"]
            assert ax in info["var_names"], f"{name}: {ax} not in var_names"
            assert ay in info["var_names"], f"{name}: {ay} not in var_names"


class TestODEFunctions:
    def test_lorenz_returns_3_derivatives(self):
        result = lorenz(0, [1.0, 1.0, 1.0])
        assert len(result) == 3

    def test_lorenz_known_values(self):
        dx, dy, dz = lorenz(0, [0, 0, 0])
        assert dx == 0
        assert dy == 0
        assert dz == 0

    def test_rossler_returns_3_derivatives(self):
        result = rossler(0, [1.0, 1.0, 0.0])
        assert len(result) == 3

    def test_chua_returns_3_derivatives(self):
        result = chua(0, [0.1, 0.0, 0.0])
        assert len(result) == 3


class TestSolveAttractor:
    @pytest.mark.parametrize("name", list(ATTRACTORS.keys()))
    def test_solve_returns_all_variables(self, name):
        result = solve_attractor(name, max_step=0.1)
        assert "time" in result
        info = ATTRACTORS[name]
        for var in info["var_names"]:
            assert var in result, f"Missing variable {var} in {name} solution"

    @pytest.mark.parametrize("name", list(ATTRACTORS.keys()))
    def test_solve_returns_nonzero_points(self, name):
        result = solve_attractor(name, max_step=0.1)
        assert len(result["time"]) > 100

    @pytest.mark.parametrize("name", list(ATTRACTORS.keys()))
    def test_solve_time_is_monotonic(self, name):
        result = solve_attractor(name, max_step=0.1)
        dt = np.diff(result["time"])
        assert np.all(dt > 0)

    def test_lorenz_stays_bounded(self):
        result = solve_attractor("lorenz", max_step=0.05)
        assert np.all(np.abs(result["x"]) < 100)
        assert np.all(np.abs(result["y"]) < 100)
        assert np.all(result["z"] < 100)

    def test_rossler_stays_bounded(self):
        result = solve_attractor("rossler", max_step=0.05)
        assert np.all(np.abs(result["x"]) < 30)
        assert np.all(np.abs(result["y"]) < 30)

    def test_chua_stays_bounded(self):
        result = solve_attractor("chua", max_step=0.05)
        assert np.all(np.abs(result["x"]) < 10)
        assert np.all(np.abs(result["y"]) < 5)

    def test_unknown_attractor_raises(self):
        with pytest.raises(KeyError):
            solve_attractor("nonexistent")
