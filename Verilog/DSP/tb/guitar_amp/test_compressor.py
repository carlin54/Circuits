"""Cocotb testbench for compressor.v (dynamics processor)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly

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
    dut.threshold.value = 0
    dut.ratio.value = 0
    dut.attack.value = 0
    dut.release_coeff.value = 0
    dut.makeup.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_sample(dut, value):
    """Send a single sample via AXI-Stream slave interface."""
    dut.s_axis_tdata.value = to_twos_complement(value)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 1
    while True:
        await RisingEdge(dut.clk)
        if int(dut.s_axis_tready.value) == 1:
            break
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0


async def collect_output(dut, timeout=200):
    """Wait for a valid output sample and return its signed value."""
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            raw = int(dut.m_axis_tdata.value)
            return from_twos_complement(raw)
    return None


@cocotb.test()
async def test_below_threshold(dut):
    """Signal below threshold should pass unchanged (no gain reduction)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set threshold high so the test signal is below it
    dut.threshold.value = 255
    dut.ratio.value = 4
    dut.attack.value = 100
    dut.release_coeff.value = 100
    dut.makeup.value = 128  # 128 = unity makeup gain (signal * 128 >>> 7 = signal)

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Small signal well below threshold
    test_value = int(0.1 * (1 << FRAC_BITS))

    # Send enough samples for the envelope detector to settle
    for _ in range(200):
        await send_sample(dut, test_value)

    # Collect output
    result = await collect_output(dut, timeout=500)

    assert result is not None, "No output received from DUT"
    # Below threshold: output should equal input (allow tolerance for processing)
    tolerance = max(8, abs(test_value) // 10)
    assert abs(result - test_value) <= tolerance, \
        f"Below-threshold output {result} differs from input {test_value} by more than {tolerance}"


@cocotb.test()
async def test_above_threshold(dut):
    """Signal above threshold should be reduced (compressed)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set threshold low so the test signal exceeds it
    dut.threshold.value = 20
    dut.ratio.value = 8
    dut.attack.value = 500
    dut.release_coeff.value = 200
    dut.makeup.value = 0

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Large signal that should exceed threshold
    test_value = int(0.9 * (1 << FRAC_BITS))

    # Send many samples to let the compressor envelope detector engage
    for _ in range(500):
        await send_sample(dut, test_value)

    # Collect output after compressor has engaged
    outputs = []
    for _ in range(50):
        result = await collect_output(dut, timeout=100)
        if result is not None:
            outputs.append(result)

    assert len(outputs) > 0, "No output samples received"

    # At least some outputs should be reduced below the input level
    reduced = [o for o in outputs if o < test_value - 8]
    assert len(reduced) > 0, \
        f"No gain reduction observed. Outputs: {outputs[:5]}... Input was: {test_value}"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input should produce zero output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set some active compressor settings
    dut.threshold.value = 128
    dut.ratio.value = 4
    dut.attack.value = 200
    dut.release_coeff.value = 200
    dut.makeup.value = 0

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
