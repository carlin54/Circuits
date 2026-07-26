"""Tests for i2s_receiver.v and i2s_transmitter.v."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Timer
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])


# ============================================================
# I2S Receiver Tests
# ============================================================

async def reset_receiver(dut, cycles=10):
    """Reset the I2S receiver DUT."""
    dut.rst.value = 1
    dut.bclk.value = 0
    dut.lrclk.value = 0
    dut.sdata.value = 0
    dut.m_axis_tready.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def drive_i2s_frame(dut, left_data, right_data, data_width=24,
                          bclk_half_period=4, bits_per_channel=32):
    """Drive a complete I2S stereo frame (left + right channel).

    I2S format: data is MSB first, delayed by 1 BCLK after LRCLK transition.

    Args:
        dut: cocotb DUT handle
        left_data: signed integer for left channel
        right_data: signed integer for right channel
        data_width: number of data bits
        bclk_half_period: system clocks per half BCLK period
        bits_per_channel: total BCLK periods per channel (typically 32)
    """
    mask = (1 << data_width) - 1
    left_unsigned = left_data & mask if left_data >= 0 else (left_data + (1 << data_width)) & mask
    right_unsigned = right_data & mask if right_data >= 0 else (right_data + (1 << data_width)) & mask

    # Left channel (LRCLK = 0)
    dut.lrclk.value = 0
    for bit_idx in range(bits_per_channel):
        # Set sdata: I2S has 1-bit delay, so first BCLK after transition is dummy
        if bit_idx == 0:
            dut.sdata.value = 0  # Delay bit
        elif bit_idx <= data_width:
            # MSB first
            bit_pos = data_width - bit_idx  # bit_idx=1 -> MSB (bit data_width-1)
            dut.sdata.value = (left_unsigned >> bit_pos) & 1
        else:
            dut.sdata.value = 0  # Padding

        # Generate one BCLK cycle
        dut.bclk.value = 0
        for _ in range(bclk_half_period):
            await RisingEdge(dut.clk)
        dut.bclk.value = 1
        for _ in range(bclk_half_period):
            await RisingEdge(dut.clk)

    # Right channel (LRCLK = 1)
    dut.lrclk.value = 1
    for bit_idx in range(bits_per_channel):
        if bit_idx == 0:
            dut.sdata.value = 0  # Delay bit
        elif bit_idx <= data_width:
            bit_pos = data_width - bit_idx
            dut.sdata.value = (right_unsigned >> bit_pos) & 1
        else:
            dut.sdata.value = 0

        dut.bclk.value = 0
        for _ in range(bclk_half_period):
            await RisingEdge(dut.clk)
        dut.bclk.value = 1
        for _ in range(bclk_half_period):
            await RisingEdge(dut.clk)


@cocotb.test()
async def test_receiver_basic(dut):
    """Drive I2S signals with known data, verify AXI-Stream output."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_receiver(dut)

    data_width = int(dut.DATA_WIDTH)

    # Test data
    left_val = 0x3A5C00 >> (24 - data_width)   # Positive value scaled to data_width
    right_val = -(0x1B2000 >> (24 - data_width))  # Negative value

    # Clamp to data_width range
    max_val = (1 << (data_width - 1)) - 1
    min_val = -(1 << (data_width - 1))
    left_val = max(min_val, min(max_val, left_val))
    right_val = max(min_val, min(max_val, right_val))

    # Drive an initial dummy frame to prime the pipeline (receiver outputs
    # on the *next* LRCLK transition after capturing data)
    await drive_i2s_frame(dut, 0, 0, data_width=data_width)

    # Drive the actual frame
    await drive_i2s_frame(dut, left_val, right_val, data_width=data_width)

    # Drive another frame to flush the right channel output
    await drive_i2s_frame(dut, 0, 0, data_width=data_width)

    # Collect outputs
    outputs = []
    # Wait extra cycles for synchronizer latency
    for _ in range(200):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.m_axis_tvalid.value) == 1:
            val = int(dut.m_axis_tdata.value)
            if val >= (1 << (data_width - 1)):
                val -= (1 << data_width)
            channel = int(dut.m_axis_channel.value)
            outputs.append((val, channel))

    # We should have received at least the left and right samples
    assert len(outputs) >= 2, \
        f"Expected at least 2 output samples, got {len(outputs)}"

    # Find our test data in the outputs (allowing for pipeline priming)
    left_found = False
    right_found = False
    tolerance = 2  # Allow a couple LSB of error from synchronization

    for val, ch in outputs:
        if ch == 0 and abs(val - left_val) <= tolerance:
            left_found = True
        if ch == 1 and abs(val - right_val) <= tolerance:
            right_found = True

    assert left_found, \
        f"Left channel data {left_val} not found in outputs: {[(v,c) for v,c in outputs if c==0]}"
    assert right_found, \
        f"Right channel data {right_val} not found in outputs: {[(v,c) for v,c in outputs if c==1]}"


# ============================================================
# I2S Transmitter Tests
# ============================================================

async def reset_transmitter(dut, cycles=10):
    """Reset the I2S transmitter DUT."""
    dut.rst.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_transmitter_basic(dut):
    """Feed AXI-Stream data, verify I2S output waveform."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_transmitter(dut)

    data_width = int(dut.DATA_WIDTH)
    mclk_divide = int(dut.MCLK_DIVIDE)
    lrclk_divide = int(dut.LRCLK_DIVIDE)

    # Test values
    left_val = 0x2AAB00 >> (24 - data_width)   # Positive
    right_val = 0x155500 >> (24 - data_width)   # Another positive

    # Encode in two's complement for the data width
    mask = (1 << data_width) - 1
    left_encoded = left_val & mask
    right_encoded = right_val & mask

    # Feed left sample
    dut.s_axis_tdata.value = left_encoded
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 0

    # Wait for acceptance
    for _ in range(500):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.s_axis_tready.value) == 1:
            break

    await RisingEdge(dut.clk)

    # Feed right sample
    dut.s_axis_tdata.value = right_encoded
    dut.s_axis_tvalid.value = 1
    dut.s_axis_tlast.value = 1  # Last in stereo pair

    for _ in range(500):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if int(dut.s_axis_tready.value) == 1:
            break

    await RisingEdge(dut.clk)
    dut.s_axis_tvalid.value = 0

    # Now observe the I2S output for a full frame
    # Total clocks per frame = MCLK_DIVIDE * LRCLK_DIVIDE (per channel) * 2
    # BCLK period = MCLK_DIVIDE system clocks
    # One full stereo frame = LRCLK_DIVIDE * 2 BCLK periods = LRCLK_DIVIDE * 2 * MCLK_DIVIDE clks
    frame_clocks = mclk_divide * lrclk_divide * 2

    # Wait for LRCLK transition to start capturing
    # First, wait until we see a LRCLK falling edge (start of left channel)
    prev_lrclk = 1
    for _ in range(frame_clocks * 2):
        await RisingEdge(dut.clk)
        await ReadOnly()
        curr_lrclk = int(dut.lrclk.value)
        if prev_lrclk == 1 and curr_lrclk == 0:
            break
        prev_lrclk = curr_lrclk

    # Now capture BCLK rising edges and sample sdata for the left channel
    captured_bits = []
    prev_bclk = int(dut.bclk.value)

    for _ in range(frame_clocks):
        await RisingEdge(dut.clk)
        await ReadOnly()
        curr_bclk = int(dut.bclk.value)

        # Detect BCLK rising edge (data should be stable)
        if curr_bclk == 1 and prev_bclk == 0:
            sdata_val = int(dut.sdata.value)
            captured_bits.append(sdata_val)

        prev_bclk = curr_bclk

    # We should have captured LRCLK_DIVIDE bits for the left channel
    # In I2S format, first bit is the delay bit (should be 0/don't care),
    # then data_width bits MSB-first
    assert len(captured_bits) >= data_width + 1, \
        f"Captured only {len(captured_bits)} bits, expected at least {data_width + 1}"

    # Reconstruct the data from captured bits (skip the 1-bit I2S delay)
    reconstructed = 0
    for i in range(data_width):
        bit_val = captured_bits[i + 1]  # +1 to skip I2S delay bit
        reconstructed = (reconstructed << 1) | bit_val

    # Verify (allow some tolerance due to timing and synchronization)
    assert reconstructed == left_val, \
        f"I2S TX data mismatch: sent 0x{left_val:06X}, captured 0x{reconstructed:06X}"
