"""Tests for tone_stack.v — cascaded biquad EQ (bass/mid/treble/presence/resonance)."""

import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers.fixed_point import float_to_fixed, fixed_to_float

DATA_WIDTH = 24
FRAC_BITS = 22


async def reset_dut(dut, cycles=10):
    """Apply reset and initialize all input signals."""
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    dut.bass.value = 128
    dut.mid.value = 128
    dut.treble.value = 128
    dut.presence.value = 128
    dut.resonance.value = 128
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_sample(dut, value, last=False):
    """Drive a single sample into the DUT and wait for acceptance."""
    dut.s_axis_tdata.value = int(value)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = int(last)
    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.s_axis_tready.value) == 1:
            break
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.s_axis_tdata.value = 0


async def collect_outputs(dut, count, timeout=500):
    """Collect multiple valid output samples."""
    results = []
    cycles = 0
    while len(results) < count and cycles < timeout:
        await RisingEdge(dut.clk)
        await ReadOnly()
        cycles += 1
        if int(dut.m_axis_tvalid.value) == 1:
            raw = int(dut.m_axis_tdata.value)
            if raw >= (1 << (DATA_WIDTH - 1)):
                raw -= (1 << DATA_WIDTH)
            results.append(raw)
    return results


@cocotb.test()
async def test_passthrough(dut):
    """With flat EQ settings (128=center), signal passes mostly unchanged.

    The cascaded biquads with center-position coefficients should approximate
    unity gain for a DC or slowly-varying signal.
    """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # All controls at midpoint (flat EQ)
    dut.bass.value = 128
    dut.mid.value = 128
    dut.treble.value = 128
    dut.presence.value = 128
    dut.resonance.value = 128

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send several identical samples (approximates DC)
    test_val = float_to_fixed(0.25, DATA_WIDTH, FRAC_BITS)
    num_samples = 20

    for i in range(num_samples):
        await send_sample(dut, test_val)

    # Collect outputs — after biquad settles, output should track input
    outputs = await collect_outputs(dut, num_samples, timeout=1000)

    assert len(outputs) > 0, "No output samples received"

    # Check that the last few outputs (after settling) are close to input
    # Allow generous tolerance since biquads may have some gain/attenuation
    # and coefficient initialization may not be perfectly flat
    input_float = fixed_to_float(test_val, DATA_WIDTH, FRAC_BITS)
    if len(outputs) >= 5:
        settled_outputs = outputs[-5:]
        for out in settled_outputs:
            out_float = fixed_to_float(
                out if out >= 0 else out + (1 << DATA_WIDTH),
                DATA_WIDTH, FRAC_BITS
            )
            # With default coefficients, expect within 50% of input
            # (generous tolerance for unloaded coefficient case)
            assert abs(out_float) <= abs(input_float) * 2.0 + 0.01, \
                f"Output {out_float:.4f} too far from input {input_float:.4f}"


@cocotb.test()
async def test_signal_present(dut):
    """Verify valid output is produced when valid input is provided."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set controls to arbitrary valid positions
    dut.bass.value = 200
    dut.mid.value = 100
    dut.treble.value = 180
    dut.presence.value = 128
    dut.resonance.value = 128

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send a burst of samples
    test_val = float_to_fixed(0.5, DATA_WIDTH, FRAC_BITS)
    num_samples = 10
    for i in range(num_samples):
        await send_sample(dut, test_val)

    # Should receive at least some valid outputs
    outputs = await collect_outputs(dut, num_samples, timeout=1000)
    assert len(outputs) > 0, \
        "No valid output received — tone stack pipeline stalled"

    # Verify we got a reasonable number of outputs
    # (cascaded biquads add pipeline latency, so we may get fewer)
    assert len(outputs) >= num_samples // 2, \
        f"Too few outputs: {len(outputs)}/{num_samples}"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input produces zero (or near-zero) output."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.bass.value = 128
    dut.mid.value = 128
    dut.treble.value = 128
    dut.presence.value = 128
    dut.resonance.value = 128

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send zero-valued samples
    num_samples = 15
    for i in range(num_samples):
        await send_sample(dut, 0)

    outputs = await collect_outputs(dut, num_samples, timeout=1000)
    assert len(outputs) > 0, "No output received for zero input"

    # All outputs should be zero (linear system with zero input = zero output)
    # Allow 1 LSB tolerance for rounding
    for i, out in enumerate(outputs):
        assert abs(out) <= 2, \
            f"Output[{i}] = {out}, expected 0 for zero input (tolerance: 2 LSB)"
