"""Tests for dual-port RAM (dual_port_ram.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly


async def reset_dut(dut):
    """Initialize RAM control signals."""
    dut.we_a.value = 0
    dut.we_b.value = 0
    dut.addr_a.value = 0
    dut.addr_b.value = 0
    dut.din_a.value = 0
    dut.din_b.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_ram_write_read_port_a(dut):
    """Write via port A, read back via port A."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1
    depth = 1 << int(dut.ADDR_WIDTH.value)
    num_addrs = min(depth, 16)

    # Write
    for addr in range(num_addrs):
        dut.we_a.value = 1
        dut.addr_a.value = addr
        dut.din_a.value = (addr * 7 + 0x123) & data_mask
        await RisingEdge(dut.clk)
    dut.we_a.value = 0

    # Read back (1-cycle read latency from registered output)
    for addr in range(num_addrs):
        dut.addr_a.value = addr
        await RisingEdge(dut.clk)
        await ReadOnly()
        expected = (addr * 7 + 0x123) & data_mask
        got = int(dut.dout_a.value)
        assert got == expected, f"Addr {addr}: got {got:#x}, expected {expected:#x}"
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_ram_write_port_a_read_port_b(dut):
    """Write via port A, read via port B."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1
    depth = 1 << int(dut.ADDR_WIDTH.value)
    num_addrs = min(depth, 16)

    # Write via port A
    for addr in range(num_addrs):
        dut.we_a.value = 1
        dut.addr_a.value = addr
        dut.din_a.value = (addr * 13 + 0x456) & data_mask
        await RisingEdge(dut.clk)
    dut.we_a.value = 0

    # Read via port B
    for addr in range(num_addrs):
        dut.addr_b.value = addr
        await RisingEdge(dut.clk)
        await ReadOnly()
        expected = (addr * 13 + 0x456) & data_mask
        got = int(dut.dout_b.value)
        assert got == expected, f"Port B addr {addr}: got {got:#x}, expected {expected:#x}"
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_ram_simultaneous_access(dut):
    """Simultaneous read/write from different ports to different addresses."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1

    # Write known values first
    dut.we_a.value = 1
    dut.addr_a.value = 0
    dut.din_a.value = 0xAAAA & data_mask
    await RisingEdge(dut.clk)
    dut.addr_a.value = 1
    dut.din_a.value = 0xBBBB & data_mask
    await RisingEdge(dut.clk)
    dut.we_a.value = 0
    await RisingEdge(dut.clk)

    # Simultaneous: write to addr 2 via port A, read addr 0 via port B
    dut.we_a.value = 1
    dut.addr_a.value = 2
    dut.din_a.value = 0xCCCC & data_mask
    dut.addr_b.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()

    got_b = int(dut.dout_b.value)
    expected_b = 0xAAAA & data_mask
    assert got_b == expected_b, f"Simultaneous access: port B got {got_b:#x}, expected {expected_b:#x}"


@cocotb.test()
async def test_ram_all_addresses(dut):
    """Write and read all addresses to verify full depth."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_mask = (1 << int(dut.DATA_WIDTH.value)) - 1
    depth = 1 << int(dut.ADDR_WIDTH.value)

    # Write all
    for addr in range(depth):
        dut.we_a.value = 1
        dut.addr_a.value = addr
        dut.din_a.value = addr & data_mask
        await RisingEdge(dut.clk)
    dut.we_a.value = 0

    # Read all and verify
    errors = 0
    for addr in range(depth):
        dut.addr_a.value = addr
        await RisingEdge(dut.clk)
        await ReadOnly()
        got = int(dut.dout_a.value)
        expected = addr & data_mask
        if got != expected:
            errors += 1
        await RisingEdge(dut.clk)

    assert errors == 0, f"{errors} address(es) failed verification"
