"""Fixed-point conversion utilities for cocotb testbenches."""

import numpy as np
from dataclasses import dataclass


@dataclass
class FixedPointConfig:
    """Configuration for a fixed-point format."""
    data_width: int = 24
    frac_bits: int = 22

    @property
    def int_bits(self):
        return self.data_width - 1 - self.frac_bits

    @property
    def max_val(self):
        return (1 << (self.data_width - 1)) - 1

    @property
    def min_val(self):
        return -(1 << (self.data_width - 1))

    @property
    def max_float(self):
        return self.max_val / (1 << self.frac_bits)

    @property
    def min_float(self):
        return self.min_val / (1 << self.frac_bits)

    @property
    def resolution(self):
        return 1.0 / (1 << self.frac_bits)


def float_to_fixed(value, data_width=24, frac_bits=22):
    """Convert floating-point value(s) to fixed-point integer representation.

    Args:
        value: scalar or numpy array of floats
        data_width: total bit width including sign
        frac_bits: number of fractional bits

    Returns:
        Integer(s) in two's complement fixed-point representation
    """
    scale = 1 << frac_bits
    max_val = (1 << (data_width - 1)) - 1
    min_val = -(1 << (data_width - 1))

    scaled = np.round(np.asarray(value, dtype=np.float64) * scale).astype(np.int64)
    clipped = np.clip(scaled, min_val, max_val)

    # Mask to data_width bits for unsigned representation
    mask = (1 << data_width) - 1
    return (clipped & mask).astype(np.int64)


def fixed_to_float(value, data_width=24, frac_bits=22):
    """Convert fixed-point integer(s) to floating-point.

    Args:
        value: integer(s) in unsigned representation (as read from DUT)
        data_width: total bit width including sign
        frac_bits: number of fractional bits

    Returns:
        Float value(s)
    """
    scale = 1 << frac_bits
    vals = np.asarray(value, dtype=np.int64)

    # Convert from unsigned to signed (two's complement)
    sign_bit = 1 << (data_width - 1)
    mask = (1 << data_width) - 1
    vals = vals & mask
    signed_vals = np.where(vals >= sign_bit, vals - (1 << data_width), vals)

    return signed_vals.astype(np.float64) / scale


def compute_snr(actual, expected):
    """Compute signal-to-noise ratio in dB between actual and expected signals."""
    signal_power = np.mean(expected ** 2)
    noise_power = np.mean((actual - expected) ** 2)
    if noise_power == 0:
        return np.inf
    return 10 * np.log10(signal_power / noise_power)


def max_error_lsb(actual_fixed, expected_fixed):
    """Compute maximum error in LSBs between two fixed-point arrays."""
    return np.max(np.abs(np.asarray(actual_fixed, dtype=np.int64) -
                         np.asarray(expected_fixed, dtype=np.int64)))
