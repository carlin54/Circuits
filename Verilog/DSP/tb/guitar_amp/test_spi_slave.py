"""Tests for spi_slave.v (SPI register interface, CPOL=0, CPHA=0)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Timer
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])


async def reset_dut(dut, cycles=10):
    """Reset the DUT for a specified number of clock cycles."""
    dut.rst.value = 1
    dut.spi_clk.value = 0
    dut.spi_mosi.value = 0
    dut.spi_cs_n.value = 1
    dut.reg_rdata.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def spi_transfer_byte(dut, byte_val, spi_half_period_clks=8):
    """Transfer one byte over SPI (CPOL=0, CPHA=0: data captured on rising edge).

    Drives MOSI MSB-first, toggles spi_clk, and captures MISO on rising edge.

    Returns:
        8-bit value read from MISO
    """
    miso_byte = 0

    for bit_idx in range(8):
        # Set MOSI on falling edge (data setup before rising edge)
        bit_val = (byte_val >> (7 - bit_idx)) & 1
        dut.spi_mosi.value = bit_val

        # Wait half SPI period (SPI clock low)
        for _ in range(spi_half_period_clks):
            await RisingEdge(dut.clk)

        # Rising edge of SPI clock — data captured by slave, read MISO
        dut.spi_clk.value = 1
        # Wait a few system clocks for synchronizer latency before sampling MISO
        for _ in range(4):
            await RisingEdge(dut.clk)
        await ReadOnly()
        miso_bit = int(dut.spi_miso.value)
        miso_byte = (miso_byte << 1) | miso_bit

        # Wait remainder of high phase
        remaining = spi_half_period_clks - 4
        if remaining > 0:
            for _ in range(remaining):
                await RisingEdge(dut.clk)

        # Falling edge of SPI clock
        dut.spi_clk.value = 0

    return miso_byte


async def spi_write_register(dut, addr, data):
    """Perform a full SPI write transaction: address byte + data byte."""
    # Assert CS
    dut.spi_cs_n.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk)

    # Send address byte: bit7=0 (write), bits[6:0]=addr
    addr_byte = (0 << 7) | (addr & 0x7F)
    await spi_transfer_byte(dut, addr_byte)

    # Send data byte
    await spi_transfer_byte(dut, data & 0xFF)

    # Wait for internal processing
    for _ in range(8):
        await RisingEdge(dut.clk)

    # Deassert CS
    dut.spi_cs_n.value = 1
    for _ in range(8):
        await RisingEdge(dut.clk)


async def spi_read_register(dut, addr, reg_value):
    """Perform a full SPI read transaction."""
    # Set up the register read data
    dut.reg_rdata.value = reg_value & 0xFF

    # Assert CS
    dut.spi_cs_n.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk)

    # Send address byte: bit7=1 (read), bits[6:0]=addr
    addr_byte = (1 << 7) | (addr & 0x7F)
    await spi_transfer_byte(dut, addr_byte)

    # Gap for TX shift register to load after address phase
    for _ in range(12):
        await RisingEdge(dut.clk)

    # Read data byte (send dummy 0x00 on MOSI, capture MISO)
    read_val = await spi_transfer_byte(dut, 0x00)

    # Deassert CS
    dut.spi_cs_n.value = 1
    for _ in range(8):
        await RisingEdge(dut.clk)

    return read_val


@cocotb.test()
async def test_write_register(dut):
    """Send address+data byte via SPI, verify reg_we fires with correct addr/data."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    test_addr = 0x15
    test_data = 0xA3

    # Start a coroutine to monitor reg_we during the transaction
    we_results = []

    async def monitor_we():
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            if int(dut.reg_we.value) == 1:
                we_results.append((int(dut.reg_addr.value), int(dut.reg_wdata.value)))
            await RisingEdge(dut.clk)

    monitor = cocotb.start_soon(monitor_we())

    # Perform the write
    await spi_write_register(dut, test_addr, test_data)

    # Wait a bit for any remaining pulses
    for _ in range(10):
        await RisingEdge(dut.clk)

    monitor.kill()

    assert len(we_results) > 0, "reg_we never asserted during SPI write"
    captured_addr, captured_data = we_results[0]
    assert captured_addr == test_addr, \
        f"Register address mismatch: expected 0x{test_addr:02X}, got 0x{captured_addr:02X}"
    assert captured_data == test_data, \
        f"Register data mismatch: expected 0x{test_data:02X}, got 0x{captured_data:02X}"


@cocotb.test()
async def test_read_register(dut):
    """Send read command, verify MISO returns register data."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    test_addr = 0x2A
    test_rdata = 0xBE

    # Provide the register read data
    dut.reg_rdata.value = test_rdata

    read_val = await spi_read_register(dut, test_addr, test_rdata)

    # The value read should match what we put on reg_rdata
    assert read_val == test_rdata, \
        f"SPI read mismatch: expected 0x{test_rdata:02X}, got 0x{read_val:02X}"


@cocotb.test()
async def test_cs_deassert_resets(dut):
    """CS going high resets the transaction state machine."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Start a transaction but abort mid-byte by deasserting CS
    dut.spi_cs_n.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk)

    # Send only 4 bits of the address byte (partial transfer)
    for bit_idx in range(4):
        dut.spi_mosi.value = 1
        for _ in range(8):
            await RisingEdge(dut.clk)
        dut.spi_clk.value = 1
        for _ in range(8):
            await RisingEdge(dut.clk)
        dut.spi_clk.value = 0

    # Deassert CS mid-transaction
    dut.spi_cs_n.value = 1

    # Wait for synchronizer to propagate
    for _ in range(12):
        await RisingEdge(dut.clk)

    # Now start a new, complete write transaction
    test_addr = 0x07
    test_data = 0x55

    we_results = []

    async def monitor_we():
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            if int(dut.reg_we.value) == 1:
                we_results.append((int(dut.reg_addr.value), int(dut.reg_wdata.value)))
            await RisingEdge(dut.clk)

    monitor = cocotb.start_soon(monitor_we())

    await spi_write_register(dut, test_addr, test_data)

    for _ in range(10):
        await RisingEdge(dut.clk)

    monitor.kill()

    # The second transaction should have completed successfully
    assert len(we_results) > 0, \
        "After CS deassert/reassert, new write did not produce reg_we"
    captured_addr, captured_data = we_results[0]
    assert captured_addr == test_addr, \
        f"After reset, addr mismatch: expected 0x{test_addr:02X}, got 0x{captured_addr:02X}"
    assert captured_data == test_data, \
        f"After reset, data mismatch: expected 0x{test_data:02X}, got 0x{captured_data:02X}"
