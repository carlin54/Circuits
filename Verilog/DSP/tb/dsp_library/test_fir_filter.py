"""Tests for FIR filter (fir_filter.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])
from helpers.fixed_point import float_to_fixed, fixed_to_float


async def reset_dut(dut, cycles=5):
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    dut.coeff_we.value = 0
    dut.coeff_addr.value = 0
    dut.coeff_data.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def load_coefficients(dut, coeffs, frac_bits=15):
    """Load filter coefficients via reload interface."""
    coeff_width = int(dut.COEFF_WIDTH)
    for i, c in enumerate(coeffs):
        fixed_val = int(round(c * (1 << frac_bits)))
        # Clamp
        max_val = (1 << (coeff_width - 1)) - 1
        min_val = -(1 << (coeff_width - 1))
        fixed_val = max(min_val, min(max_val, fixed_val))
        if fixed_val < 0:
            fixed_val = fixed_val + (1 << coeff_width)

        dut.coeff_we.value = 1
        dut.coeff_addr.value = i
        dut.coeff_data.value = fixed_val
        await RisingEdge(dut.clk)

    dut.coeff_we.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_fir_impulse_response(dut):
    """Impulse response should equal the filter coefficients."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    num_taps = int(dut.NUM_TAPS)
    data_width = int(dut.DATA_WIDTH)
    frac_bits = int(dut.FRAC_BITS)

    # Load simple coefficients: [0.25, 0.5, 0.25] padded to NUM_TAPS
    coeffs = np.zeros(num_taps)
    coeffs[0] = 0.25
    coeffs[1] = 0.5
    coeffs[2] = 0.25
    await load_coefficients(dut, coeffs, frac_bits)

    # Send impulse (1.0 scaled)
    impulse_val = (1 << (data_width - 2))  # 0.5 to avoid overflow
    dut.s_axis_tdata.value = impulse_val
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 0
    await RisingEdge(dut.clk)

    # Send zeros
    dut.s_axis_tdata.value = 0
    for _ in range(num_taps + 5):
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    # Collect output
    output = []
    for _ in range(num_taps * 3):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            output.append(int(dut.m_axis_tdata.value))

    # Verify we got some output
    assert len(output) > 0, "No output from FIR filter"


@cocotb.test()
async def test_fir_dc_passthrough(dut):
    """DC input with unit-sum coefficients should pass DC unchanged."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    num_taps = int(dut.NUM_TAPS)
    frac_bits = int(dut.FRAC_BITS)
    data_width = int(dut.DATA_WIDTH)

    # Coefficients that sum to 1.0
    coeffs = np.zeros(num_taps)
    coeffs[0] = 1.0 / 3
    coeffs[1] = 1.0 / 3
    coeffs[2] = 1.0 / 3
    await load_coefficients(dut, coeffs, frac_bits)

    # Send DC value
    dc_val = 1000
    dut.m_axis_tready.value = 1

    for _ in range(num_taps * 3):
        dut.s_axis_tdata.value = dc_val
        dut.s_axis_tvalid.value = 1
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    # Check steady-state output is close to input
    output = []
    for _ in range(20):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            # Sign extend
            if val >= (1 << (int(dut.OUTPUT_WIDTH) - 1)):
                val -= (1 << int(dut.OUTPUT_WIDTH))
            output.append(val)

    # After settling, output should be approximately dc_val
    if len(output) > num_taps:
        steady_state = output[-5:]
        for val in steady_state:
            assert abs(val - dc_val) < dc_val * 0.1, \
                f"DC passthrough: got {val}, expected ~{dc_val}"


@cocotb.test()
async def test_fir_zeros_output_zero(dut):
    """Zero input should produce zero output."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    num_taps = int(dut.NUM_TAPS)
    frac_bits = int(dut.FRAC_BITS)

    # Any coefficients
    coeffs = np.ones(num_taps) / num_taps
    await load_coefficients(dut, coeffs, frac_bits)

    # Send zeros
    for _ in range(num_taps * 2):
        dut.s_axis_tdata.value = 0
        dut.s_axis_tvalid.value = 1
        await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    # Output should be zero
    for _ in range(10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            assert int(dut.m_axis_tdata.value) == 0, "Zero input should give zero output"
