"""Cocotb testbench for eq_parametric.v (multi-band parametric EQ)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

DATA_WIDTH = 24
COEFF_WIDTH = 18
FRAC_BITS = 16


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
    dut.band_freq.value = 0
    dut.band_gain.value = 0
    dut.band_q.value = 0
    dut.coeff_we.value = 0
    dut.coeff_band.value = 0
    dut.coeff_addr.value = 0
    dut.coeff_data.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def write_unity_coeffs(dut, num_bands=4):
    """Write unity (passthrough) coefficients to all bands.
    b0=1.0, b1=0, b2=0, a1=0, a2=0 => y[n] = x[n]
    """
    one_fixed = 1 << FRAC_BITS  # 1.0 in fixed point

    for band in range(num_bands):
        for addr in range(5):
            dut.coeff_we.value = 1
            dut.coeff_band.value = band
            dut.coeff_addr.value = addr
            if addr == 0:  # b0 = 1.0
                dut.coeff_data.value = to_twos_complement(one_fixed, COEFF_WIDTH)
            else:  # b1, b2, a1, a2 = 0
                dut.coeff_data.value = 0
            await RisingEdge(dut.clk)

    dut.coeff_we.value = 0
    await RisingEdge(dut.clk)


async def send_and_collect(dut, values, extra_cycles=20):
    """Send samples and collect outputs."""
    outputs = []
    total = len(values) + extra_cycles

    for i in range(total):
        if i < len(values):
            dut.s_axis_tdata.value = to_twos_complement(values[i])
            dut.s_axis_tvalid.value = 1
            dut.s_axis_tlast.value = int(i == len(values) - 1)
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
async def test_unity_passthrough(dut):
    """With unity coefficients (b0=1, rest=0), output should equal input."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    await write_unity_coeffs(dut)

    # Wait for coefficients to settle
    for _ in range(10):
        await RisingEdge(dut.clk)

    test_values = [int(0.3 * (1 << (DATA_WIDTH-2))),
                   int(-0.2 * (1 << (DATA_WIDTH-2))),
                   int(0.5 * (1 << (DATA_WIDTH-2))),
                   0,
                   int(-0.7 * (1 << (DATA_WIDTH-2)))]

    outputs = await send_and_collect(dut, test_values, extra_cycles=30)

    # With 4 cascaded biquads all set to unity, output = input delayed by 4 cycles
    assert len(outputs) >= len(test_values), \
        f"Expected at least {len(test_values)} outputs, got {len(outputs)}"

    # Check that outputs eventually match inputs (accounting for pipeline delay)
    # The biquads add latency (1 clock per section = 4 total for NUM_BANDS=4)
    for i, expected in enumerate(test_values):
        if i + 4 < len(outputs):
            tolerance = abs(expected) * 0.01 + 4  # 1% + rounding
            assert abs(outputs[i + 4] - expected) <= tolerance, \
                f"Output[{i+4}]={outputs[i+4]} != expected {expected}"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input should produce zero output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    await write_unity_coeffs(dut)

    zeros = [0] * 50
    outputs = await send_and_collect(dut, zeros, extra_cycles=20)

    assert len(outputs) > 0, "No outputs received"
    for out in outputs:
        assert abs(out) <= 1, f"Zero input should give zero output, got {out}"


@cocotb.test()
async def test_ready_signal(dut):
    """Module should assert ready when downstream is ready."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.m_axis_tready.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk)

    assert int(dut.s_axis_tready.value) == 1, \
        "s_axis_tready should be high when m_axis_tready is high"
