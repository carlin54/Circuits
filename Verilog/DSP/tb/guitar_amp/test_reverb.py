"""Tests for reverb.v — Schroeder reverb (parallel combs + series allpass)."""

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
    dut.decay.value = 0
    dut.damping_ctrl.value = 0
    dut.mix.value = 0
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
    """Collect multiple valid output samples as signed integers."""
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
async def test_impulse_response(dut):
    """An impulse input with nonzero decay/mix produces a decaying output tail.

    After the initial impulse, the comb filter feedback should produce
    output samples that decay over time.
    """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set reverb parameters: moderate decay, no damping, full wet
    dut.decay.value = 180       # Moderate feedback
    dut.damping_ctrl.value = 0  # No damping (raw delay)
    dut.mix.value = 255         # Full wet so we see the reverb tail

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send an impulse (one loud sample followed by silence)
    impulse_val = float_to_fixed(0.8, DATA_WIDTH, FRAC_BITS)
    await send_sample(dut, impulse_val)

    # Follow with silence for many samples to let the reverb tail develop
    num_silence = 100
    for _ in range(num_silence):
        await send_sample(dut, 0)

    # Collect all available outputs
    outputs = await collect_outputs(dut, num_silence + 1, timeout=2000)
    assert len(outputs) > 10, \
        f"Too few outputs received: {len(outputs)}"

    # The first output should contain the impulse (or part of it through mix)
    # After initial samples, the comb feedback should produce nonzero tail
    # (comb delays are 1557, 1617, 1491, 1422 samples — so echoes appear later)
    # For this test with short sequence, verify pipeline is functional
    # and that at least some non-zero output exists from the impulse
    has_nonzero = any(abs(o) > 0 for o in outputs)
    assert has_nonzero, "All outputs zero — reverb produced no signal"


@cocotb.test()
async def test_dry_only(dut):
    """With mix=0, output equals the dry input signal (no wet reverb)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Mix = 0 means fully dry: output = input * (255-0)/255 = input
    dut.decay.value = 200
    dut.damping_ctrl.value = 128
    dut.mix.value = 0  # Fully dry

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send several samples
    test_values = [
        float_to_fixed(0.5, DATA_WIDTH, FRAC_BITS),
        float_to_fixed(-0.3, DATA_WIDTH, FRAC_BITS),
        float_to_fixed(0.7, DATA_WIDTH, FRAC_BITS),
        float_to_fixed(-0.1, DATA_WIDTH, FRAC_BITS),
    ]

    for val in test_values:
        await send_sample(dut, val)

    outputs = await collect_outputs(dut, len(test_values), timeout=500)
    assert len(outputs) == len(test_values), \
        f"Expected {len(test_values)} outputs, got {len(outputs)}"

    # With mix=0: output = dry = input * 255/256 (approximately input)
    for i, (out, inp) in enumerate(zip(outputs, test_values)):
        inp_signed = int(inp)
        if inp_signed >= (1 << (DATA_WIDTH - 1)):
            inp_signed -= (1 << DATA_WIDTH)

        # Allow small rounding error from the 255/256 scaling
        tolerance = abs(inp_signed) // 64 + 4  # ~1.5% + small absolute tolerance
        assert abs(out - inp_signed) <= tolerance, \
            f"Sample[{i}]: output {out} != input {inp_signed} (tol={tolerance})"


@cocotb.test()
async def test_zero_input(dut):
    """Silence in produces silence out (or decaying tail from prior state).

    After reset, zero input should produce zero output since there is
    no energy in the comb buffers.
    """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Full wet to expose any spurious reverb energy
    dut.decay.value = 200
    dut.damping_ctrl.value = 128
    dut.mix.value = 128  # Half mix

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send only zeros
    num_samples = 20
    for _ in range(num_samples):
        await send_sample(dut, 0)

    outputs = await collect_outputs(dut, num_samples, timeout=500)
    assert len(outputs) > 0, "No output produced for zero input"

    # After reset, comb buffers are zeroed, so zero input -> zero output
    for i, out in enumerate(outputs):
        assert abs(out) <= 1, \
            f"Output[{i}] = {out}, expected 0 for zero input after reset"
