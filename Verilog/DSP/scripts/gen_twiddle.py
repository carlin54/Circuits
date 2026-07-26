#!/usr/bin/env python3
"""Generate twiddle factor ROM files for FFT.

Exploits quarter-wave symmetry: only stores N/4 values.
Output format: hex file loadable by $readmemh.

Usage:
    python gen_twiddle.py --n 1024 --width 16 --frac 14 --output twiddle_1024.hex
"""

import argparse
import numpy as np


def generate_twiddle_factors(n, width, frac_bits, output_file, quarter_wave=True):
    """Generate twiddle factors W_N^k = exp(-j*2*pi*k/N) for k=0..N/4-1."""
    num_points = n // 4 if quarter_wave else n // 2

    max_val = (1 << (width - 1)) - 1
    min_val = -(1 << (width - 1))

    with open(output_file, 'w') as f:
        f.write(f"// Twiddle factors for N={n}, width={width}, frac_bits={frac_bits}\n")
        f.write(f"// Quarter-wave symmetry: {num_points} entries\n")
        f.write(f"// Format: cos (real), sin (imag) interleaved\n")

        for k in range(num_points):
            angle = -2.0 * np.pi * k / n
            cos_val = np.cos(angle)
            sin_val = np.sin(angle)

            # Quantize
            cos_fixed = int(np.round(cos_val * (1 << frac_bits)))
            sin_fixed = int(np.round(sin_val * (1 << frac_bits)))

            # Clamp
            cos_fixed = max(min_val, min(max_val, cos_fixed))
            sin_fixed = max(min_val, min(max_val, sin_fixed))

            # Convert to unsigned hex representation
            cos_hex = cos_fixed & ((1 << width) - 1)
            sin_hex = sin_fixed & ((1 << width) - 1)

            hex_width = (width + 3) // 4
            f.write(f"{cos_hex:0{hex_width}x}\n")
            f.write(f"{sin_hex:0{hex_width}x}\n")

    print(f"Generated {num_points} twiddle factor pairs -> {output_file}")
    print(f"  Max quantization error: {1.0 / (1 << frac_bits):.6e}")


def main():
    parser = argparse.ArgumentParser(description="Generate FFT twiddle factors")
    parser.add_argument('--n', type=int, default=1024, help='FFT size')
    parser.add_argument('--width', type=int, default=16, help='Bit width')
    parser.add_argument('--frac', type=int, default=14, help='Fractional bits')
    parser.add_argument('--output', type=str, default='twiddle.hex', help='Output file')
    parser.add_argument('--full', action='store_true', help='Full table (no quarter-wave)')
    args = parser.parse_args()

    assert args.n & (args.n - 1) == 0, "N must be power of 2"
    assert args.frac < args.width, "Fractional bits must be less than width"

    generate_twiddle_factors(args.n, args.width, args.frac, args.output,
                             quarter_wave=not args.full)


if __name__ == '__main__':
    main()
