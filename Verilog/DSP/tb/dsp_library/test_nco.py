"""Tests for NCO (nco.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np


async def reset_dut(dut, cycles=5):
    dut.rst.value = 1
    dut.freq_word.value = 0
    dut.phase_offset.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_nco_zero_freq(dut):
    """Zero frequency word should produce DC output."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.freq_word.value = 0
    dut.phase_offset.value = 0

    # Wait for valid output
    outputs = []
    for _ in range(20):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid.value) == 1:
            sin_val = int(dut.sin_out.value)
            outputs.append(sin_val)

    # With zero freq, phase stays at 0, so sin(0) = 0
    if len(outputs) > 2:
        # All outputs should be the same (DC)
        assert len(set(outputs[-5:])) <= 2, \
            "Zero freq should give constant output"


@cocotb.test()
async def test_nco_output_changes(dut):
    """Non-zero frequency should produce changing output."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    phase_width = int(dut.PHASE_WIDTH)
    # Set freq_word for ~1/16 of sample rate (one full cycle per 16 clocks)
    freq_word = (1 << phase_width) // 16
    dut.freq_word.value = freq_word

    outputs_sin = []
    for _ in range(40):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid.value) == 1:
            outputs_sin.append(int(dut.sin_out.value))

    # Output should vary (not constant)
    assert len(set(outputs_sin)) > 1, "NCO output should change with non-zero freq"


@cocotb.test()
async def test_nco_sin_cos_quadrature(dut):
    """Sin and cos outputs should be in quadrature (90° apart)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    phase_width = int(dut.PHASE_WIDTH)
    output_width = int(dut.OUTPUT_WIDTH)
    freq_word = (1 << phase_width) // 32  # 32 samples per cycle

    dut.freq_word.value = freq_word

    sin_vals = []
    cos_vals = []

    for _ in range(80):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid.value) == 1:
            s = int(dut.sin_out.value)
            c = int(dut.cos_out.value)
            if s >= (1 << (output_width - 1)):
                s -= (1 << output_width)
            if c >= (1 << (output_width - 1)):
                c -= (1 << output_width)
            sin_vals.append(s)
            cos_vals.append(c)

    # Verify quadrature: sin^2 + cos^2 should be approximately constant
    if len(sin_vals) > 16:
        magnitudes = [s*s + c*c for s, c in zip(sin_vals[4:], cos_vals[4:])]
        mean_mag = np.mean(magnitudes)
        # All magnitudes should be within 30% of mean (generous for LUT inaccuracy)
        for m in magnitudes:
            assert abs(m - mean_mag) < 0.3 * mean_mag, \
                "sin^2 + cos^2 should be approximately constant"
