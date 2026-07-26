"""Tests for single-port RAM (single_port_ram.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import random


async def reset_dut(dut):
    """Initialize RAM control signals."""
    dut.we.value = 0
    dut.addr.value = 0
    dut.din.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_ram_write_read(dut):
    """Write and read back sequential values."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1
    depth = 1 << int(dut.ADDR_WIDTH.value)
    num_addrs = min(depth, 32)

    # Write
    for addr in range(num_addrs):
        dut.we.value = 1
        dut.addr.value = addr
        dut.din.value = (addr * 11 + 0x55) & data_mask
        await RisingEdge(dut.clk)
    dut.we.value = 0

    # Read (1-cycle latency)
    for addr in range(num_addrs):
        dut.addr.value = addr
        await RisingEdge(dut.clk)
        await ReadOnly()
        expected = (addr * 11 + 0x55) & data_mask
        got = int(dut.dout.value)
        assert got == expected, f"Addr {addr}: got {got:#x}, expected {expected:#x}"
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_ram_overwrite(dut):
    """Overwrite existing data and verify new value."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1

    # Write initial value
    dut.we.value = 1
    dut.addr.value = 5
    dut.din.value = 0x111 & data_mask
    await RisingEdge(dut.clk)

    # Overwrite
    dut.addr.value = 5
    dut.din.value = 0x222 & data_mask
    await RisingEdge(dut.clk)
    dut.we.value = 0

    # Read back
    dut.addr.value = 5
    await RisingEdge(dut.clk)
    await ReadOnly()
    got = int(dut.dout.value)
    expected = 0x222 & data_mask
    assert got == expected, f"Overwrite failed: got {got:#x}, expected {expected:#x}"


@cocotb.test()
async def test_ram_read_during_write(dut):
    """Read output during write cycle (read-first behavior)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1

    # Write a known value to address 3 first
    dut.we.value = 1
    dut.addr.value = 3
    dut.din.value = 0x111 & data_mask
    await RisingEdge(dut.clk)

    # Now write a new value to same address — dout should show the OLD value (read-first)
    dut.din.value = 0xABC & data_mask
    await RisingEdge(dut.clk)
    await ReadOnly()

    got = int(dut.dout.value)
    # Read-first: dout captures mem[addr] BEFORE the write takes effect
    assert got == (0x111 & data_mask), f"Read-during-write (read-first): got {got:#x}, expected 0x111"


@cocotb.test()
async def test_ram_all_addresses(dut):
    """Write and verify every address in the RAM."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1
    depth = 1 << int(dut.ADDR_WIDTH.value)

    # Write all with random-ish pattern
    for addr in range(depth):
        dut.we.value = 1
        dut.addr.value = addr
        dut.din.value = ((addr ^ 0x5A5) * 3) & data_mask
        await RisingEdge(dut.clk)
    dut.we.value = 0

    # Read and verify all
    errors = 0
    for addr in range(depth):
        dut.addr.value = addr
        await RisingEdge(dut.clk)
        await ReadOnly()
        expected = ((addr ^ 0x5A5) * 3) & data_mask
        got = int(dut.dout.value)
        if got != expected:
            errors += 1
        await RisingEdge(dut.clk)

    assert errors == 0, f"{errors}/{depth} addresses failed"


@cocotb.test()
async def test_ram_no_write_without_we(dut):
    """Data should not change when write enable is low."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1

    # Write a value
    dut.we.value = 1
    dut.addr.value = 7
    dut.din.value = 0x999 & data_mask
    await RisingEdge(dut.clk)
    dut.we.value = 0

    # Present different data with WE low
    dut.addr.value = 7
    dut.din.value = 0xFFF & data_mask
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await ReadOnly()

    # Should still be original value
    got = int(dut.dout.value)
    expected = 0x999 & data_mask
    assert got == expected, f"Write without WE: got {got:#x}, expected {expected:#x}"
