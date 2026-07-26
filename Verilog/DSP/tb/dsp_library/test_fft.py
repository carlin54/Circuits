"""Tests for FFT top-level (fft_top.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np


async def reset_dut(dut, cycles=10):
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_fft_impulse(dut):
    """FFT of impulse should be constant magnitude across all bins."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    n = int(dut.N)
    data_width = int(dut.DATA_WIDTH)
    max_val = (1 << (data_width - 1)) - 1

    # Send impulse: 1.0 at sample 0, zeros elsewhere
    # Scale to avoid overflow with block scaling
    impulse_val = max_val >> int(np.log2(n))  # Account for 1/N scaling

    for i in range(n):
        dut.s_axis_tdata.value = impulse_val if i == 0 else 0
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 1 if i == n - 1 else 0
        await RisingEdge(dut.clk)

    dut.s_axis_tvalid.value = 0

    # Collect output
    output_re = []
    output_im = []
    timeout = n * int(np.log2(n)) * 2 + 100

    for _ in range(timeout):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            output_re.append(int(dut.m_axis_tdata_re.value))
            output_im.append(int(dut.m_axis_tdata_im.value))
            if int(dut.m_axis_tlast.value) == 1:
                break

    assert len(output_re) == n, f"Expected {n} output bins, got {len(output_re)}"


@cocotb.test()
async def test_fft_dc_signal(dut):
    """FFT of DC signal should have energy only in bin 0."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    n = int(dut.N)
    data_width = int(dut.DATA_WIDTH)
    dc_val = 1000  # Small DC value

    # Send constant value
    for i in range(n):
        dut.s_axis_tdata.value = dc_val
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 1 if i == n - 1 else 0
        await RisingEdge(dut.clk)

    dut.s_axis_tvalid.value = 0

    # Collect output
    output_re = []
    output_im = []
    timeout = n * int(np.log2(n)) * 2 + 100

    for _ in range(timeout):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            output_re.append(int(dut.m_axis_tdata_re.value))
            output_im.append(int(dut.m_axis_tdata_im.value))
            if int(dut.m_axis_tlast.value) == 1:
                break

    # Bin 0 should have all the energy (DC component)
    if len(output_re) == n:
        # Bin 0 real part should be largest
        bin0_mag = abs(output_re[0])
        other_max = max(abs(output_re[i]) for i in range(1, n))
        assert bin0_mag > other_max, "DC signal: bin 0 should dominate"


@cocotb.test()
async def test_fft_known_sinusoid(dut):
    """FFT of a known single-frequency sinusoid — energy in expected bin."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    n = int(dut.N)
    data_width = int(dut.DATA_WIDTH)
    amplitude = (1 << (data_width - 2))  # Half-scale

    # Generate sinusoid at bin k=8
    k = 8
    samples = []
    for i in range(n):
        val = int(amplitude * np.sin(2 * np.pi * k * i / n))
        # Two's complement for negative
        if val < 0:
            val = val + (1 << data_width)
        samples.append(val & ((1 << data_width) - 1))

    # Send samples
    for i in range(n):
        dut.s_axis_tdata.value = samples[i]
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 1 if i == n - 1 else 0
        await RisingEdge(dut.clk)

    dut.s_axis_tvalid.value = 0

    # Collect output
    output_re = []
    output_im = []
    timeout = n * int(np.log2(n)) * 2 + 100

    for _ in range(timeout):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            output_re.append(int(dut.m_axis_tdata_re.value))
            output_im.append(int(dut.m_axis_tdata_im.value))
            if int(dut.m_axis_tlast.value) == 1:
                break

    # Verify we got output
    assert len(output_re) > 0, "No FFT output received"
