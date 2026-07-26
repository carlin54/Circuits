import pytest
from circuits import get_circuit, load_all, ALL_CIRCUITS
from circuits.base import BaseCircuit
from src.registry import ModelRegistry


CIRCUIT_NAMES = [
    "chua", "rossler", "lorenz", "chen", "sprott_a",
    "halvorsen", "aizawa", "thomas", "dadras", "lu",
]


class TestCircuitLoading:
    def test_get_circuit_chua(self):
        cls = get_circuit("chua")
        assert cls.NAME == "chua"

    def test_get_circuit_all_known(self):
        for name in CIRCUIT_NAMES:
            cls = get_circuit(name)
            assert cls.NAME == name

    def test_get_circuit_unknown_raises(self):
        with pytest.raises(KeyError, match="Unknown circuit"):
            get_circuit("nonexistent")

    def test_load_all_returns_list(self):
        all_circuits = load_all()
        assert len(all_circuits) >= len(CIRCUIT_NAMES)
        names = [c.NAME for c in all_circuits]
        for expected in CIRCUIT_NAMES:
            assert expected in names


class TestNetlistGeneration:
    def setup_method(self):
        self.registry = ModelRegistry()

    @pytest.mark.parametrize("name", CIRCUIT_NAMES)
    def test_generate_netlist_returns_string(self, name):
        cls = get_circuit(name)
        circuit = cls()
        netlist = circuit.generate_netlist(self.registry)
        assert isinstance(netlist, str)
        assert len(netlist) > 100

    @pytest.mark.parametrize("name", CIRCUIT_NAMES)
    def test_netlist_has_required_sections(self, name):
        cls = get_circuit(name)
        circuit = cls()
        netlist = circuit.generate_netlist(self.registry)
        assert ".end" in netlist.lower()
        assert ".tran" in netlist.lower()
        assert "vcc" in netlist.lower()
        assert "vee" in netlist.lower()

    @pytest.mark.parametrize("name", CIRCUIT_NAMES)
    def test_netlist_has_initial_conditions(self, name):
        cls = get_circuit(name)
        circuit = cls()
        netlist = circuit.generate_netlist(self.registry)
        assert ".ic" in netlist.lower()

    @pytest.mark.parametrize("name", CIRCUIT_NAMES)
    def test_netlist_has_integrators(self, name):
        cls = get_circuit(name)
        circuit = cls()
        netlist = circuit.generate_netlist(self.registry)
        assert "xu1" in netlist.lower()
        assert "xu2" in netlist.lower()
        assert "xu3" in netlist.lower()
        assert "c1" in netlist.lower()

    @pytest.mark.parametrize("name", CIRCUIT_NAMES)
    def test_get_plot_variables_returns_tuple(self, name):
        cls = get_circuit(name)
        circuit = cls()
        x_var, y_var = circuit.get_plot_variables()
        assert x_var.startswith("v(")
        assert y_var.startswith("v(")

    @pytest.mark.parametrize("name", CIRCUIT_NAMES)
    def test_circuit_has_metadata(self, name):
        cls = get_circuit(name)
        assert cls.NAME != ""
        assert cls.DESCRIPTION != ""
        assert isinstance(cls.PLOT_AXES, tuple)
        assert len(cls.PLOT_AXES) == 2
