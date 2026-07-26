"""Audio file I/O helpers for simulation — reads/writes .wav files as fixed-point."""

import numpy as np
from pathlib import Path

try:
    import scipy.io.wavfile as wavfile
except ImportError:
    wavfile = None

from .fixed_point import float_to_fixed, fixed_to_float


def load_wav_as_fixed(filepath, data_width=24, frac_bits=22, mono=True):
    """Load a .wav file and convert to fixed-point representation.

    Args:
        filepath: path to .wav file
        data_width: target fixed-point width
        frac_bits: target fractional bits
        mono: if True, mix stereo to mono

    Returns:
        tuple: (sample_rate, fixed_point_samples as numpy int64 array)
    """
    if wavfile is None:
        raise ImportError("scipy is required for wav file I/O")

    sr, data = wavfile.read(str(filepath))

    # Normalize to [-1.0, 1.0)
    if data.dtype == np.int16:
        float_data = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        float_data = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.float32 or data.dtype == np.float64:
        float_data = data.astype(np.float64)
    else:
        raise ValueError(f"Unsupported wav format: {data.dtype}")

    # Stereo to mono
    if mono and float_data.ndim > 1:
        float_data = np.mean(float_data, axis=1)

    return sr, float_to_fixed(float_data, data_width, frac_bits)


def save_fixed_as_wav(filepath, sample_rate, fixed_data, data_width=24, frac_bits=22):
    """Save fixed-point samples as a .wav file.

    Args:
        filepath: output path
        sample_rate: sample rate in Hz
        fixed_data: numpy array of fixed-point integers
        data_width: bit width used
        frac_bits: fractional bits used
    """
    if wavfile is None:
        raise ImportError("scipy is required for wav file I/O")

    float_data = fixed_to_float(fixed_data, data_width, frac_bits)
    # Clip to [-1, 1) and convert to 16-bit PCM
    float_data = np.clip(float_data, -1.0, 1.0 - 1.0/32768)
    int_data = (float_data * 32768).astype(np.int16)

    wavfile.write(str(filepath), sample_rate, int_data)


def generate_sine(freq_hz, sample_rate, duration_sec, amplitude=0.9,
                  data_width=24, frac_bits=22):
    """Generate a sine wave in fixed-point.

    Returns:
        numpy array of fixed-point integers
    """
    t = np.arange(int(sample_rate * duration_sec)) / sample_rate
    signal = amplitude * np.sin(2 * np.pi * freq_hz * t)
    return float_to_fixed(signal, data_width, frac_bits)


def generate_impulse(length, data_width=24, frac_bits=22):
    """Generate a unit impulse in fixed-point.

    Returns:
        numpy array of fixed-point integers (1.0 at index 0, 0 elsewhere)
    """
    signal = np.zeros(length)
    signal[0] = 1.0 - 2.0**(-frac_bits)  # Just under 1.0 to avoid saturation
    return float_to_fixed(signal, data_width, frac_bits)
