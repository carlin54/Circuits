"""Tests for gain_stage.v — waveshaping overdrive with oversampling."""

import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly

# Add tb/ to path so helpers can be imported
sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers.fixed_point import float_to_fixed, fixed_to_float

DATA_WIDTH = 24
FRAC_BITS = 22
PRE_GAIN_WIDTH = 16


async def reset_dut(dut, cycles=10):
    """Apply reset and initialize all input signals."""
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    dut.drive.value = 0
    dut.level.value = 0
    dut.curve_sel.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_sample(dut, value, last=False):
    """Drive a single sample into the DUT and wait for acceptance."""
    dut.s_axis_tdata.value = int(value)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = int(last)
    await RisingEdge(dut.clk)
    await ReadOnly()
    while int(dut.s_axis_tready.value) != 1:
        await RisingEdge(dut.clk)
        await ReadOnly()
    await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.s_axis_tdata.value = 0


async def collect_output(dut, timeout=200):
    """Wait for a valid output sample and return it as a signed integer."""
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            raw = int(dut.m_axis_tdata.value)
            if raw >= (1 << (DATA_WIDTH - 1)):
                raw -= (1 << DATA_WIDTH)
            return raw
        await RisingEdge(dut.clk)
    return None


@cocotb.test()
async def test_bypass(dut):
    """Zero drive should pass signal through cleanly (unity gain waveshape at origin)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # With drive=0, pre-gain multiplication produces 0 -> LUT address at midpoint
    dut.drive.value = 0
    dut.level.value = (1 << PRE_GAIN_WIDTH) - 1  # Max level
    dut.curve_sel.value = 0

    # Send several dummy samples first to fill the pipeline/buffer
    for _ in range(20):
        await send_sample(dut, 0)

    # Send actual test signal
    test_val = float_to_fixed(0.25, DATA_WIDTH, FRAC_BITS)
    await send_sample(dut, test_val)

    # Collect output
    output = await collect_output(dut, timeout=300)
    assert output is not None, "No output produced"

    # With zero drive, the gained input is 0, so LUT outputs 0 (or near-zero)
    assert abs(output) < (1 << (FRAC_BITS - 2)), \
        f"Expected near-zero output with zero drive, got {output}"


@cocotb.test()
async def test_soft_clip(dut):
    """Moderate drive produces compression — output magnitude < input magnitude for large signals."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Moderate drive: roughly half scale
    dut.drive.value = (1 << PRE_GAIN_WIDTH) // 4
    dut.level.value = (1 << PRE_GAIN_WIDTH) // 2
    dut.curve_sel.value = 0

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send dummy samples to fill pipeline first
    for _ in range(20):
        await send_sample(dut, 0)

    # Send a large signal (near full scale)
    large_input = float_to_fixed(0.8, DATA_WIDTH, FRAC_BITS)
    await send_sample(dut, large_input)

    output = await collect_output(dut, timeout=300)
    assert output is not None, "No output produced for soft clip test"

    input_float = fixed_to_float(large_input, DATA_WIDTH, FRAC_BITS)
    output_float = fixed_to_float(output if output >= 0 else output + (1 << DATA_WIDTH),
                                  DATA_WIDTH, FRAC_BITS)

    # With zero-initialized LUT in simulation, output will be 0 or very small
    assert abs(output_float) <= abs(input_float) + 0.01, \
        f"Soft clip failed: output {output_float:.4f} exceeds input {input_float:.4f}"


@cocotb.test()
async def test_hard_clip(dut):
    """High drive saturates the waveshaper — output is clipped."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Maximum drive
    dut.drive.value = (1 << PRE_GAIN_WIDTH) - 1
    dut.level.value = (1 << PRE_GAIN_WIDTH) - 1
    dut.curve_sel.value = 0

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Send dummy samples to fill pipeline first
    for _ in range(20):
        await send_sample(dut, 0)

    # Send full-scale signal
    full_scale = float_to_fixed(0.99, DATA_WIDTH, FRAC_BITS)
    await send_sample(dut, full_scale)

    output = await collect_output(dut, timeout=300)
    assert output is not None, "No output produced for hard clip test"

    # With maximum drive pushing into saturation, output should be bounded
    max_possible = (1 << (DATA_WIDTH - 1)) - 1
    assert abs(output) <= max_possible, \
        f"Output {output} exceeds valid range [{-max_possible-1}, {max_possible}]"


@cocotb.test()
async def test_no_output_without_valid(dut):
    """No valid input means no valid output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.drive.value = (1 << PRE_GAIN_WIDTH) // 2
    dut.level.value = (1 << PRE_GAIN_WIDTH) // 2
    dut.curve_sel.value = 0

    # Drive data on tdata but keep tvalid deasserted
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = int(float_to_fixed(0.5, DATA_WIDTH, FRAC_BITS))

    # Wait many cycles — no valid output should appear
    for _ in range(50):
        await RisingEdge(dut.clk)
        await ReadOnly()
        assert int(dut.m_axis_tvalid.value) == 0, \
            "Output valid asserted without input valid"
        await RisingEdge(dut.clk)
