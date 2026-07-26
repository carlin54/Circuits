"""Cocotb testbench for chorus.v (modulated delay with LFO)."""

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
    dut.rate.value = 0
    dut.depth.value = 0
    dut.mix.value = 0
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


async def send_and_collect(dut, value, count):
    """Send samples continuously and collect all valid outputs."""
    outputs = []
    dut.s_axis_tdata.value = to_twos_complement(value)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 1
    for _ in range(count):
        await RisingEdge(dut.clk)
        try:
            if int(dut.m_axis_tvalid.value) == 1:
                raw = int(dut.m_axis_tdata.value)
                outputs.append(from_twos_complement(raw))
        except ValueError:
            pass
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    return outputs


# BUF_SIZE = BASE_DELAY + MAX_DEPTH + 1 = 1200 + 480 + 1 = 1681
BUF_SIZE = 1681


@cocotb.test()
async def test_dry_only(dut):
    """With mix=0, the output should pass the input unchanged (dry only)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set controls: mix=0 means fully dry
    dut.rate.value = 64
    dut.depth.value = 128
    dut.mix.value = 0

    for _ in range(5):
        await RisingEdge(dut.clk)

    test_value = int(0.5 * (1 << FRAC_BITS))

    # Send enough samples to fill the buffer and get valid outputs
    outputs = await send_and_collect(dut, test_value, BUF_SIZE + 100)

    assert len(outputs) > 0, "No output received from DUT"
    # With mix=0: output = input * 255 >>> 8 ≈ input * 0.996 (loses ~0.4%)
    result = outputs[-1]
    expected = (test_value * 255) >> 8
    tolerance = 4
    assert abs(result - expected) <= tolerance, \
        f"Dry-only output {result} differs from expected {expected} by more than {tolerance}"


@cocotb.test()
async def test_wet_signal_present(dut):
    """With mix>0 and rate>0, output should differ from input due to modulated delay."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set controls for audible chorus effect
    dut.rate.value = 100
    dut.depth.value = 200
    dut.mix.value = 128  # 50% wet

    for _ in range(5):
        await RisingEdge(dut.clk)

    test_value = int(0.25 * (1 << FRAC_BITS))

    # Send enough to fill buffer and get meaningful outputs
    outputs = await send_and_collect(dut, test_value, BUF_SIZE + 200)

    # Use only outputs after buffer is filled
    late_outputs = outputs[BUF_SIZE:] if len(outputs) > BUF_SIZE else outputs
    assert len(late_outputs) > 0, "No output samples received"

    # With wet mix, at least some outputs should differ from the input
    differing = [o for o in late_outputs if abs(o - test_value) > 4]
    assert len(differing) > 0, \
        "Output never differs from input despite non-zero mix - wet signal not present"


@cocotb.test()
async def test_zero_input(dut):
    """Silence in should produce silence out regardless of effect settings."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set controls to active values
    dut.rate.value = 80
    dut.depth.value = 150
    dut.mix.value = 200

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send zero-valued samples — need BUF_SIZE to overwrite entire buffer from prior tests
    outputs = await send_and_collect(dut, 0, BUF_SIZE + 100)

    # Only check outputs after buffer is fully filled with zeros
    late_outputs = outputs[BUF_SIZE:] if len(outputs) > BUF_SIZE else outputs
    assert len(late_outputs) > 0, "No output samples received"

    # All outputs should be zero (or very close due to rounding)
    for i, out in enumerate(late_outputs):
        assert abs(out) <= 2, \
            f"Output sample {i} = {out}, expected 0 for zero input"
