"""Cocotb testbench for pitch_shift.v (granular time-domain pitch shifter)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

import sys
import os
import math
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
    dut.shift.value = 0
    dut.mix.value = 255
    dut.grain_size_ctrl.value = 128
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_sine_collect(dut, freq, num_samples, amplitude=0.3):
    """Send a sine wave and collect outputs."""
    outputs = []
    amp = int(amplitude * (1 << FRAC_BITS))

    for n in range(num_samples):
        sample = int(amp * math.sin(2 * math.pi * freq * n / 48000))
        dut.s_axis_tdata.value = to_twos_complement(sample)
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 0

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
async def test_unity_shift(dut):
    """With shift=0 (unity), output should closely match input."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.shift.value = 0   # Unity pitch
    dut.mix.value = 255   # Full wet

    freq = 440
    outputs = await send_sine_collect(dut, freq, 3000)

    # After initial buffer fill, output should have energy
    stable = outputs[1200:]
    assert len(stable) > 100, "Not enough stable outputs"

    max_val = max(abs(o) for o in stable)
    amp = int(0.3 * (1 << FRAC_BITS))
    assert max_val > amp * 0.3, \
        f"Unity shift output too quiet ({max_val} vs expected ~{amp})"


@cocotb.test()
async def test_dry_mix(dut):
    """With mix=0 (fully dry), output should equal input."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.shift.value = to_twos_complement(64, 8)  # Some pitch shift
    dut.mix.value = 0   # Fully dry

    freq = 440
    amp = int(0.3 * (1 << FRAC_BITS))
    outputs = []

    for n in range(2000):
        sample = int(amp * math.sin(2 * math.pi * freq * n / 48000))
        dut.s_axis_tdata.value = to_twos_complement(sample)
        dut.s_axis_tvalid.value = 1
        await RisingEdge(dut.clk)
        try:
            if int(dut.m_axis_tvalid.value) == 1:
                raw = int(dut.m_axis_tdata.value)
                outputs.append((from_twos_complement(raw), sample))
        except ValueError:
            pass

    # With mix=0, wet contribution is 0 and dry is (input * 255) >> 8
    stable = outputs[1200:]
    assert len(stable) > 50, "Not enough stable outputs"

    for out, inp in stable[:20]:
        expected = (inp * 255) >> 8
        tolerance = abs(inp) * 0.05 + 10
        assert abs(out - expected) <= tolerance, \
            f"Dry-only output {out} != expected {expected}"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input should produce zero output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.shift.value = to_twos_complement(32, 8)
    dut.mix.value = 128

    outputs = await send_sine_collect(dut, 0, 2000, amplitude=0)

    stable = outputs[1200:]
    assert len(stable) > 0, "No outputs received"
    for out in stable:
        assert abs(out) <= 2, f"Zero input should give zero output, got {out}"


@cocotb.test()
async def test_pitch_up_produces_output(dut):
    """Pitch shift up should produce output with energy."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.shift.value = to_twos_complement(64, 8)  # Shift up
    dut.mix.value = 255

    outputs = await send_sine_collect(dut, 440, 4000)

    stable = outputs[2000:]
    assert len(stable) > 100, "Not enough outputs"

    max_val = max(abs(o) for o in stable)
    assert max_val > 100, f"Pitch-shifted output should have audible energy ({max_val})"


@cocotb.test()
async def test_pitch_down_produces_output(dut):
    """Pitch shift down should produce output with energy."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Negative shift (pitch down)
    dut.shift.value = to_twos_complement(-64, 8)
    dut.mix.value = 255

    outputs = await send_sine_collect(dut, 440, 4000)

    stable = outputs[2000:]
    assert len(stable) > 100, "Not enough outputs"

    max_val = max(abs(o) for o in stable)
    assert max_val > 100, f"Pitch-shifted output should have audible energy ({max_val})"
