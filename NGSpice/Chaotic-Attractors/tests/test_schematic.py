import pytest
from pathlib import Path

from src.schematic import draw_schematic, draw_all_schematics, CIRCUIT_TOPOLOGIES


CIRCUIT_NAMES = list(CIRCUIT_TOPOLOGIES.keys())


class TestSchematicTopologies:
    def test_all_circuits_have_topology(self):
        expected = ["chua", "rossler", "lorenz", "chen", "sprott_a",
                    "halvorsen", "aizawa", "thomas", "dadras", "lu"]
        for name in expected:
            assert name in CIRCUIT_TOPOLOGIES


class TestDrawSchematic:
    @pytest.mark.parametrize("name", CIRCUIT_NAMES)
    def test_draw_produces_file(self, name, tmp_path):
        out = tmp_path / f"{name}.png"
        draw_schematic(name, out)
        assert out.exists()
        assert out.stat().st_size > 1000

    def test_draw_creates_parent_dirs(self, tmp_path):
        out = tmp_path / "sub" / "dir" / "test.png"
        draw_schematic("chua", out)
        assert out.exists()

    def test_unknown_circuit_raises(self, tmp_path):
        with pytest.raises(KeyError):
            draw_schematic("nonexistent", tmp_path / "x.png")


class TestDrawAll:
    def test_draw_all_produces_all_files(self, tmp_path):
        results = draw_all_schematics(tmp_path)
        assert len(results) == len(CIRCUIT_NAMES)
        for name, ok in results.items():
            assert ok, f"{name} schematic failed"
            assert (tmp_path / f"{name}_schematic.png").exists()
