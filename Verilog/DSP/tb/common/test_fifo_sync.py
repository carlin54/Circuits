"""Tests for synchronous FIFO (fifo_sync.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly


async def reset_dut(dut, cycles=5):
    """Apply reset."""
    dut.rst.value = 1
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_data.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_fifo_empty_on_reset(dut):
    """FIFO should be empty after reset."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    await ReadOnly()

    assert int(dut.empty.value) == 1, "FIFO should be empty after reset"
    assert int(dut.full.value) == 0, "FIFO should not be full after reset"
    assert int(dut.count.value) == 0, "Count should be 0 after reset"


@cocotb.test()
async def test_fifo_write_read_single(dut):
    """Write one word, read it back."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH.value)
    expected = 0xABCDEF & ((1 << data_width) - 1)

    # Write one value
    dut.wr_data.value = expected
    dut.wr_en.value = 1
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()

    assert int(dut.empty.value) == 0, "FIFO should not be empty after write"
    assert int(dut.count.value) == 1, "Count should be 1"

    # rd_data is combinational from mem[rd_ptr] — already valid before rd_en
    rd_val = int(dut.rd_data.value)
    assert rd_val == expected, f"Read {rd_val:#x} != expected {expected:#x}"

    # Now assert rd_en to advance the pointer
    await RisingEdge(dut.clk)
    dut.rd_en.value = 1
    await RisingEdge(dut.clk)
    dut.rd_en.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(dut.empty.value) == 1, "FIFO should be empty after read"


@cocotb.test()
async def test_fifo_fill_to_full(dut):
    """Fill FIFO completely, verify full flag."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    depth = int(dut.DEPTH.value)

    # Fill FIFO
    for i in range(depth):
        dut.wr_data.value = i
        dut.wr_en.value = 1
        await RisingEdge(dut.clk)

    dut.wr_en.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()

    assert int(dut.full.value) == 1, "FIFO should be full"
    assert int(dut.count.value) == depth, f"Count should be {depth}"


@cocotb.test()
async def test_fifo_overflow_protection(dut):
    """Write to full FIFO should not corrupt data."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_width = int(dut.DATA_WIDTH.value)
    depth = int(dut.DEPTH.value)

    # Fill FIFO with known pattern
    for i in range(depth):
        dut.wr_data.value = i + 100
        dut.wr_en.value = 1
        await RisingEdge(dut.clk)

    # Attempt to write when full
    dut.wr_data.value = 0xDEAD
    dut.wr_en.value = 1
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0
    await RisingEdge(dut.clk)

    # Read back all data — should be original pattern
    # rd_data is combinational: shows mem[rd_ptr] immediately
    # Assert rd_en before clock edge to advance pointer
    for i in range(depth):
        await ReadOnly()
        rd_val = int(dut.rd_data.value)
        expected = (i + 100) & ((1 << data_width) - 1)
        assert rd_val == expected, f"Index {i}: got {rd_val}, expected {expected}"
        await RisingEdge(dut.clk)
        dut.rd_en.value = 1  # Will take effect on next rising edge
        await RisingEdge(dut.clk)
        dut.rd_en.value = 0
        await RisingEdge(dut.clk)

    dut.rd_en.value = 0


@cocotb.test()
async def test_fifo_simultaneous_read_write(dut):
    """Simultaneous read and write should maintain count."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Pre-fill with a few values
    for i in range(4):
        dut.wr_data.value = i
        dut.wr_en.value = 1
        await RisingEdge(dut.clk)
    dut.wr_en.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()

    count_before = int(dut.count.value)

    # Simultaneous read and write
    await RisingEdge(dut.clk)
    dut.wr_data.value = 99
    dut.wr_en.value = 1
    dut.rd_en.value = 1
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()

    count_after = int(dut.count.value)
    assert count_after == count_before, \
        f"Count changed during simultaneous R/W: {count_before} -> {count_after}"
