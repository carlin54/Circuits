from abc import ABC, abstractmethod
from pathlib import Path

from src.registry import ModelRegistry


class BaseCircuit(ABC):
    NAME: str = ""
    DESCRIPTION: str = ""
    PLOT_AXES: tuple[str, str] = ("x", "y")

    @abstractmethod
    def generate_netlist(self, registry: ModelRegistry) -> str:
        pass

    @abstractmethod
    def get_plot_variables(self) -> tuple[str, str]:
        pass

    def get_variable_scaling(self) -> dict[str, float]:
        return {}
