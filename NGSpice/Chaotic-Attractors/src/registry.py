from dataclasses import dataclass
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "models"


@dataclass
class OpAmpModel:
    name: str
    lib_path: str
    subckt_name: str
    pins: list[str]
    gbw_hz: float
    slew_rate_v_us: float
    supply_voltage: float

    def get_include(self) -> str:
        return f".include {MODELS_DIR / self.lib_path}"

    def instantiate(self, instance: str, connections: dict[str, str]) -> str:
        pin_nets = [connections[p] for p in self.pins]
        return f"{instance} {' '.join(pin_nets)} {self.subckt_name}"


@dataclass
class MultiplierModel:
    name: str
    lib_path: str
    subckt_name: str
    pins: list[str]

    def get_include(self) -> str:
        return f".include {MODELS_DIR / self.lib_path}"

    def instantiate(self, instance: str, connections: dict[str, str]) -> str:
        pin_nets = [connections[p] for p in self.pins]
        return f"{instance} {' '.join(pin_nets)} {self.subckt_name}"


class ModelRegistry:
    def __init__(self):
        self._opamps: dict[str, OpAmpModel] = {}
        self._multipliers: dict[str, MultiplierModel] = {}
        self._register_defaults()

    def _register_defaults(self):
        self._opamps["LT1057"] = OpAmpModel(
            name="LT1057",
            lib_path="LT1057.lib",
            subckt_name="LT1057",
            pins=["INP", "INN", "VCC", "VEE", "OUT"],
            gbw_hz=5e6,
            slew_rate_v_us=15,
            supply_voltage=15,
        )
        self._opamps["TL072"] = OpAmpModel(
            name="TL072",
            lib_path="TL072.lib",
            subckt_name="TL072",
            pins=["INP", "INN", "VCC", "VEE", "OUT"],
            gbw_hz=3e6,
            slew_rate_v_us=13,
            supply_voltage=15,
        )
        self._multipliers["AD633"] = MultiplierModel(
            name="AD633",
            lib_path="AD633.lib",
            subckt_name="AD633",
            pins=["X1", "X2", "Y1", "Y2", "Z", "W", "VP", "VN"],
        )

    def get_opamp(self, name: str) -> OpAmpModel:
        return self._opamps[name]

    def get_multiplier(self, name: str) -> MultiplierModel:
        return self._multipliers[name]

    def list_opamps(self) -> list[str]:
        return list(self._opamps.keys())

    def list_multipliers(self) -> list[str]:
        return list(self._multipliers.keys())
