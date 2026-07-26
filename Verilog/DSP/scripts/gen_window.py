#!/usr/bin/env python3
"""Generate window function LUTs for FFT windowing.

Supports: Hann, Hamming, Blackman, Blackman-Harris, Kaiser, Flat-top.
Output: hex file for Verilog ROM initialization.

Usage:
    python gen_window.py --type hann --length 1024 --width 16 --output hann_1024.hex
"""

import argparse
import numpy as np
from scipy import signal as sig


WINDOW_TYPES = {
    'hann': lambda n: np.hanning(n),
    'hamming': lambda n: np.hamming(n),
    'blackman': lambda n: np.blackman(n),
    'blackman_harris': lambda n: sig.windows.blackmanharris(n),
    'kaiser': lambda n, beta=14: np.kaiser(n, beta),
    'flattop': lambda n: sig.windows.flattop(n),
    'rectangular': lambda n: np.ones(n),
}


def generate_window(window_type, length, width, output_file, beta=14):
    """Generate window coefficients and write to hex file."""
    if window_type == 'kaiser':
        window = WINDOW_TYPES[window_type](length, beta)
    else:
        window = WINDOW_TYPES[window_type](length)

    # Scale to fill the positive range of the fixed-point format
    # Window values are in [0, 1], map to [0, 2^(width-1)-1]
    max_val = (1 << (width - 1)) - 1
    quantized = np.round(window * max_val).astype(int)
    quantized = np.clip(quantized, 0, max_val)

    hex_width = (width + 3) // 4

    with open(output_file, 'w') as f:
        f.write(f"// {window_type} window, length={length}, {width}-bit unsigned\n")
        f.write(f"// Peak value: {max_val} (0x{max_val:0{hex_width}x})\n")
        for val in quantized:
            f.write(f"{val:0{hex_width}x}\n")

    # Stats
    coherent_gain = np.sum(window) / length
    processing_gain = np.sum(window**2) / length
    scallop_loss = 20 * np.log10(np.abs(np.sum(window * np.exp(1j * np.pi * np.arange(length) / length))) / np.sum(window))

    print(f"Generated {window_type} window ({length} points) -> {output_file}")
    print(f"  Coherent gain: {coherent_gain:.4f} ({20*np.log10(coherent_gain):.2f} dB)")
    print(f"  ENBW: {processing_gain/coherent_gain**2:.4f} bins")
    print(f"  Scallop loss: {scallop_loss:.2f} dB")


def main():
    parser = argparse.ArgumentParser(description="Generate window function LUTs")
    parser.add_argument('--type', type=str, default='hann',
                        choices=list(WINDOW_TYPES.keys()))
    parser.add_argument('--length', type=int, default=1024, help='Window length')
    parser.add_argument('--width', type=int, default=16, help='Bit width')
    parser.add_argument('--output', type=str, default='window.hex')
    parser.add_argument('--beta', type=float, default=14, help='Kaiser beta parameter')
    parser.add_argument('--all', action='store_true',
                        help='Generate all window types')
    args = parser.parse_args()

    if args.all:
        for wtype in WINDOW_TYPES:
            outfile = f"{wtype}_{args.length}.hex"
            generate_window(wtype, args.length, args.width, outfile, args.beta)
    else:
        generate_window(args.type, args.length, args.width, args.output, args.beta)


if __name__ == '__main__':
    main()
