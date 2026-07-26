#!/usr/bin/env python3
"""Generate waveshaping LUTs for guitar amp gain stage.

Curves: clean (linear), soft clip (tanh), hard clip, asymmetric, tube-like.
Each curve maps input [-1, +1] to output [-1, +1] through a nonlinear function.

Usage:
    python gen_waveshape_lut.py --curves all --size 1024 --width 16 --output waveshape.hex
"""

import argparse
import numpy as np


def curve_clean(x):
    """Linear passthrough."""
    return x


def curve_soft_clip(x, gain=4.0):
    """Smooth tanh saturation."""
    return np.tanh(gain * x) / np.tanh(gain)


def curve_hard_clip(x, gain=4.0):
    """Hard clipping (brick wall)."""
    return np.clip(gain * x, -1.0, 1.0)


def curve_asymmetric(x, gain=3.0):
    """Asymmetric clipping (tube-like even harmonics)."""
    pos = np.tanh(gain * x) / np.tanh(gain)
    neg = np.tanh(gain * 0.6 * x) / np.tanh(gain * 0.6)
    return np.where(x >= 0, pos, neg)


def curve_tube(x, gain=3.0):
    """Tube-like transfer function with soft knee."""
    y = np.zeros_like(x)
    for i, xi in enumerate(x):
        if xi >= 0:
            y[i] = 1.0 - np.exp(-gain * xi)
        else:
            y[i] = -(1.0 - np.exp(gain * xi)) * 0.8
    # Normalize
    peak = np.max(np.abs(y))
    if peak > 0:
        y = y / peak
    return y


CURVES = {
    'clean': curve_clean,
    'soft_clip': curve_soft_clip,
    'hard_clip': curve_hard_clip,
    'asymmetric': curve_asymmetric,
    'tube': curve_tube,
}


def generate_waveshape_lut(curves, table_size, width, output_file):
    """Generate waveshaping LUT with multiple curves concatenated."""
    max_val = (1 << (width - 1)) - 1
    min_val = -(1 << (width - 1))
    hex_width = (width + 3) // 4

    # Input range: table addressed by unsigned index 0..table_size-1
    # Maps to input signal range [-1.0, +1.0)
    x = np.linspace(-1.0, 1.0, table_size, endpoint=False)

    with open(output_file, 'w') as f:
        f.write(f"// Waveshaping LUT: {len(curves)} curves x {table_size} entries x {width} bits\n")
        f.write(f"// Curve order: {', '.join(curves)}\n")
        f.write(f"// Total entries: {len(curves) * table_size}\n\n")

        for curve_name in curves:
            curve_fn = CURVES[curve_name]
            y = curve_fn(x)

            # Quantize to signed fixed-point
            quantized = np.round(y * max_val).astype(int)
            quantized = np.clip(quantized, min_val, max_val)

            f.write(f"// Curve: {curve_name}\n")
            for val in quantized:
                unsigned = val & ((1 << width) - 1)
                f.write(f"{unsigned:0{hex_width}x}\n")

    print(f"Generated waveshaping LUT -> {output_file}")
    print(f"  Curves: {', '.join(curves)}")
    print(f"  Table size: {table_size} entries per curve")
    print(f"  Total: {len(curves) * table_size} entries")
    print(f"  Address width needed: {int(np.ceil(np.log2(len(curves) * table_size)))} bits")


def main():
    parser = argparse.ArgumentParser(description="Generate waveshaping LUTs")
    parser.add_argument('--curves', type=str, nargs='+', default=['all'],
                        help='Curves to generate (or "all")')
    parser.add_argument('--size', type=int, default=1024, help='Table entries per curve')
    parser.add_argument('--width', type=int, default=16, help='Output bit width')
    parser.add_argument('--output', type=str, default='waveshape.hex')
    parser.add_argument('--plot', action='store_true', help='Plot curves')
    args = parser.parse_args()

    if 'all' in args.curves:
        curves = list(CURVES.keys())
    else:
        curves = args.curves

    generate_waveshape_lut(curves, args.size, args.width, args.output)

    if args.plot:
        import matplotlib.pyplot as plt
        x = np.linspace(-1.0, 1.0, args.size)
        fig, ax = plt.subplots(1, 1, figsize=(10, 6))
        for name in curves:
            y = CURVES[name](x)
            ax.plot(x, y, label=name)
        ax.set_xlabel('Input')
        ax.set_ylabel('Output')
        ax.set_title('Waveshaping Transfer Functions')
        ax.legend()
        ax.grid(True)
        ax.axhline(y=0, color='k', linewidth=0.5)
        ax.axvline(x=0, color='k', linewidth=0.5)
        plt.tight_layout()
        plt.savefig(args.output.replace('.hex', '.png'), dpi=150)
        print(f"Plot saved to {args.output.replace('.hex', '.png')}")


if __name__ == '__main__':
    main()
