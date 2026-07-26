"""Cocotb testbench for limiter.v (brickwall output limiter with lookahead)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

DATA_WIDTH = 24
FRAC_BITS = 22
LOOKAHEAD = 32


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
    dut.threshold.value = 200
    dut.release_ctrl.value = 128
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_and_collect(dut, values, extra_cycles=50):
    """Send samples and collect outputs."""
    outputs = []
    total = len(values) + extra_cycles

    for i in range(total):
        if i < len(values):
            dut.s_axis_tdata.value = to_twos_complement(values[i])
            dut.s_axis_tvalid.value = 1
            dut.s_axis_tlast.value = 0
        else:
            dut.s_axis_tvalid.value = 0

        await RisingEdge(dut.clk)
        try:
            if int(dut.m_axis_tvalid.value) == 1:
                raw = int(dut.m_axis_tdata.value)
                outputs.append(from_twos_complement(raw))
        except ValueError:
            pass

    return outputs


@cocotb.test()
async def test_below_threshold_passthrough(dut):
    """Signals below threshold should pass through unchanged (minus lookahead delay)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.threshold.value = 200  # High threshold

    # Low-level signal (well below threshold)
    amplitude = int(0.1 * (1 << FRAC_BITS))  # ~10% of full scale
    values = [amplitude] * 200

    outputs = await send_and_collect(dut, values, extra_cycles=50)

    # After lookahead delay fills, outputs should closely match input
    stable_outputs = outputs[LOOKAHEAD + 10:]
    assert len(stable_outputs) > 20, "Not enough stable outputs"

    for out in stable_outputs[:20]:
        # With gain=255 (unity): output ≈ input * 255/256
        expected = (amplitude * 255) >> 8
        tolerance = abs(expected) * 0.1 + 10
        assert abs(out - expected) <= tolerance, \
            f"Below-threshold output {out} should be ~{expected}"


@cocotb.test()
async def test_above_threshold_limited(dut):
    """Signals above threshold should be attenuated."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.threshold.value = 64  # Low threshold (aggressive limiting)

    # High-level signal (well above threshold)
    amplitude = int(0.8 * (1 << FRAC_BITS))
    values = [amplitude] * 300

    outputs = await send_and_collect(dut, values, extra_cycles=50)

    # After lookahead fills and limiter engages, output should be reduced
    stable_outputs = outputs[LOOKAHEAD + 50:]
    assert len(stable_outputs) > 20, "Not enough stable outputs"

    # Output should be less than input (limiting is active)
    avg_out = sum(abs(o) for o in stable_outputs[:20]) / 20
    assert avg_out < amplitude, \
        f"Limiter should reduce output ({avg_out}) below input ({amplitude})"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input should produce zero output after lookahead fills."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    zeros = [0] * 200
    outputs = await send_and_collect(dut, zeros, extra_cycles=50)

    stable_outputs = outputs[LOOKAHEAD + 5:]
    assert len(stable_outputs) > 0, "No stable outputs"
    for out in stable_outputs:
        assert abs(out) <= 2, f"Zero input should give zero output, got {out}"


@cocotb.test()
async def test_lookahead_delay(dut):
    """Output should be delayed by LOOKAHEAD samples."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.threshold.value = 255  # Max threshold (no limiting)

    # Send zeros then a step
    values = [0] * 100 + [int(0.1 * (1 << FRAC_BITS))] * 100
    outputs = await send_and_collect(dut, values, extra_cycles=50)

    # The step should appear LOOKAHEAD samples after it was sent
    # First LOOKAHEAD outputs should be zero (filling the buffer)
    # Then zeros from the first 100 input samples
    # Then non-zero from the step, delayed by LOOKAHEAD
    if len(outputs) > 100 + LOOKAHEAD + 10:
        pre_step = outputs[LOOKAHEAD:100 + LOOKAHEAD]
        post_step = outputs[100 + LOOKAHEAD:100 + LOOKAHEAD + 20]
        if len(pre_step) > 5 and len(post_step) > 5:
            avg_pre = sum(abs(o) for o in pre_step[-5:]) / 5
            avg_post = sum(abs(o) for o in post_step[:5]) / 5
            assert avg_post > avg_pre, \
                "Step should appear in output after lookahead delay"
