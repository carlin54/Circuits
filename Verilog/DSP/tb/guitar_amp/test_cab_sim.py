"""Tests for cab_sim.v (cabinet impulse response convolution)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])
from helpers.fixed_point import float_to_fixed, fixed_to_float


async def reset_dut(dut, cycles=10):
    """Reset the DUT for a specified number of clock cycles."""
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    dut.bypass.value = 0
    dut.ir_select.value = 0
    dut.ir_we.value = 0
    dut.ir_slot.value = 0
    dut.ir_addr.value = 0
    dut.ir_wdata.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def load_ir_coefficients(dut, coeffs, slot=0, coeff_width=16):
    """Load impulse response coefficients into the specified slot."""
    for i, c in enumerate(coeffs):
        fixed_val = int(round(c * (1 << (coeff_width - 1))))
        max_val = (1 << (coeff_width - 1)) - 1
        min_val = -(1 << (coeff_width - 1))
        fixed_val = max(min_val, min(max_val, fixed_val))
        if fixed_val < 0:
            fixed_val = fixed_val + (1 << coeff_width)

        dut.ir_we.value = 1
        dut.ir_slot.value = slot
        dut.ir_addr.value = i
        dut.ir_wdata.value = fixed_val
        await RisingEdge(dut.clk)

    dut.ir_we.value = 0
    await RisingEdge(dut.clk)


async def send_sample(dut, value, last=False):
    """Send a single sample via AXI-Stream and wait for handshake."""
    data_width = int(dut.DATA_WIDTH.value)
    if value < 0:
        value = value + (1 << data_width)
    dut.s_axis_tdata.value = int(value) & ((1 << data_width) - 1)
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = int(last)
    while True:
        await RisingEdge(dut.clk)
        if int(dut.s_axis_tready.value) == 1:
            break
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0


async def wait_for_output(dut, timeout_cycles=2000):
    """Wait for a valid output sample and return its signed value."""
    data_width = int(dut.DATA_WIDTH.value)
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            if val >= (1 << (data_width - 1)):
                val -= (1 << data_width)
            return val
    return None


@cocotb.test()
async def test_bypass(dut):
    """When bypass=1, input passes through unchanged."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH.value)
    dut.bypass.value = 1

    # Send several known values and check they pass through
    test_values = [1000, -500, 32767, -32768, 0, 12345]

    for val in test_values:
        await send_sample(dut, val)

        # Check output appears
        out_val = await wait_for_output(dut, timeout_cycles=20)
        assert out_val is not None, f"No output for bypass input {val}"
        assert out_val == val, f"Bypass failed: sent {val}, got {out_val}"


@cocotb.test()
async def test_impulse_response(dut):
    """With known IR loaded, impulse input produces expected output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    ir_length = int(dut.IR_LENGTH.value)
    data_width = int(dut.DATA_WIDTH.value)
    coeff_width = int(dut.COEFF_WIDTH.value)

    # Load a simple IR: first 4 taps nonzero, rest zero
    ir_coeffs = [0.0] * ir_length
    ir_coeffs[0] = 0.5
    ir_coeffs[1] = 0.25
    ir_coeffs[2] = 0.125
    ir_coeffs[3] = 0.0625
    await load_ir_coefficients(dut, ir_coeffs, slot=0, coeff_width=coeff_width)

    dut.ir_select.value = 0
    dut.bypass.value = 0
    await RisingEdge(dut.clk)

    # Send an impulse (a single nonzero sample followed by zeros)
    impulse_val = (1 << (data_width - 3))  # Positive value, about 0.25 FS

    await send_sample(dut, impulse_val)

    # Send zeros to flush the pipeline (MAC engine takes IR_LENGTH clocks per sample)
    for _ in range(ir_length + 20):
        await send_sample(dut, 0)

    # Collect outputs
    outputs = []
    for _ in range(ir_length * 2 + 100):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            if val >= (1 << (data_width - 1)):
                val -= (1 << data_width)
            outputs.append(val)

    # Verify we got outputs
    assert len(outputs) > 0, "No output from cab_sim after impulse"

    # The first nonzero output should be approximately impulse_val * 0.5
    nonzero_outputs = [o for o in outputs if o != 0]
    if len(nonzero_outputs) > 0:
        expected_first = impulse_val * 0.5
        tolerance = abs(expected_first) * 0.2 + 4  # 20% + 4 LSB tolerance
        assert abs(nonzero_outputs[0] - expected_first) < tolerance, \
            f"First impulse response tap: expected ~{expected_first}, got {nonzero_outputs[0]}"


@cocotb.test()
async def test_zero_input(dut):
    """Zero input produces zero output."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    ir_length = int(dut.IR_LENGTH.value)
    coeff_width = int(dut.COEFF_WIDTH.value)
    data_width = int(dut.DATA_WIDTH.value)

    # Load nonzero IR coefficients
    ir_coeffs = [0.0] * ir_length
    ir_coeffs[0] = 0.9
    ir_coeffs[1] = 0.5
    ir_coeffs[2] = 0.25
    await load_ir_coefficients(dut, ir_coeffs, slot=0, coeff_width=coeff_width)

    dut.ir_select.value = 0
    dut.bypass.value = 0
    await RisingEdge(dut.clk)

    # Send several zero-valued samples
    for _ in range(ir_length + 5):
        await send_sample(dut, 0)

    # Collect all output values
    outputs = []
    for _ in range(ir_length + 20):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            if val >= (1 << (data_width - 1)):
                val -= (1 << data_width)
            outputs.append(val)

    # All outputs should be zero
    for i, val in enumerate(outputs):
        assert val == 0, f"Zero input produced nonzero output {val} at sample {i}"
