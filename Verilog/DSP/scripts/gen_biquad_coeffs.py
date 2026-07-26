#!/usr/bin/env python3
"""Generate IIR biquad coefficients for tone stack and other filters.

Supports: lowpass, highpass, bandpass, notch, allpass, peaking EQ, low-shelf, high-shelf.
Uses bilinear transform from analog prototypes.

Can generate lookup tables for multiple knob positions (tone stack use case).

Usage:
    python gen_biquad_coeffs.py --type peaking --fc 800 --gain 6 --q 1.5 --sr 48000 --width 18 --frac 16
    python gen_biquad_coeffs.py --tone-stack --sr 48000 --width 18 --frac 16 --steps 16 --output tone_stack.hex
"""

import argparse
import numpy as np
from scipy import signal


def biquad_lowpass(fc, q, fs):
    """Second-order Butterworth low-pass."""
    w0 = 2 * np.pi * fc / fs
    alpha = np.sin(w0) / (2 * q)
    b0 = (1 - np.cos(w0)) / 2
    b1 = 1 - np.cos(w0)
    b2 = (1 - np.cos(w0)) / 2
    a0 = 1 + alpha
    a1 = -2 * np.cos(w0)
    a2 = 1 - alpha
    return np.array([b0, b1, b2]) / a0, np.array([1, a1, a2]) / a0


def biquad_highpass(fc, q, fs):
    """Second-order high-pass."""
    w0 = 2 * np.pi * fc / fs
    alpha = np.sin(w0) / (2 * q)
    b0 = (1 + np.cos(w0)) / 2
    b1 = -(1 + np.cos(w0))
    b2 = (1 + np.cos(w0)) / 2
    a0 = 1 + alpha
    a1 = -2 * np.cos(w0)
    a2 = 1 - alpha
    return np.array([b0, b1, b2]) / a0, np.array([1, a1, a2]) / a0


def biquad_peaking(fc, gain_db, q, fs):
    """Peaking/parametric EQ."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / fs
    alpha = np.sin(w0) / (2 * q)
    b0 = 1 + alpha * A
    b1 = -2 * np.cos(w0)
    b2 = 1 - alpha * A
    a0 = 1 + alpha / A
    a1 = -2 * np.cos(w0)
    a2 = 1 - alpha / A
    return np.array([b0, b1, b2]) / a0, np.array([1, a1, a2]) / a0


def biquad_low_shelf(fc, gain_db, fs, q=0.707):
    """Low-shelf filter."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / fs
    alpha = np.sin(w0) / (2 * q)
    b0 = A * ((A + 1) - (A - 1) * np.cos(w0) + 2 * np.sqrt(A) * alpha)
    b1 = 2 * A * ((A - 1) - (A + 1) * np.cos(w0))
    b2 = A * ((A + 1) - (A - 1) * np.cos(w0) - 2 * np.sqrt(A) * alpha)
    a0 = (A + 1) + (A - 1) * np.cos(w0) + 2 * np.sqrt(A) * alpha
    a1 = -2 * ((A - 1) + (A + 1) * np.cos(w0))
    a2 = (A + 1) + (A - 1) * np.cos(w0) - 2 * np.sqrt(A) * alpha
    return np.array([b0, b1, b2]) / a0, np.array([1, a1, a2]) / a0


def biquad_high_shelf(fc, gain_db, fs, q=0.707):
    """High-shelf filter."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / fs
    alpha = np.sin(w0) / (2 * q)
    b0 = A * ((A + 1) + (A - 1) * np.cos(w0) + 2 * np.sqrt(A) * alpha)
    b1 = -2 * A * ((A - 1) + (A + 1) * np.cos(w0))
    b2 = A * ((A + 1) + (A - 1) * np.cos(w0) - 2 * np.sqrt(A) * alpha)
    a0 = (A + 1) - (A - 1) * np.cos(w0) + 2 * np.sqrt(A) * alpha
    a1 = 2 * ((A - 1) - (A + 1) * np.cos(w0))
    a2 = (A + 1) - (A - 1) * np.cos(w0) - 2 * np.sqrt(A) * alpha
    return np.array([b0, b1, b2]) / a0, np.array([1, a1, a2]) / a0


def generate_tone_stack_lut(fs, width, frac_bits, num_steps, output_file):
    """Generate coefficient lookup table for guitar amp tone stack.

    5 bands: bass (low shelf), mid (peaking), treble (high shelf),
             presence (high shelf), resonance (low shelf).
    Each band has num_steps gain positions from -12dB to +12dB.
    """
    max_val = (1 << (width - 1)) - 1
    min_val = -(1 << (width - 1))
    hex_width = (width + 3) // 4
    scale = 1 << frac_bits

    # Band definitions
    bands = [
        {'name': 'bass', 'type': 'low_shelf', 'fc': 300, 'q': 0.707},
        {'name': 'mid', 'type': 'peaking', 'fc': 800, 'q': 1.5},
        {'name': 'treble', 'type': 'high_shelf', 'fc': 3000, 'q': 0.707},
        {'name': 'presence', 'type': 'high_shelf', 'fc': 5000, 'q': 0.707},
        {'name': 'resonance', 'type': 'low_shelf', 'fc': 100, 'q': 0.707},
    ]

    gains_db = np.linspace(-12, 12, num_steps)

    with open(output_file, 'w') as f:
        f.write(f"// Tone stack biquad coefficients\n")
        f.write(f"// {len(bands)} bands x {num_steps} steps x 5 coeffs (b0,b1,b2,a1,a2)\n")
        f.write(f"// Total entries: {len(bands) * num_steps * 5}\n")
        f.write(f"// Format: {width}-bit signed Q{width-frac_bits-1}.{frac_bits}\n\n")

        for band in bands:
            f.write(f"// Band: {band['name']} (fc={band['fc']}Hz, Q={band['q']})\n")
            for step, gain_db in enumerate(gains_db):
                if band['type'] == 'low_shelf':
                    b, a = biquad_low_shelf(band['fc'], gain_db, fs, band['q'])
                elif band['type'] == 'high_shelf':
                    b, a = biquad_high_shelf(band['fc'], gain_db, fs, band['q'])
                elif band['type'] == 'peaking':
                    b, a = biquad_peaking(band['fc'], gain_db, band['q'], fs)

                # Quantize: b0, b1, b2, a1, a2 (a0 is normalized to 1)
                coeffs = [b[0], b[1], b[2], a[1], a[2]]
                for c in coeffs:
                    fixed = int(np.round(c * scale))
                    fixed = max(min_val, min(max_val, fixed))
                    unsigned = fixed & ((1 << width) - 1)
                    f.write(f"{unsigned:0{hex_width}x}\n")

    total = len(bands) * num_steps * 5
    print(f"Generated tone stack LUT -> {output_file}")
    print(f"  Bands: {', '.join(b['name'] for b in bands)}")
    print(f"  Steps per band: {num_steps}")
    print(f"  Gain range: {gains_db[0]:.1f} to {gains_db[-1]:.1f} dB")
    print(f"  Total entries: {total}")


def main():
    parser = argparse.ArgumentParser(description="Generate biquad coefficients")
    parser.add_argument('--type', type=str, default=None,
                        choices=['lowpass', 'highpass', 'peaking', 'low_shelf', 'high_shelf'])
    parser.add_argument('--fc', type=float, default=1000, help='Center/cutoff frequency')
    parser.add_argument('--gain', type=float, default=0, help='Gain in dB (shelves/peaking)')
    parser.add_argument('--q', type=float, default=0.707, help='Q factor')
    parser.add_argument('--sr', type=int, default=48000, help='Sample rate')
    parser.add_argument('--width', type=int, default=18, help='Coefficient bit width')
    parser.add_argument('--frac', type=int, default=16, help='Fractional bits')
    parser.add_argument('--tone-stack', action='store_true',
                        help='Generate full tone stack LUT')
    parser.add_argument('--steps', type=int, default=16, help='Knob positions for tone stack')
    parser.add_argument('--output', type=str, default='biquad_coeffs.hex')
    args = parser.parse_args()

    if args.tone_stack:
        generate_tone_stack_lut(args.sr, args.width, args.frac, args.steps, args.output)
    elif args.type:
        if args.type == 'lowpass':
            b, a = biquad_lowpass(args.fc, args.q, args.sr)
        elif args.type == 'highpass':
            b, a = biquad_highpass(args.fc, args.q, args.sr)
        elif args.type == 'peaking':
            b, a = biquad_peaking(args.fc, args.gain, args.q, args.sr)
        elif args.type == 'low_shelf':
            b, a = biquad_low_shelf(args.fc, args.gain, args.sr, args.q)
        elif args.type == 'high_shelf':
            b, a = biquad_high_shelf(args.fc, args.gain, args.sr, args.q)

        print(f"Biquad coefficients ({args.type}, fc={args.fc}Hz, Q={args.q}, gain={args.gain}dB):")
        print(f"  b0 = {b[0]:+.8f}")
        print(f"  b1 = {b[1]:+.8f}")
        print(f"  b2 = {b[2]:+.8f}")
        print(f"  a1 = {a[1]:+.8f}")
        print(f"  a2 = {a[2]:+.8f}")

        # Quantize and write
        scale = 1 << args.frac
        max_val = (1 << (args.width - 1)) - 1
        hex_width = (args.width + 3) // 4

        with open(args.output, 'w') as f:
            f.write(f"// {args.type} biquad: fc={args.fc}, Q={args.q}, gain={args.gain}dB\n")
            for name, val in zip(['b0', 'b1', 'b2', 'a1', 'a2'],
                                 [b[0], b[1], b[2], a[1], a[2]]):
                fixed = int(np.round(val * scale))
                fixed = max(-(1 << (args.width-1)), min(max_val, fixed))
                unsigned = fixed & ((1 << args.width) - 1)
                f.write(f"{unsigned:0{hex_width}x}  // {name} = {val:+.6f}\n")
        print(f"Written to {args.output}")
    else:
        parser.error("Specify --type or --tone-stack")


if __name__ == '__main__':
    main()
