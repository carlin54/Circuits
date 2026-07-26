"""Tests for delay_line.v — RAM-based digital delay with feedback and wet/dry mix."""

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
    dut.delay_time.value = 0
    dut.feedback.value = 0
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
async def test_delay_correct(dut):
    """Signal appears in the wet path after the specified delay.

    Send an impulse, then silence. With full wet mix and the delay set to N
    samples, the delayed impulse should appear at output position N.
    """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Set a short delay for testability
    delay_samples = 10
    dut.delay_time.value = delay_samples
    dut.feedback.value = 0      # No feedback (single echo)
    dut.mix.value = 255         # Full wet to see the delayed signal clearly

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send an impulse followed by silence
    impulse_val = float_to_fixed(0.5, DATA_WIDTH, FRAC_BITS)
    total_samples = delay_samples + 20  # Enough to see the echo

    await send_sample(dut, impulse_val)
    for _ in range(total_samples - 1):
        await send_sample(dut, 0)

    # Collect all outputs
    outputs = await collect_outputs(dut, total_samples, timeout=2000)
    assert len(outputs) >= delay_samples + 1, \
        f"Too few outputs: {len(outputs)}, need at least {delay_samples + 1}"

    # With full wet (mix=255): output = delayed_sample * 255/256
    # The first output should be the delayed buffer read (initially 0)
    # The impulse should appear at index = delay_samples
    # (because the delay buffer starts empty, and we wrote the impulse at position 0,
    #  which gets read back delay_samples later)

    # Find the first significantly nonzero output (the delayed impulse)
    impulse_threshold = abs(int(impulse_val)) // 4  # At least 25% of input
    if int(impulse_val) >= (1 << (DATA_WIDTH - 1)):
        impulse_threshold = abs(int(impulse_val) - (1 << DATA_WIDTH)) // 4

    found_at = None
    for i, out in enumerate(outputs):
        if abs(out) > impulse_threshold:
            found_at = i
            break

    assert found_at is not None, \
        f"Delayed impulse never appeared in output (max={max(abs(o) for o in outputs)})"
    assert found_at == delay_samples, \
        f"Impulse appeared at index {found_at}, expected {delay_samples}"


@cocotb.test()
async def test_dry_only(dut):
    """With mix=0, output equals the dry input signal (no delayed component)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Mix=0 means fully dry
    dut.delay_time.value = 50
    dut.feedback.value = 128
    dut.mix.value = 0  # Fully dry

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send several samples
    test_values = [
        float_to_fixed(0.4, DATA_WIDTH, FRAC_BITS),
        float_to_fixed(-0.6, DATA_WIDTH, FRAC_BITS),
        float_to_fixed(0.2, DATA_WIDTH, FRAC_BITS),
        float_to_fixed(-0.8, DATA_WIDTH, FRAC_BITS),
        float_to_fixed(0.1, DATA_WIDTH, FRAC_BITS),
    ]

    for val in test_values:
        await send_sample(dut, val)

    outputs = await collect_outputs(dut, len(test_values), timeout=500)
    assert len(outputs) == len(test_values), \
        f"Expected {len(test_values)} outputs, got {len(outputs)}"

    # With mix=0: output = input * (255-0)/256 + delayed * 0/256
    # This is approximately input (off by at most input/256)
    for i, (out, inp) in enumerate(zip(outputs, test_values)):
        inp_signed = int(inp)
        if inp_signed >= (1 << (DATA_WIDTH - 1)):
            inp_signed -= (1 << DATA_WIDTH)

        # Tolerance: rounding from the 255/256 multiply plus 1-2 LSB
        tolerance = abs(inp_signed) // 64 + 4
        assert abs(out - inp_signed) <= tolerance, \
            f"Sample[{i}]: output {out} != input {inp_signed} (tol={tolerance})"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input with empty delay buffer produces zero output."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Half mix to expose any spurious signal from delay buffer
    dut.delay_time.value = 20
    dut.feedback.value = 200
    dut.mix.value = 128

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send only zeros — delay buffer uninitialized memory may read X in sim,
    # but after reset write pointer starts at 0 and we read from (0 - delay_time).
    # In Verilog sim, uninitialized RAM reads as X/0 depending on simulator.
    # With Icarus, reg arrays initialize to 'x' but $signed('x') is typically 0.
    num_samples = 30
    for _ in range(num_samples):
        await send_sample(dut, 0)

    outputs = await collect_outputs(dut, num_samples, timeout=500)
    assert len(outputs) > 0, "No output produced for zero input"

    # After enough zero samples have been written, all reads should also be zero.
    # Check the last portion of outputs (after delay_time samples have been written).
    safe_start = min(21, len(outputs))  # After delay_time=20 samples
    for i in range(safe_start, len(outputs)):
        assert abs(outputs[i]) <= 1, \
            f"Output[{i}] = {outputs[i]}, expected 0 for zero input"
