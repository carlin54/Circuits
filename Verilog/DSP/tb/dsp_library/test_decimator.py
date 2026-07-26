"""Tests for decimator (decimator.v)."""

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
async def test_decimator_rate_reduction(dut):
    """Output rate should be input_rate / FACTOR."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    factor = int(dut.FACTOR.value)
    data_width = int(dut.DATA_WIDTH.value)
    num_input_samples = factor * 20

    output_count = 0

    # Send input samples and count outputs simultaneously
    for i in range(num_input_samples):
        dut.s_axis_tdata.value = i & ((1 << data_width) - 1)
        dut.s_axis_tvalid.value = 1
        await RisingEdge(dut.clk)
        # Check output on this same clock edge
        if int(dut.m_axis_tvalid.value) == 1:
            output_count += 1

    dut.s_axis_tvalid.value = 0

    # Drain remaining outputs
    for _ in range(factor * 4 + 50):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            output_count += 1

    # Should get approximately num_input_samples / factor outputs
    expected = num_input_samples // factor
    assert abs(output_count - expected) <= 3, \
        f"Decimation rate wrong: got {output_count} outputs, expected ~{expected}"


@cocotb.test()
async def test_decimator_dc_preservation(dut):
    """DC input should produce DC output (with CIC gain)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    factor = int(dut.FACTOR.value)
    data_width = int(dut.DATA_WIDTH.value)
    dc_val = 100

    # Send many DC samples
    for _ in range(factor * 30):
        dut.s_axis_tdata.value = dc_val
        dut.s_axis_tvalid.value = 1
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    # Collect outputs and check steady state
    outputs = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            if val >= (1 << (data_width - 1)):
                val -= (1 << data_width)
            outputs.append(val)

    # After settling, outputs should be approximately constant
    if len(outputs) > 5:
        steady = outputs[-5:]
        variation = max(steady) - min(steady)
        assert variation < abs(steady[0]) * 0.1 + 5, \
            f"DC not preserved: variation={variation}, values={steady}"


@cocotb.test()
async def test_decimator_zero_input(dut):
    """Zero input should give zero output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    factor = int(dut.FACTOR.value)

    for _ in range(factor * 10):
        dut.s_axis_tdata.value = 0
        dut.s_axis_tvalid.value = 1
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    for _ in range(50):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            assert int(dut.m_axis_tdata.value) == 0, "Zero in should give zero out"
