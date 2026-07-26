import pytest
from src.registry import ModelRegistry, OpAmpModel, MultiplierModel


class TestModelRegistry:
    def setup_method(self):
        self.registry = ModelRegistry()

    def test_default_opamps_registered(self):
        assert "LT1057" in self.registry.list_opamps()
        assert "TL072" in self.registry.list_opamps()

    def test_default_multiplier_registered(self):
        assert "AD633" in self.registry.list_multipliers()

    def test_get_opamp_returns_model(self):
        opamp = self.registry.get_opamp("LT1057")
        assert isinstance(opamp, OpAmpModel)
        assert opamp.name == "LT1057"
        assert opamp.gbw_hz == 5e6
        assert opamp.slew_rate_v_us == 15
        assert opamp.supply_voltage == 15

    def test_get_opamp_tl072(self):
        opamp = self.registry.get_opamp("TL072")
        assert opamp.gbw_hz == 3e6

    def test_get_multiplier_returns_model(self):
        mult = self.registry.get_multiplier("AD633")
        assert isinstance(mult, MultiplierModel)
        assert mult.name == "AD633"
        assert len(mult.pins) == 8

    def test_get_opamp_missing_raises(self):
        with pytest.raises(KeyError):
            self.registry.get_opamp("NONEXISTENT")

    def test_get_multiplier_missing_raises(self):
        with pytest.raises(KeyError):
            self.registry.get_multiplier("NONEXISTENT")


class TestOpAmpModel:
    def test_get_include(self):
        model = OpAmpModel(
            name="TEST",
            lib_path="test.lib",
            subckt_name="TEST_SUB",
            pins=["INP", "INN", "VCC", "VEE", "OUT"],
            gbw_hz=1e6,
            slew_rate_v_us=10,
            supply_voltage=15,
        )
        include = model.get_include()
        assert "test.lib" in include
        assert ".include" in include

    def test_instantiate(self):
        model = OpAmpModel(
            name="TEST",
            lib_path="test.lib",
            subckt_name="TEST_SUB",
            pins=["INP", "INN", "VCC", "VEE", "OUT"],
            gbw_hz=1e6,
            slew_rate_v_us=10,
            supply_voltage=15,
        )
        connections = {"INP": "net1", "INN": "net2", "VCC": "vcc", "VEE": "vee", "OUT": "out1"}
        inst = model.instantiate("XU1", connections)
        assert inst == "XU1 net1 net2 vcc vee out1 TEST_SUB"


class TestMultiplierModel:
    def test_instantiate(self):
        model = MultiplierModel(
            name="AD633",
            lib_path="AD633.lib",
            subckt_name="AD633",
            pins=["X1", "X2", "Y1", "Y2", "Z", "W", "VP", "VN"],
        )
        connections = {
            "X1": "x", "X2": "0", "Y1": "z", "Y2": "0",
            "Z": "0", "W": "w_xz", "VP": "vcc", "VN": "vee",
        }
        inst = model.instantiate("XM1", connections)
        assert "XM1" in inst
        assert "AD633" in inst
