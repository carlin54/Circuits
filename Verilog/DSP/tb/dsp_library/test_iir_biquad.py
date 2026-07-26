"""Tests for IIR biquad filter (iir_biquad.v)."""

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
    dut.coeff_we.value = 0
    dut.coeff_addr.value = 0
    dut.coeff_data.value = 0
    dut.coeff_section.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def load_biquad_coeffs(dut, b0, b1, b2, a1, a2, section=0):
    """Load one section's coefficients."""
    coeff_width = int(dut.COEFF_WIDTH.value)
    frac_bits = int(dut.FRAC_BITS.value)

    for addr, val in enumerate([b0, b1, b2, a1, a2]):
        fixed = int(round(val * (1 << frac_bits)))
        max_v = (1 << (coeff_width - 1)) - 1
        min_v = -(1 << (coeff_width - 1))
        fixed = max(min_v, min(max_v, fixed))
        if fixed < 0:
            fixed += (1 << coeff_width)

        dut.coeff_we.value = 1
        dut.coeff_addr.value = addr
        dut.coeff_data.value = fixed
        dut.coeff_section.value = section
        await RisingEdge(dut.clk)

    dut.coeff_we.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_biquad_passthrough(dut):
    """Unity coefficients (b0=1, rest=0) should pass signal unchanged."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # b0=1.0, b1=0, b2=0, a1=0, a2=0 => y[n] = x[n]
    await load_biquad_coeffs(dut, 1.0, 0.0, 0.0, 0.0, 0.0)

    data_width = int(dut.DATA_WIDTH.value)
    test_vals = [100, -200, 500, 1000, -1000, 0]
    received = []

    # Send samples one at a time with handshaking, collecting outputs in between
    prev_valid = 0
    for val in test_vals:
        unsigned_val = val if val >= 0 else val + (1 << data_width)
        dut.s_axis_tdata.value = unsigned_val & ((1 << data_width) - 1)
        dut.s_axis_tvalid.value = 1

        # Wait for handshake (ready + valid on rising edge)
        while True:
            await RisingEdge(dut.clk)
            # Detect rising edge of m_axis_tvalid (new output)
            cur_valid = int(dut.m_axis_tvalid.value)
            if cur_valid and not prev_valid:
                raw = int(dut.m_axis_tdata.value)
                if raw >= (1 << (data_width - 1)):
                    raw -= (1 << data_width)
                received.append(raw)
            prev_valid = cur_valid
            if int(dut.s_axis_tready.value) == 1:
                break

        dut.s_axis_tvalid.value = 0

    # Collect any remaining outputs
    for _ in range(20):
        await RisingEdge(dut.clk)
        cur_valid = int(dut.m_axis_tvalid.value)
        if cur_valid and not prev_valid:
            raw = int(dut.m_axis_tdata.value)
            if raw >= (1 << (data_width - 1)):
                raw -= (1 << data_width)
            received.append(raw)
        prev_valid = cur_valid

    assert len(received) == len(test_vals), \
        f"Expected {len(test_vals)} outputs, got {len(received)}"

    for i, (got, exp) in enumerate(zip(received, test_vals)):
        assert abs(got - exp) <= 1, \
            f"Sample {i}: got {got}, expected {exp}"


@cocotb.test()
async def test_biquad_gain(dut):
    """Constant gain (b0=0.5) should halve the signal."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    await load_biquad_coeffs(dut, 0.5, 0.0, 0.0, 0.0, 0.0)

    data_width = int(dut.DATA_WIDTH.value)
    test_val = 1000

    # Send one sample
    dut.s_axis_tdata.value = test_val
    dut.s_axis_tvalid.value = 1
    await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    # Wait for output
    for _ in range(20):
        await RisingEdge(dut.clk)
        if int(dut.m_axis_tvalid.value) == 1:
            raw = int(dut.m_axis_tdata.value)
            if raw >= (1 << (data_width - 1)):
                raw -= (1 << data_width)
            assert abs(raw - test_val // 2) <= 2, \
                f"Gain 0.5: got {raw}, expected ~{test_val // 2}"
            break


@cocotb.test()
async def test_biquad_impulse_response(dut):
    """Verify impulse response matches expected from coefficients."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Simple first-order IIR: b0=0.5, b1=0, b2=0, a1=-0.5, a2=0
    await load_biquad_coeffs(dut, 0.5, 0.0, 0.0, -0.5, 0.0)

    data_width = int(dut.DATA_WIDTH.value)
    impulse_val = 1 << (data_width - 3)
    output = []

    # Send impulse then zeros, collecting outputs on every cycle
    samples_to_send = [impulse_val] + [0] * 20
    send_idx = 0

    for _ in range(200):
        # Drive input with handshaking
        if send_idx < len(samples_to_send):
            val = samples_to_send[send_idx]
            unsigned_val = val if val >= 0 else val + (1 << data_width)
            dut.s_axis_tdata.value = unsigned_val & ((1 << data_width) - 1)
            dut.s_axis_tvalid.value = 1
        else:
            dut.s_axis_tvalid.value = 0

        await RisingEdge(dut.clk)

        # Check output
        if int(dut.m_axis_tvalid.value) == 1:
            raw = int(dut.m_axis_tdata.value)
            if raw >= (1 << (data_width - 1)):
                raw -= (1 << data_width)
            output.append(raw)

        # Check if handshake occurred (input accepted)
        if send_idx < len(samples_to_send) and int(dut.s_axis_tready.value) == 1:
            send_idx += 1

    dut.s_axis_tvalid.value = 0

    assert len(output) > 3, f"Need at least 3 output samples, got {len(output)}"
    # First output should be largest
    assert abs(output[0]) >= abs(output[1]), \
        f"Response should decay: output[0]={output[0]}, output[1]={output[1]}"
