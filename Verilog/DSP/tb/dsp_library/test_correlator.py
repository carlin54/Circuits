"""Tests for correlator (correlator.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np


async def reset_dut(dut, cycles=10):
    dut.rst.value = 1
    dut.a_data.value = 0
    dut.a_valid.value = 0
    dut.b_data.value = 0
    dut.b_valid.value = 0
    dut.ref_we.value = 0
    dut.ref_addr.value = 0
    dut.ref_data.value = 0
    dut.lag_select.value = 0
    dut.frame_start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_correlator_self_correlation(dut):
    """Auto-correlation at lag=0 should give maximum energy."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    max_lag = int(dut.MAX_LAG.value)
    data_width = int(dut.DATA_WIDTH.value)
    output_width = int(dut.OUTPUT_WIDTH.value)

    dut.lag_select.value = 0

    # Send same signal to both A and B, checking for corr_valid each cycle
    got_result = False
    corr = 0
    for i in range(max_lag * 2 + 10):
        val = 100 * (1 if (i % 4 < 2) else -1)  # Square wave
        unsigned_val = val if val >= 0 else val + (1 << data_width)
        dut.a_data.value = unsigned_val & ((1 << data_width) - 1)
        dut.b_data.value = unsigned_val & ((1 << data_width) - 1)
        dut.a_valid.value = 1
        dut.b_valid.value = 1
        await RisingEdge(dut.clk)

        # Check if output is valid on this cycle
        if int(dut.corr_valid.value) == 1:
            corr = int(dut.corr_out.value)
            if corr >= (1 << (output_width - 1)):
                corr -= (1 << output_width)
            got_result = True
            break

    dut.a_valid.value = 0
    dut.b_valid.value = 0

    # If not caught during sending, check a few more cycles
    if not got_result:
        for _ in range(10):
            await RisingEdge(dut.clk)
            if int(dut.corr_valid.value) == 1:
                corr = int(dut.corr_out.value)
                if corr >= (1 << (output_width - 1)):
                    corr -= (1 << output_width)
                got_result = True
                break

    assert got_result, "No correlation output received"
    assert corr > 0, f"Auto-correlation at lag 0 should be positive, got {corr}"


@cocotb.test()
async def test_correlator_zero_signal(dut):
    """Correlation with zero signal should be zero."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    max_lag = int(dut.MAX_LAG.value)

    dut.lag_select.value = 0

    got_result = False
    for _ in range(max_lag * 2 + 10):
        dut.a_data.value = 0
        dut.b_data.value = 0
        dut.a_valid.value = 1
        dut.b_valid.value = 1
        await RisingEdge(dut.clk)

        if int(dut.corr_valid.value) == 1:
            assert int(dut.corr_out.value) == 0, "Correlation of zeros should be 0"
            got_result = True
            break

    dut.a_valid.value = 0
    dut.b_valid.value = 0

    if not got_result:
        for _ in range(10):
            await RisingEdge(dut.clk)
            if int(dut.corr_valid.value) == 1:
                assert int(dut.corr_out.value) == 0, "Correlation of zeros should be 0"
                got_result = True
                break

    assert got_result, "No correlation output received"


@cocotb.test()
async def test_correlator_uncorrelated_signals(dut):
    """Correlation between orthogonal signals should be near zero."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    max_lag = int(dut.MAX_LAG.value)
    data_width = int(dut.DATA_WIDTH.value)
    output_width = int(dut.OUTPUT_WIDTH.value)

    dut.lag_select.value = 0

    got_result = False
    corr = 0
    for i in range(max_lag * 2 + 10):
        a_val = 100
        b_val = 100 if (i % 2 == 0) else -100
        b_unsigned = b_val if b_val >= 0 else b_val + (1 << data_width)

        dut.a_data.value = a_val
        dut.b_data.value = b_unsigned & ((1 << data_width) - 1)
        dut.a_valid.value = 1
        dut.b_valid.value = 1
        await RisingEdge(dut.clk)

        if int(dut.corr_valid.value) == 1:
            corr = int(dut.corr_out.value)
            if corr >= (1 << (output_width - 1)):
                corr -= (1 << output_width)
            got_result = True
            break

    dut.a_valid.value = 0
    dut.b_valid.value = 0

    if not got_result:
        for _ in range(10):
            await RisingEdge(dut.clk)
            if int(dut.corr_valid.value) == 1:
                corr = int(dut.corr_out.value)
                if corr >= (1 << (output_width - 1)):
                    corr -= (1 << output_width)
                got_result = True
                break

    assert got_result, "No correlation output received"
    # DC * alternating at lag 0 should sum to ~0 (alternating cancels)
    assert abs(corr) < 100 * 100 * max_lag * 0.1, \
        f"Uncorrelated signals: correlation should be small, got {corr}"
