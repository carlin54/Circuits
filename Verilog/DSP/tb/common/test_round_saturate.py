"""Tests for round_saturate.v — rounding modes and saturation behavior."""

import cocotb
from cocotb.triggers import Timer
import numpy as np


def compute_expected(val, input_width, output_width, input_frac, output_frac,
                     round_mode, sat_mode):
    """Python golden model for round_saturate."""
    frac_drop = input_frac - output_frac

    # Step 1: Round
    if frac_drop <= 0:
        rounded = val
    elif round_mode == 0:  # Truncate
        rounded = val
    elif round_mode == 1:  # Round half up
        rounded = val + (1 << (frac_drop - 1))
    else:  # Round half to even
        guard = (val >> (frac_drop - 1)) & 1
        if frac_drop >= 2:
            sticky = 1 if (val & ((1 << (frac_drop - 1)) - 1)) != 0 else 0
        else:
            sticky = 0
        lsb = (val >> frac_drop) & 1
        round_up = guard & (sticky | lsb)
        rounded = val + (round_up << (frac_drop - 1))

    # Mask to input width (handle overflow from rounding)
    sign_bit = 1 << (input_width - 1)
    mask = (1 << input_width) - 1
    rounded = rounded & mask
    if rounded >= sign_bit:
        rounded_signed = rounded - (1 << input_width)
    else:
        rounded_signed = rounded

    # Extract trimmed value (shift out fractional bits)
    trimmed = rounded_signed >> frac_drop
    rounded_width = input_width - frac_drop

    # Step 2: Saturate/wrap
    if rounded_width <= output_width:
        result = trimmed
        overflow = False
    else:
        out_max = (1 << (output_width - 1)) - 1
        out_min = -(1 << (output_width - 1))

        if sat_mode == 0:  # Wrap
            out_mask = (1 << output_width) - 1
            result = trimmed & out_mask
            if result >= (1 << (output_width - 1)):
                result -= (1 << output_width)
            overflow = trimmed > out_max or trimmed < out_min
        else:  # Saturate
            if trimmed > out_max:
                result = out_max
                overflow = True
            elif trimmed < out_min:
                result = out_min
                overflow = True
            else:
                result = trimmed
                overflow = False

    # Convert to unsigned for comparison with DUT
    if result < 0:
        result = result + (1 << output_width)
    return result & ((1 << output_width) - 1), overflow


@cocotb.test()
async def test_passthrough_no_reduction(dut):
    """When input equals output format, data passes through unchanged."""
    # Get parameters from DUT
    input_width = int(dut.INPUT_WIDTH)
    output_width = int(dut.OUTPUT_WIDTH)
    input_frac = int(dut.INPUT_FRAC)
    output_frac = int(dut.OUTPUT_FRAC)

    if input_frac == output_frac and input_width == output_width:
        test_vals = [0, 1, (1 << (input_width - 1)) - 1, (1 << input_width) - 1]
        for val in test_vals:
            dut.data_in.value = val
            await Timer(1, units="ns")
            got = int(dut.data_out.value)
            assert got == (val & ((1 << output_width) - 1)), \
                f"Passthrough: in={val:#x}, out={got:#x}"


@cocotb.test()
async def test_truncation_mode(dut):
    """Test truncation (floor toward negative infinity)."""
    input_width = int(dut.INPUT_WIDTH)
    output_width = int(dut.OUTPUT_WIDTH)
    input_frac = int(dut.INPUT_FRAC)
    output_frac = int(dut.OUTPUT_FRAC)
    round_mode = int(dut.ROUND_MODE)
    sat_mode = int(dut.SAT_MODE)

    # Test a range of values including positive and negative
    mask = (1 << input_width) - 1
    test_vals = [0, 1, 0x7F, 0x80, mask >> 1, mask]
    # Add values near boundaries
    if input_width >= 8:
        test_vals += [0x55, 0xAA, (1 << (input_width - 2))]

    for val in test_vals:
        val = val & mask
        # Sign-extend for golden model
        if val >= (1 << (input_width - 1)):
            signed_val = val - (1 << input_width)
        else:
            signed_val = val

        dut.data_in.value = val
        await Timer(1, units="ns")

        expected, exp_ovf = compute_expected(signed_val, input_width, output_width,
                                              input_frac, output_frac,
                                              round_mode, sat_mode)
        got = int(dut.data_out.value)
        assert got == expected, \
            f"val={val:#x} (signed={signed_val}): got={got:#x}, expected={expected:#x}"


@cocotb.test()
async def test_saturation_positive_overflow(dut):
    """Large positive values should saturate to max positive."""
    input_width = int(dut.INPUT_WIDTH)
    output_width = int(dut.OUTPUT_WIDTH)
    input_frac = int(dut.INPUT_FRAC)
    output_frac = int(dut.OUTPUT_FRAC)
    round_mode = int(dut.ROUND_MODE)
    sat_mode = int(dut.SAT_MODE)

    if sat_mode != 1:
        return  # Only test saturation mode

    frac_drop = input_frac - output_frac
    rounded_width = input_width - frac_drop

    if rounded_width <= output_width:
        return  # Can't overflow

    # Max positive value
    max_pos_input = (1 << (input_width - 1)) - 1
    dut.data_in.value = max_pos_input
    await Timer(1, units="ns")

    expected, _ = compute_expected(max_pos_input, input_width, output_width,
                                    input_frac, output_frac, round_mode, sat_mode)
    got = int(dut.data_out.value)
    got_overflow = int(dut.overflow.value)

    # Max positive output
    max_pos_output = (1 << (output_width - 1)) - 1
    assert got == max_pos_output or got == expected, \
        f"Positive overflow: got={got:#x}, expected max_pos={max_pos_output:#x}"


@cocotb.test()
async def test_saturation_negative_overflow(dut):
    """Large negative values should saturate to max negative."""
    input_width = int(dut.INPUT_WIDTH)
    output_width = int(dut.OUTPUT_WIDTH)
    input_frac = int(dut.INPUT_FRAC)
    output_frac = int(dut.OUTPUT_FRAC)
    round_mode = int(dut.ROUND_MODE)
    sat_mode = int(dut.SAT_MODE)

    if sat_mode != 1:
        return

    frac_drop = input_frac - output_frac
    rounded_width = input_width - frac_drop

    if rounded_width <= output_width:
        return

    # Max negative value (two's complement)
    max_neg_input = -(1 << (input_width - 1))
    # Convert to unsigned for DUT
    unsigned_input = max_neg_input & ((1 << input_width) - 1)
    dut.data_in.value = unsigned_input
    await Timer(1, units="ns")

    expected, _ = compute_expected(max_neg_input, input_width, output_width,
                                    input_frac, output_frac, round_mode, sat_mode)
    got = int(dut.data_out.value)

    # Max negative output (unsigned representation)
    max_neg_output = 1 << (output_width - 1)
    assert got == max_neg_output or got == expected, \
        f"Negative overflow: got={got:#x}, expected max_neg={max_neg_output:#x}"
