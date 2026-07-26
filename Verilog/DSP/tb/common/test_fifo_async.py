"""Tests for asynchronous FIFO (fifo_async.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


async def reset_both(dut, cycles=5):
    """Apply reset on both clock domains."""
    dut.wr_rst.value = 1
    dut.rd_rst.value = 1
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_data.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.wr_clk)
    dut.wr_rst.value = 0
    dut.rd_rst.value = 0
    # Wait for sync stages to settle
    for _ in range(5):
        await RisingEdge(dut.wr_clk)


@cocotb.test()
async def test_async_fifo_empty_after_reset(dut):
    """FIFO should be empty after reset in both domains."""
    # Start clocks at different frequencies to exercise async behavior
    wr_clock = Clock(dut.wr_clk, 10, units="ns")   # 100 MHz write
    rd_clock = Clock(dut.rd_clk, 13, units="ns")   # ~77 MHz read
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())

    await reset_both(dut)
    await ReadOnly()

    assert int(dut.rd_empty.value) == 1, "Should be empty after reset"
    assert int(dut.wr_full.value) == 0, "Should not be full after reset"


@cocotb.test()
async def test_async_fifo_write_read(dut):
    """Write data in write domain, read in read domain."""
    wr_clock = Clock(dut.wr_clk, 10, units="ns")
    rd_clock = Clock(dut.rd_clk, 13, units="ns")
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())

    await reset_both(dut)

    depth = int(dut.DEPTH)
    test_data = list(range(1, depth // 2 + 1))

    # Write data
    for val in test_data:
        dut.wr_data.value = val
        dut.wr_en.value = 1
        await RisingEdge(dut.wr_clk)
    dut.wr_en.value = 0

    # Wait for pointer synchronization (SYNC_STAGES cycles in read domain)
    for _ in range(5):
        await RisingEdge(dut.rd_clk)

    # Read data
    received = []
    for _ in range(len(test_data)):
        await ReadOnly()
        if int(dut.rd_empty.value) == 0:
            dut.rd_en.value = 1
            await ReadOnly()
            received.append(int(dut.rd_data.value))
            await RisingEdge(dut.rd_clk)
        else:
            dut.rd_en.value = 0
            await RisingEdge(dut.rd_clk)

    dut.rd_en.value = 0

    mask = (1 << int(dut.DATA_WIDTH)) - 1
    expected = [v & mask for v in test_data]
    assert received == expected, f"Data mismatch: got {received}, expected {expected}"


@cocotb.test()
async def test_async_fifo_full_flag(dut):
    """Fill FIFO and verify full flag asserts."""
    wr_clock = Clock(dut.wr_clk, 10, units="ns")
    rd_clock = Clock(dut.rd_clk, 13, units="ns")
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())

    await reset_both(dut)

    depth = int(dut.DEPTH)

    # Fill FIFO
    for i in range(depth):
        dut.wr_data.value = i
        dut.wr_en.value = 1
        await RisingEdge(dut.wr_clk)
    dut.wr_en.value = 0

    # Wait for full flag (needs sync stages)
    for _ in range(5):
        await RisingEdge(dut.wr_clk)
    await ReadOnly()

    assert int(dut.wr_full.value) == 1, "FIFO should be full"


@cocotb.test()
async def test_async_fifo_different_rates(dut):
    """Test with write faster than read — FIFO should buffer without data loss."""
    wr_clock = Clock(dut.wr_clk, 8, units="ns")    # 125 MHz (fast writer)
    rd_clock = Clock(dut.rd_clk, 20, units="ns")   # 50 MHz (slow reader)
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())

    await reset_both(dut)

    depth = int(dut.DEPTH)
    num_words = depth // 2  # Don't fill completely
    test_data = list(range(1, num_words + 1))

    # Write burst
    for val in test_data:
        while True:
            await ReadOnly()
            if int(dut.wr_full.value) == 0:
                break
            await RisingEdge(dut.wr_clk)
        dut.wr_data.value = val
        dut.wr_en.value = 1
        await RisingEdge(dut.wr_clk)
    dut.wr_en.value = 0

    # Wait for synchronizers
    for _ in range(10):
        await RisingEdge(dut.rd_clk)

    # Read all
    received = []
    timeout = 100
    while len(received) < num_words and timeout > 0:
        await ReadOnly()
        if int(dut.rd_empty.value) == 0:
            dut.rd_en.value = 1
            received.append(int(dut.rd_data.value))
        else:
            dut.rd_en.value = 0
            timeout -= 1
        await RisingEdge(dut.rd_clk)
    dut.rd_en.value = 0

    mask = (1 << int(dut.DATA_WIDTH)) - 1
    expected = [v & mask for v in test_data]
    assert received == expected, f"Data mismatch with rate difference"
