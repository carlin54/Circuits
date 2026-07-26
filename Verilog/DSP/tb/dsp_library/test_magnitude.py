"""Tests for magnitude calculator (magnitude.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np


async def reset_dut(dut, cycles=5):
    dut.rst.value = 1
    dut.i_in.value = 0
    dut.q_in.value = 0
    dut.valid_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


def to_unsigned(val, width):
    if val < 0:
        return val + (1 << width)
    return val


@cocotb.test()
async def test_magnitude_pure_real(dut):
    """Magnitude of (x, 0) should be |x|."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH)
    test_val = (1 << (data_width - 3))  # Quarter scale positive

    dut.i_in.value = test_val
    dut.q_in.value = 0
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    # Wait for output (CORDIC takes NUM_ITERATIONS cycles)
    for _ in range(50):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:
            mag = int(dut.mag_out.value)
            # Should be close to test_val
            tolerance = test_val * 0.3
            assert abs(mag - test_val) < tolerance, \
                f"Mag of ({test_val}, 0) = {mag}, expected ~{test_val}"
            break


@cocotb.test()
async def test_magnitude_pure_imaginary(dut):
    """Magnitude of (0, y) should be |y|."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH)
    test_val = (1 << (data_width - 3))

    dut.i_in.value = 0
    dut.q_in.value = test_val
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    for _ in range(50):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:
            mag = int(dut.mag_out.value)
            tolerance = test_val * 0.3
            assert abs(mag - test_val) < tolerance, \
                f"Mag of (0, {test_val}) = {mag}, expected ~{test_val}"
            break


@cocotb.test()
async def test_magnitude_equal_components(dut):
    """Magnitude of (x, x) should be x * sqrt(2)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH)
    test_val = (1 << (data_width - 3))
    expected_mag = int(test_val * np.sqrt(2))

    dut.i_in.value = test_val
    dut.q_in.value = test_val
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    for _ in range(50):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:
            mag = int(dut.mag_out.value)
            tolerance = expected_mag * 0.3
            assert abs(mag - expected_mag) < tolerance, \
                f"Mag of ({test_val}, {test_val}) = {mag}, expected ~{expected_mag}"
            break


@cocotb.test()
async def test_magnitude_zero(dut):
    """Magnitude of (0, 0) should be 0."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.i_in.value = 0
    dut.q_in.value = 0
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    for _ in range(50):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:
            mag = int(dut.mag_out.value)
            assert mag < 5, f"Mag of (0,0) should be ~0, got {mag}"
            break
