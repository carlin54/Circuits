"""Cocotb testbench for noise_gate.v (state machine gate)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from helpers.fixed_point import float_to_fixed, fixed_to_float


DATA_WIDTH = 24
FRAC_BITS = 22


def to_twos_complement(value, width=DATA_WIDTH):
    """Convert signed integer to unsigned two's complement representation."""
    if value < 0:
        return value + (1 << width)
    return value & ((1 << width) - 1)


def from_twos_complement(value, width=DATA_WIDTH):
    """Convert unsigned two's complement back to signed integer."""
    if value >= (1 << (width - 1)):
        return value - (1 << width)
    return value


async def reset_dut(dut, cycles=10):
    """Assert reset for the specified number of clock cycles."""
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    dut.open_threshold.value = 0
    dut.close_threshold.value = 0
    dut.hold_time.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_sample(dut, value):
    """Send a single sample via AXI-Stream slave interface."""
    dut.s_axis_tdata.value = to_twos_complement(value)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 1
    await RisingEdge(dut.clk)
    while dut.s_axis_tready.value == 0:
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0


async def collect_output(dut, timeout=200):
    """Wait for a valid output sample and return its signed value."""
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.m_axis_tvalid.value == 1:
            raw = int(dut.m_axis_tdata.value)
            return from_twos_complement(raw)
    return None


@cocotb.test()
async def test_gate_opens(dut):
    """Signal above open_threshold should pass through the gate."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set low thresholds so the signal opens the gate easily
    dut.open_threshold.value = 10    # Low open threshold
    dut.close_threshold.value = 5    # Even lower close threshold (hysteresis)
    dut.hold_time.value = 100        # Short hold time

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Large signal well above threshold
    test_value = int(0.7 * (1 << FRAC_BITS))

    # Send enough samples for the gate to detect and open
    for _ in range(200):
        await send_sample(dut, test_value)

    # Collect output - gate should be open, passing signal through
    outputs = []
    for _ in range(50):
        result = await collect_output(dut, timeout=100)
        if result is not None:
            outputs.append(result)

    assert len(outputs) > 0, "No output samples received"

    # At least some outputs should be non-zero and close to the input
    # (gate open means signal passes through, possibly with envelope shaping)
    passing = [o for o in outputs if abs(o) > abs(test_value) // 4]
    assert len(passing) > 0, \
        f"Gate did not open - all outputs near zero. Outputs: {outputs[:10]}"


@cocotb.test()
async def test_gate_closed(dut):
    """Signal below threshold should be silenced by the gate."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set high thresholds so even a moderate signal stays below
    dut.open_threshold.value = 250   # Very high open threshold
    dut.close_threshold.value = 240  # High close threshold
    dut.hold_time.value = 10         # Short hold

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Small signal below the gate threshold
    test_value = int(0.01 * (1 << FRAC_BITS))

    # Send samples - gate should remain closed
    for _ in range(200):
        await send_sample(dut, test_value)

    # Collect output
    outputs = []
    for _ in range(50):
        result = await collect_output(dut, timeout=100)
        if result is not None:
            outputs.append(result)

    assert len(outputs) > 0, "No output samples received"

    # Gate closed: output should be silenced (zero or heavily attenuated)
    # RANGE_DB parameter controls attenuation depth
    max_allowed = abs(test_value) // 2  # Should be significantly attenuated
    silenced = [o for o in outputs if abs(o) <= max_allowed]
    assert len(silenced) > len(outputs) // 2, \
        f"Gate not closing - outputs not attenuated. Outputs: {outputs[:10]}, threshold: {max_allowed}"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input should produce zero output regardless of gate state."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set moderate thresholds
    dut.open_threshold.value = 50
    dut.close_threshold.value = 30
    dut.hold_time.value = 100

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send zero samples
    for _ in range(100):
        await send_sample(dut, 0)

    # Collect outputs
    outputs = []
    for _ in range(50):
        result = await collect_output(dut, timeout=100)
        if result is not None:
            outputs.append(result)

    assert len(outputs) > 0, "No output samples received"

    # All outputs should be zero
    for i, out in enumerate(outputs):
        assert abs(out) <= 2, \
            f"Output sample {i} = {out}, expected 0 for zero input"
