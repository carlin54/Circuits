"""Tests for AXI-Stream interface (axis_interface.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import random


async def reset_dut(dut, cycles=5):
    """Apply reset and initialize signals."""
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
async def test_passthrough_basic(dut):
    """Data passes through the interface correctly."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH)) - 1
    test_data = [0x123456 & data_mask, 0xABCDEF & data_mask, 0x000001, 0x7FFFFF & data_mask]

    received = []
    dut.m_axis_tready.value = 1

    for val in test_data:
        dut.s_axis_tdata.value = val
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 0

        # Wait for ready
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            if int(dut.s_axis_tready.value) == 1:
                break

        # Check output (might be 1 cycle later with registered output)
        for _ in range(3):
            await RisingEdge(dut.clk)
            await ReadOnly()
            if int(dut.m_axis_tvalid.value) == 1:
                received.append(int(dut.m_axis_tdata.value))
                break

    dut.s_axis_tvalid.value = 0

    # Flush pipeline
    for _ in range(5):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            received.append(int(dut.m_axis_tdata.value))

    assert len(received) >= len(test_data), \
        f"Received {len(received)} samples, expected at least {len(test_data)}"
    assert received[:len(test_data)] == test_data, \
        f"Data mismatch: got {[hex(x) for x in received[:len(test_data)]]}"


@cocotb.test()
async def test_backpressure(dut):
    """Deassert tready and verify valid data holds stable."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH)) - 1

    # Send data
    dut.s_axis_tdata.value = 0x42 & data_mask
    dut.s_axis_tvalid.value = 1
    dut.m_axis_tready.value = 1

    # Wait until output valid
    for _ in range(5):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            break

    # Now stall the output
    dut.m_axis_tready.value = 0
    dut.s_axis_tdata.value = 0xFF & data_mask  # Change input
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await ReadOnly()

    # Output should hold the original valid data
    if int(dut.m_axis_tvalid.value) == 1:
        held_val = int(dut.m_axis_tdata.value)
        assert held_val == (0x42 & data_mask), \
            f"Data not held during backpressure: got {held_val:#x}"


@cocotb.test()
async def test_tlast_propagation(dut):
    """tlast signal propagates through the pipeline."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.m_axis_tready.value = 1

    # Send with tlast
    dut.s_axis_tdata.value = 0x55
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 1

    # Wait for output
    for _ in range(5):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            assert int(dut.m_axis_tlast.value) == 1, "tlast not propagated"
            break
    else:
        assert False, "No valid output within 5 cycles"

    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0


@cocotb.test()
async def test_burst_with_backpressure(dut):
    """Send a burst of data with random backpressure, verify all data arrives."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH)) - 1
    test_data = [(i * 7 + 3) & data_mask for i in range(20)]
    sent_idx = 0
    received = []

    for cycle in range(200):
        # Random backpressure
        dut.m_axis_tready.value = int(random.random() > 0.3)

        # Drive input when ready
        await ReadOnly()
        if sent_idx < len(test_data) and int(dut.s_axis_tready.value) == 1:
            dut.s_axis_tdata.value = test_data[sent_idx]
            dut.s_axis_tvalid.value = 1
            dut.s_axis_tlast.value = int(sent_idx == len(test_data) - 1)
            sent_idx += 1
        elif sent_idx >= len(test_data):
            dut.s_axis_tvalid.value = 0

        # Capture output
        if int(dut.m_axis_tvalid.value) == 1 and int(dut.m_axis_tready.value) == 1:
            received.append(int(dut.m_axis_tdata.value))

        await RisingEdge(dut.clk)

        if len(received) >= len(test_data):
            break

    assert received == test_data, \
        f"Burst data mismatch: received {len(received)}/{len(test_data)} items"


@cocotb.test()
async def test_no_data_when_invalid(dut):
    """No data transfer should occur when tvalid is low."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.m_axis_tready.value = 1
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0xDEAD

    # Wait several cycles
    for _ in range(10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        assert int(dut.m_axis_tvalid.value) == 0, \
            "Output valid asserted with no input valid"
