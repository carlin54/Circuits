"""Tests for interpolator (interpolator.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly


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
async def test_interpolator_rate_increase(dut):
    """Output rate should be input_rate * FACTOR."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    factor = int(dut.FACTOR)
    num_input_samples = 10

    # Send input samples
    for i in range(num_input_samples):
        dut.s_axis_tdata.value = (i + 1) * 100
        dut.s_axis_tvalid.value = 1

        # Wait for ready
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            if int(dut.s_axis_tready.value) == 1:
                break

    dut.s_axis_tvalid.value = 0

    # Count outputs
    output_count = 0
    for _ in range(num_input_samples * factor * 3):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            output_count += 1

    # Should get factor * num_input_samples outputs
    expected = num_input_samples * factor
    assert output_count >= expected - factor, \
        f"Interpolation: got {output_count}, expected ~{expected}"


@cocotb.test()
async def test_interpolator_zero_input(dut):
    """Zero input should give zero output."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    factor = int(dut.FACTOR)

    for _ in range(5):
        dut.s_axis_tdata.value = 0
        dut.s_axis_tvalid.value = 1
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            if int(dut.s_axis_tready.value) == 1:
                break
    dut.s_axis_tvalid.value = 0

    # All outputs should be zero
    for _ in range(factor * 10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            assert int(dut.m_axis_tdata.value) == 0, "Zero in -> zero out"
