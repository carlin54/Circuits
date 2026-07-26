import subprocess
import sys

import pytest

PROJECT_DIR = "/home/mordecai/Git/circuits"


class TestMainCLI:
    def test_list_command(self):
        result = subprocess.run(
            [sys.executable, "main.py", "list"],
            capture_output=True, text=True,
            cwd=PROJECT_DIR,
        )
        assert result.returncode == 0
        assert "chua" in result.stdout
        assert "lorenz" in result.stdout

    def test_run_missing_circuit_arg(self):
        result = subprocess.run(
            [sys.executable, "main.py", "run"],
            capture_output=True, text=True,
            cwd=PROJECT_DIR,
        )
        assert result.returncode != 0

    def test_reference_single(self, tmp_path):
        result = subprocess.run(
            [sys.executable, "main.py", "reference", "--circuit", "lorenz", "-o", str(tmp_path)],
            capture_output=True, text=True,
            cwd=PROJECT_DIR,
        )
        assert result.returncode == 0
        assert (tmp_path / "lorenz_reference.png").exists()
