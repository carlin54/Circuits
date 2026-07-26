"""Cocotb testbench for tremolo.v (amplitude modulation via LFO)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

DATA_WIDTH = 24
FRAC_BITS = 22


def to_twos_complement(value, width=DATA_WIDTH):
    if value < 0:
        return value + (1 << width)
    return value & ((1 << width) - 1)


def from_twos_complement(value, width=DATA_WIDTH):
    if value >= (1 << (width - 1)):
        return value - (1 << width)
    return value


async def reset_dut(dut, cycles=10):
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    dut.rate.value = 0
    dut.depth.value = 0
    dut.shape.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_constant_collect(dut, value, count):
    """Send a constant value and collect outputs."""
    outputs = []
    dut.s_axis_tdata.value = to_twos_complement(value)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 0
    for _ in range(count):
        await RisingEdge(dut.clk)
        try:
            if int(dut.m_axis_tvalid.value) == 1:
                raw = int(dut.m_axis_tdata.value)
                outputs.append(from_twos_complement(raw))
        except ValueError:
            pass
    dut.s_axis_tvalid.value = 0
    return outputs


@cocotb.test()
async def test_no_modulation(dut):
    """With depth=0, output should equal input (no volume modulation)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.rate.value = 100
    dut.depth.value = 0  # No modulation
    dut.shape.value = 0

    test_value = int(0.5 * (1 << FRAC_BITS))
    outputs = await send_constant_collect(dut, test_value, 200)

    assert len(outputs) > 0, "No output received"
    # With depth=0: gain = 255-0 + (lfo*0)/256 = 255 always
    # output = input * 255 >> 8 ≈ input * 0.996
    expected = (test_value * 255) >> 8
    for out in outputs[-50:]:
        assert abs(out - expected) <= 2, \
            f"With depth=0, output {out} should be ~{expected}"


@cocotb.test()
async def test_full_depth_modulates(dut):
    """With depth=255, output amplitude should vary between ~0 and input level."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.rate.value = 200  # Fast LFO
    dut.depth.value = 255  # Full modulation
    dut.shape.value = 1    # Triangle for smooth sweep

    test_value = int(0.4 * (1 << FRAC_BITS))
    # Need many samples to see full LFO cycle
    outputs = await send_constant_collect(dut, test_value, 2000)

    assert len(outputs) > 100, "Not enough outputs received"

    min_out = min(outputs[50:])
    max_out = max(outputs[50:])

    # With full depth: gain ranges from 0 to 255
    # So output should range from ~0 to ~input
    assert min_out < test_value // 4, \
        f"Min output {min_out} should be much less than input {test_value} at full depth"
    assert max_out > test_value // 2, \
        f"Max output {max_out} should be close to input {test_value}"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input should always produce zero output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.rate.value = 128
    dut.depth.value = 200
    dut.shape.value = 2  # Square wave

    outputs = await send_constant_collect(dut, 0, 200)
    assert len(outputs) > 0, "No output received"
    for out in outputs:
        assert abs(out) <= 1, f"Zero input should give zero output, got {out}"


@cocotb.test()
async def test_square_shape(dut):
    """Square LFO shape should produce two distinct amplitude levels."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.rate.value = 200
    dut.depth.value = 200
    dut.shape.value = 2  # Square

    test_value = int(0.3 * (1 << FRAC_BITS))
    outputs = await send_constant_collect(dut, test_value, 3000)

    assert len(outputs) > 500, "Not enough outputs"

    # Square wave should create two clusters of output values
    # Group outputs into "high" and "low"
    mid_point = (max(outputs[100:]) + min(outputs[100:])) // 2
    high_count = sum(1 for o in outputs[100:] if o > mid_point)
    low_count = sum(1 for o in outputs[100:] if o <= mid_point)

    # Both levels should have significant representation
    total = high_count + low_count
    assert high_count > total * 0.2, "Square shape should have ~50% high phase"
    assert low_count > total * 0.2, "Square shape should have ~50% low phase"
