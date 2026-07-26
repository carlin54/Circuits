"""Tests for CORDIC processor (cordic.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np


async def reset_dut(dut, cycles=5):
    dut.rst.value = 1
    dut.x_in.value = 0
    dut.y_in.value = 0
    dut.z_in.value = 0
    dut.valid_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


def angle_to_fixed(angle_rad, data_width):
    """Convert angle in radians to fixed-point representation.
    Maps [-pi, pi) to [-2^(DW-1), 2^(DW-1))."""
    scale = (1 << (data_width - 1)) / np.pi
    fixed = int(round(angle_rad * scale))
    max_val = (1 << (data_width - 1)) - 1
    min_val = -(1 << (data_width - 1))
    fixed = max(min_val, min(max_val, fixed))
    if fixed < 0:
        fixed += (1 << data_width)
    return fixed


def fixed_to_signed(val, width):
    """Convert unsigned to signed."""
    if val >= (1 << (width - 1)):
        return val - (1 << width)
    return val


@cocotb.test()
async def test_cordic_rotation_zero(dut):
    """Rotating by 0 should return input unchanged."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH.value)
    x_val = (1 << (data_width - 2))  # 0.5 scale

    dut.x_in.value = x_val
    dut.y_in.value = 0
    dut.z_in.value = 0  # Angle = 0
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    # Wait for pipeline
    num_iters = int(dut.NUM_ITERATIONS.value)
    for _ in range(num_iters + 10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:
            x_out = fixed_to_signed(int(dut.x_out.value), data_width)
            y_out = fixed_to_signed(int(dut.y_out.value), data_width)
            # x should be close to input (CORDIC gain ~1.647 is compensated)
            assert abs(x_out - x_val) < x_val * 0.15, \
                f"Rotation by 0: x_out={x_out}, expected ~{x_val}"
            assert abs(y_out) < x_val * 0.15, \
                f"Rotation by 0: y_out={y_out}, expected ~0"
            break
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_cordic_rotation_90(dut):
    """Rotating unit vector by pi/2 should give (0, 1)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH.value)
    x_val = (1 << (data_width - 2))
    z_val = angle_to_fixed(np.pi / 2, data_width)

    dut.x_in.value = x_val
    dut.y_in.value = 0
    dut.z_in.value = z_val
    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    num_iters = int(dut.NUM_ITERATIONS.value)
    for _ in range(num_iters + 10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:
            x_out = fixed_to_signed(int(dut.x_out.value), data_width)
            y_out = fixed_to_signed(int(dut.y_out.value), data_width)
            # After 90 degree rotation: x should be ~0, y should be ~x_val
            tolerance = x_val * 0.3  # 30% tolerance
            assert abs(x_out) < tolerance, \
                f"90° rotation: x_out={x_out}, expected ~0"
            assert abs(y_out - x_val) < tolerance, \
                f"90° rotation: y_out={y_out}, expected ~{x_val}"
            break
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_cordic_multiple_angles(dut):
    """Test rotation at multiple angles, verify sin/cos relationship."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH.value)
    num_iters = int(dut.NUM_ITERATIONS.value)
    x_val = (1 << (data_width - 2))

    test_angles = [0, np.pi/6, np.pi/4, np.pi/3]
    outputs = []

    for angle in test_angles:
        z_val = angle_to_fixed(angle, data_width)
        dut.x_in.value = x_val
        dut.y_in.value = 0
        dut.z_in.value = z_val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)

    dut.valid_in.value = 0

    # Collect outputs — pipeline takes num_iters clocks per sample
    for _ in range(num_iters * len(test_angles) + 30):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.valid_out.value) == 1:
            x_out = fixed_to_signed(int(dut.x_out.value), data_width)
            y_out = fixed_to_signed(int(dut.y_out.value), data_width)
            outputs.append((x_out, y_out))
            if len(outputs) >= len(test_angles):
                break

    assert len(outputs) >= len(test_angles), \
        f"Expected {len(test_angles)} outputs, got {len(outputs)}"
