"""Tests for peak detector (peak_detector.v)."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly


async def reset_dut(dut, cycles=5):
    dut.rst.value = 1
    dut.data_in.value = 0
    dut.valid_in.value = 0
    dut.last_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_frame_and_get_peak(dut, num_bins, peak_bin, peak_value, bg_value):
    """Send a frame of data with a peak at the given bin and return peak results."""
    for i in range(num_bins):
        val = peak_value if i == peak_bin else bg_value
        dut.data_in.value = val
        dut.valid_in.value = 1
        dut.last_in.value = 1 if i == num_bins - 1 else 0
        await RisingEdge(dut.clk)

    dut.valid_in.value = 0
    dut.last_in.value = 0

    # Check for done — it may fire on the next cycle after last_in
    for _ in range(5):
        await RisingEdge(dut.clk)
        if int(dut.done.value) == 1:
            return int(dut.peak_index.value), int(dut.peak_mag.value)

    return None, None


@cocotb.test()
async def test_peak_single_max(dut):
    """Single peak in the data — should be detected correctly."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    num_bins = int(dut.NUM_BINS.value)
    peak_bin = 42
    peak_value = 5000

    idx, mag = await send_frame_and_get_peak(dut, num_bins, peak_bin, peak_value, 100)

    assert idx is not None, "Done signal never asserted"
    assert idx == peak_bin, \
        f"Peak at wrong bin: got {idx}, expected {peak_bin}"
    assert mag == peak_value, \
        f"Peak value wrong: got {mag}, expected {peak_value}"


@cocotb.test()
async def test_peak_at_first_bin(dut):
    """Peak at bin 0 edge case."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    num_bins = int(dut.NUM_BINS.value)

    idx, mag = await send_frame_and_get_peak(dut, num_bins, 0, 9999, 50)

    assert idx is not None, "Done signal never asserted"
    assert idx == 0, f"Peak should be at bin 0, got {idx}"


@cocotb.test()
async def test_peak_at_last_bin(dut):
    """Peak at last bin edge case."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    num_bins = int(dut.NUM_BINS.value)

    idx, mag = await send_frame_and_get_peak(dut, num_bins, num_bins - 1, 8888, 10)

    assert idx is not None, "Done signal never asserted"
    assert idx == num_bins - 1, \
        f"Peak should be at last bin, got {idx}"


@cocotb.test()
async def test_peak_multiple_frames(dut):
    """Peak detector should work across multiple consecutive frames."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    num_bins = int(dut.NUM_BINS.value)
    peaks_found = []

    for frame in range(3):
        peak_bin = 10 + frame * 20  # Different peak each frame

        idx, mag = await send_frame_and_get_peak(dut, num_bins, peak_bin, 7000, 200)

        if idx is not None:
            peaks_found.append(idx)

        # Gap between frames
        await RisingEdge(dut.clk)

    expected_peaks = [10, 30, 50]
    assert peaks_found == expected_peaks, \
        f"Multi-frame peaks: got {peaks_found}, expected {expected_peaks}"
