#!/usr/bin/env python3
"""Generate cabinet impulse response files for cab_sim module.

Reads a .wav IR file, truncates/windows to the desired length,
quantizes to fixed-point, and outputs hex for Verilog ROM init.

Can also generate synthetic IRs for testing.

Usage:
    python gen_cab_ir.py --input cab_4x12.wav --length 512 --width 16 --output cab_ir.hex
    python gen_cab_ir.py --synthetic lowpass --length 512 --width 16 --output cab_ir_test.hex
"""

import argparse
import numpy as np
from scipy import signal
from scipy.io import wavfile


def load_ir_from_wav(filename, target_length, target_sr=48000):
    """Load IR from wav file, resample if needed, truncate/pad."""
    sr, data = wavfile.read(filename)

    # Convert to mono float
    if data.ndim > 1:
        data = data[:, 0]
    if data.dtype == np.int16:
        data = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        data = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.float32:
        data = data.astype(np.float64)

    # Resample if different sample rate
    if sr != target_sr:
        num_samples = int(len(data) * target_sr / sr)
        data = signal.resample(data, num_samples)

    # Truncate or pad
    if len(data) > target_length:
        # Apply fade-out window to last 10% to avoid clicks
        fade_len = target_length // 10
        window = np.ones(target_length)
        window[-fade_len:] = np.linspace(1, 0, fade_len)
        data = data[:target_length] * window
    elif len(data) < target_length:
        data = np.pad(data, (0, target_length - len(data)))

    # Normalize
    peak = np.max(np.abs(data))
    if peak > 0:
        data = data / peak * 0.95

    return data


def generate_synthetic_ir(ir_type, length, sample_rate=48000):
    """Generate synthetic IR for testing."""
    if ir_type == 'lowpass':
        # Simple low-pass FIR (simulates dark cabinet)
        coeffs = signal.firwin(length, 4000, fs=sample_rate)
    elif ir_type == 'bandpass':
        # Band-pass (simulates guitar speaker resonance)
        coeffs = signal.firwin(length, [100, 5000], fs=sample_rate, pass_zero=False)
    elif ir_type == 'impulse':
        # Pure impulse (bypass test)
        coeffs = np.zeros(length)
        coeffs[0] = 1.0
    elif ir_type == 'resonant':
        # Resonant peak at ~2.5kHz (classic guitar speaker)
        b, a = signal.iirpeak(2500, 5, fs=sample_rate)
        coeffs = signal.lfilter(b, a, np.concatenate([[1], np.zeros(length-1)]))
        # Truncate and window
        coeffs = coeffs[:length]
        fade_len = length // 10
        coeffs[-fade_len:] *= np.linspace(1, 0, fade_len)
    else:
        raise ValueError(f"Unknown synthetic type: {ir_type}")

    # Normalize
    peak = np.max(np.abs(coeffs))
    if peak > 0:
        coeffs = coeffs / peak * 0.95

    return coeffs


def quantize_and_write(ir_data, width, output_file, info=""):
    """Quantize IR to fixed-point and write hex file."""
    max_val = (1 << (width - 1)) - 1
    min_val = -(1 << (width - 1))
    hex_width = (width + 3) // 4

    quantized = np.round(ir_data * max_val).astype(int)
    quantized = np.clip(quantized, min_val, max_val)

    with open(output_file, 'w') as f:
        f.write(f"// Cabinet IR: {len(quantized)} taps, {width}-bit signed\n")
        if info:
            f.write(f"// {info}\n")
        for val in quantized:
            unsigned = val & ((1 << width) - 1)
            f.write(f"{unsigned:0{hex_width}x}\n")

    print(f"Generated cabinet IR -> {output_file}")
    print(f"  Length: {len(quantized)} taps")
    print(f"  Peak: {np.max(np.abs(ir_data)):.4f}")
    print(f"  RMS: {np.sqrt(np.mean(ir_data**2)):.4f}")
    print(f"  Energy after 50%: {np.sum(ir_data[len(ir_data)//2:]**2)/np.sum(ir_data**2)*100:.1f}%")


def main():
    parser = argparse.ArgumentParser(description="Generate cabinet IR hex files")
    parser.add_argument('--input', type=str, default=None, help='Input .wav file')
    parser.add_argument('--synthetic', type=str, default=None,
                        choices=['lowpass', 'bandpass', 'impulse', 'resonant'],
                        help='Generate synthetic IR')
    parser.add_argument('--length', type=int, default=512, help='IR length (taps)')
    parser.add_argument('--width', type=int, default=16, help='Bit width')
    parser.add_argument('--sr', type=int, default=48000, help='Target sample rate')
    parser.add_argument('--output', type=str, default='cab_ir.hex')
    parser.add_argument('--plot', action='store_true', help='Plot IR and frequency response')
    args = parser.parse_args()

    if args.input:
        ir_data = load_ir_from_wav(args.input, args.length, args.sr)
        info = f"Source: {args.input}"
    elif args.synthetic:
        ir_data = generate_synthetic_ir(args.synthetic, args.length, args.sr)
        info = f"Synthetic: {args.synthetic}"
    else:
        parser.error("Must specify --input or --synthetic")

    quantize_and_write(ir_data, args.width, args.output, info)

    if args.plot:
        import matplotlib.pyplot as plt
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))

        t = np.arange(len(ir_data)) / args.sr * 1000
        ax1.plot(t, ir_data)
        ax1.set_xlabel('Time (ms)')
        ax1.set_ylabel('Amplitude')
        ax1.set_title(f'Cabinet IR ({info})')
        ax1.grid(True)

        f, H = signal.freqz(ir_data, worN=4096, fs=args.sr)
        ax2.semilogx(f[1:], 20*np.log10(np.abs(H[1:])))
        ax2.set_xlabel('Frequency (Hz)')
        ax2.set_ylabel('Magnitude (dB)')
        ax2.set_title('Frequency Response')
        ax2.grid(True)
        ax2.set_xlim([20, args.sr/2])
        ax2.set_ylim([-40, 10])

        plt.tight_layout()
        plt.savefig(args.output.replace('.hex', '.png'), dpi=150)


if __name__ == '__main__':
    main()
