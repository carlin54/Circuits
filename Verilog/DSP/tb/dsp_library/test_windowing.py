"""Tests for windowing module (windowing.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np


async def reset_dut(dut, cycles=5):
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
async def test_windowing_unity_passthrough(dut):
    """With unity window coefficients, output should equal input."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    n = int(dut.N)
    data_width = int(dut.DATA_WIDTH)
    test_val = 1000

    # Default coefficients are unity — send constant
    received = []
    for i in range(n):
        dut.s_axis_tdata.value = test_val
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 1 if i == n - 1 else 0
        await RisingEdge(dut.clk)

    dut.s_axis_tvalid.value = 0

    # Collect (allow 2 cycles pipeline latency)
    for _ in range(n + 10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            if val >= (1 << (data_width - 1)):
                val -= (1 << data_width)
            received.append(val)

    # Output should be close to input (within rounding)
    assert len(received) > 0, "No output from windowing"
    for val in received[:n]:
        assert abs(val - test_val) <= 2, f"Unity window: got {val}, expected ~{test_val}"


@cocotb.test()
async def test_windowing_tlast(dut):
    """tlast should propagate and reset sample counter."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    n = int(dut.N)

    # Send a frame with tlast
    for i in range(n):
        dut.s_axis_tdata.value = i + 1
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 1 if i == n - 1 else 0
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    # Check tlast appears in output
    got_last = False
    for _ in range(n + 10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1 and int(dut.m_axis_tlast.value) == 1:
            got_last = True
            break

    assert got_last, "tlast not propagated through windowing"


@cocotb.test()
async def test_windowing_zero_input(dut):
    """Zero input should produce zero output regardless of window."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    n = int(dut.N)

    for i in range(n):
        dut.s_axis_tdata.value = 0
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 1 if i == n - 1 else 0
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    for _ in range(n + 10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            assert int(dut.m_axis_tdata.value) == 0, "0 * window should = 0"
