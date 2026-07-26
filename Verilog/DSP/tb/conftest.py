"""Shared pytest/cocotb fixtures for the FPGA signal processing project."""

import sys
from pathlib import Path

# Add helpers to path
sys.path.insert(0, str(Path(__file__).parent))
