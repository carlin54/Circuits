"""Tests for uart_interface.v (UART TX/RX)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Timer
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])

# UART timing constants (matching default parameters)
CLK_FREQ = 100_000_000
BAUD_RATE = 115200
CLKS_PER_BIT = CLK_FREQ // BAUD_RATE  # 868


async def reset_dut(dut, cycles=10):
    """Reset the DUT for a specified number of clock cycles."""
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.uart_rxd.value = 1  # Idle high
    dut.m_axis_tready.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def uart_tx_send(dut, byte_val):
    """Send a byte through the UART TX by asserting s_axis_tdata/tvalid.

    Waits for the TX to accept the data (s_axis_tready).
    """
    dut.s_axis_tdata.value = byte_val & 0xFF
    dut.s_axis_tvalid.value = 1

    # Wait for tready handshake
    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.s_axis_tready.value) == 1:
            break

    # Deassert valid after accepted
    dut.s_axis_tvalid.value = 0


async def capture_uart_txd_frame(dut, clks_per_bit=CLKS_PER_BIT):
    """Capture one UART frame from uart_txd (start + 8 data + stop).

    Returns:
        Tuple (data_byte, frame_valid) where frame_valid checks start/stop bits.
    """
    # Wait for start bit (falling edge on uart_txd)
    timeout = clks_per_bit * 15
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.uart_txd.value) == 0:
            break
    else:
        return None, False

    # We're at the beginning of the start bit.
    # Move to middle of start bit to confirm it's still low
    for _ in range(clks_per_bit // 2):
        await RisingEdge(dut.clk)

    await ReadOnly()
    if int(dut.uart_txd.value) != 0:
        return None, False  # Not a valid start bit

    # Sample 8 data bits at the center of each bit period
    data_byte = 0
    for bit_idx in range(8):
        for _ in range(clks_per_bit):
            await RisingEdge(dut.clk)
        await ReadOnly()
        bit_val = int(dut.uart_txd.value)
        data_byte |= (bit_val << bit_idx)  # LSB first

    # Sample stop bit
    for _ in range(clks_per_bit):
        await RisingEdge(dut.clk)
    await ReadOnly()
    stop_bit = int(dut.uart_txd.value)

    return data_byte, (stop_bit == 1)


async def drive_uart_rxd_frame(dut, byte_val, clks_per_bit=CLKS_PER_BIT):
    """Drive a UART frame into uart_rxd (start + 8 data + stop).

    Sends LSB first as per standard UART.
    """
    # Start bit (low)
    dut.uart_rxd.value = 0
    for _ in range(clks_per_bit):
        await RisingEdge(dut.clk)

    # Data bits (LSB first)
    for bit_idx in range(8):
        bit_val = (byte_val >> bit_idx) & 1
        dut.uart_rxd.value = bit_val
        for _ in range(clks_per_bit):
            await RisingEdge(dut.clk)

    # Stop bit (high)
    dut.uart_rxd.value = 1
    for _ in range(clks_per_bit):
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_tx_byte(dut):
    """Load a byte into s_axis_tdata, assert valid, verify uart_txd produces correct frame."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    test_byte = 0xA5  # 10100101 in binary

    # Start the TX
    await uart_tx_send(dut, test_byte)

    # Capture the UART frame from uart_txd
    data, valid = await capture_uart_txd_frame(dut)

    assert valid, "UART TX frame had invalid start or stop bit"
    assert data == test_byte, \
        f"UART TX mismatch: sent 0x{test_byte:02X}, captured 0x{data:02X}"


@cocotb.test()
async def test_rx_byte(dut):
    """Drive uart_rxd with a valid frame, verify m_axis_tdata/m_axis_tvalid."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    test_byte = 0x3C  # 00111100

    # Ensure RXD is idle high before starting
    dut.uart_rxd.value = 1
    for _ in range(CLKS_PER_BIT * 2):
        await RisingEdge(dut.clk)

    # Drive a UART frame into the RX
    await drive_uart_rxd_frame(dut, test_byte)

    # Wait for the receiver to output the byte via AXI-Stream
    received = False
    received_data = 0
    # Account for synchronizer latency + processing
    for _ in range(CLKS_PER_BIT * 3):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            received_data = int(dut.m_axis_tdata.value)
            received = True
            break

    assert received, "UART RX did not produce m_axis_tvalid after receiving frame"
    assert received_data == test_byte, \
        f"UART RX mismatch: sent 0x{test_byte:02X}, received 0x{received_data:02X}"


@cocotb.test()
async def test_loopback(dut):
    """Connect uart_txd to uart_rxd externally in test, verify data round-trips."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    test_byte = 0x7E

    # Loopback: continuously connect uart_txd to uart_rxd
    async def loopback_driver():
        """Continuously forward uart_txd to uart_rxd with 1 cycle delay."""
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            txd_val = int(dut.uart_txd.value)
            # Drive on next clock edge (small propagation delay)
            dut.uart_rxd.value = txd_val

    loopback = cocotb.start_soon(loopback_driver())

    # Ensure idle state propagates through loopback
    dut.uart_rxd.value = 1
    for _ in range(CLKS_PER_BIT * 2):
        await RisingEdge(dut.clk)

    # Transmit a byte
    await uart_tx_send(dut, test_byte)

    # Wait for full frame to transmit and be received back
    # Total frame: 1 start + 8 data + 1 stop = 10 bit periods
    # Plus synchronizer + processing latency
    received = False
    received_data = 0
    timeout = CLKS_PER_BIT * 25  # Generous timeout

    for _ in range(timeout):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            received_data = int(dut.m_axis_tdata.value)
            received = True
            break

    loopback.kill()

    assert received, "Loopback: no data received after TX"
    assert received_data == test_byte, \
        f"Loopback mismatch: sent 0x{test_byte:02X}, received 0x{received_data:02X}"
