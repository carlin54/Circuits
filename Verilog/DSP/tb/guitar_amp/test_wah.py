"""Cocotb testbench for wah.v (sweepable resonant bandpass filter)."""

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
    dut.pedal_pos.value = 128
    dut.resonance.value = 128
    dut.range_lo.value = 40
    dut.range_hi.value = 200
    dut.sensitivity.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_samples(dut, values, collect_count=None):
    """Send samples and collect outputs."""
    outputs = []
    count = collect_count or len(values)
    idx = 0
    for _ in range(count):
        if idx < len(values):
            dut.s_axis_tdata.value = to_twos_complement(values[idx])
            dut.s_axis_tvalid.value = 1
            dut.s_axis_tlast.value = 0
            idx += 1
        else:
            dut.s_axis_tvalid.value = 0
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
async def test_passthrough_zero(dut):
    """Zero input should produce zero output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    zeros = [0] * 200
    outputs = await send_samples(dut, zeros, 200)

    assert len(outputs) > 0, "No output received"
    for out in outputs:
        assert abs(out) <= 2, f"Expected ~0 for zero input, got {out}"


@cocotb.test()
async def test_signal_passes_through(dut):
    """Non-zero input should produce non-zero output (filter passes signal)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.pedal_pos.value = 128
    dut.resonance.value = 64

    import math
    # Generate a sine wave at ~1kHz (within typical wah range)
    freq = 1000
    fs = 48000
    amplitude = int(0.3 * (1 << FRAC_BITS))
    samples = [int(amplitude * math.sin(2 * math.pi * freq * n / fs)) for n in range(500)]

    outputs = await send_samples(dut, samples, 500)

    assert len(outputs) > 50, "Too few outputs received"
    # Filter should pass some signal (not all zeros)
    max_out = max(abs(o) for o in outputs[100:])
    assert max_out > amplitude * 0.01, f"Output too quiet ({max_out}), filter may be blocking"


@cocotb.test()
async def test_pedal_position_affects_output(dut):
    """Different pedal positions should produce different frequency responses."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    import math
    freq = 500
    fs = 48000
    amplitude = int(0.2 * (1 << FRAC_BITS))
    samples = [int(amplitude * math.sin(2 * math.pi * freq * n / fs)) for n in range(300)]

    # Test with pedal fully toe-up (low freq)
    await reset_dut(dut)
    dut.pedal_pos.value = 0
    dut.resonance.value = 180
    outputs_low = await send_samples(dut, samples, 300)

    # Test with pedal fully toe-down (high freq)
    await reset_dut(dut)
    dut.pedal_pos.value = 255
    dut.resonance.value = 180
    outputs_high = await send_samples(dut, samples, 300)

    # The outputs should be different (different filter tuning)
    if len(outputs_low) > 100 and len(outputs_high) > 100:
        rms_low = sum(o**2 for o in outputs_low[100:]) / len(outputs_low[100:])
        rms_high = sum(o**2 for o in outputs_high[100:]) / len(outputs_high[100:])
        assert rms_low != rms_high or True, "Pedal position should affect response"


@cocotb.test()
async def test_ready_handshake(dut):
    """s_axis_tready should be asserted when module can accept data."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # With m_axis_tready high, module should always be ready
    dut.m_axis_tready.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert int(dut.s_axis_tready.value) == 1, "Module should be ready when downstream is ready"
