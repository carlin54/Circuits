#!/usr/bin/env python3
"""Generate FIR filter coefficients.

Uses scipy.signal for filter design, quantizes to fixed-point,
outputs hex file for Verilog $readmemh.

Usage:
    python gen_fir_coeffs.py --type lowpass --taps 63 --fc 0.2 --width 16 --frac 15 --output fir_lp.hex
    python gen_fir_coeffs.py --type bandpass --taps 127 --fc 0.1 0.4 --width 16 --frac 15 --output fir_bp.hex
"""

import argparse
import numpy as np
from scipy import signal


def design_filter(filter_type, num_taps, cutoff, window='hamming'):
    """Design FIR filter using windowed sinc method."""
    if filter_type == 'lowpass':
        coeffs = signal.firwin(num_taps, cutoff, window=window)
    elif filter_type == 'highpass':
        coeffs = signal.firwin(num_taps, cutoff, window=window, pass_zero=False)
    elif filter_type == 'bandpass':
        coeffs = signal.firwin(num_taps, cutoff, window=window, pass_zero=False)
    elif filter_type == 'bandstop':
        coeffs = signal.firwin(num_taps, cutoff, window=window)
    else:
        raise ValueError(f"Unknown filter type: {filter_type}")
    return coeffs


def quantize_coefficients(coeffs, width, frac_bits):
    """Quantize floating-point coefficients to fixed-point."""
    scale = 1 << frac_bits
    max_val = (1 << (width - 1)) - 1
    min_val = -(1 << (width - 1))

    quantized = np.round(coeffs * scale).astype(int)
    quantized = np.clip(quantized, min_val, max_val)
    return quantized


def write_hex_file(coeffs_fixed, width, output_file, header_info=""):
    """Write quantized coefficients to hex file."""
    hex_width = (width + 3) // 4

    with open(output_file, 'w') as f:
        if header_info:
            f.write(f"// {header_info}\n")
        f.write(f"// {len(coeffs_fixed)} coefficients, {width}-bit signed\n")
        for c in coeffs_fixed:
            unsigned = c & ((1 << width) - 1)
            f.write(f"{unsigned:0{hex_width}x}\n")

    print(f"Wrote {len(coeffs_fixed)} coefficients to {output_file}")


def main():
    parser = argparse.ArgumentParser(description="Generate FIR filter coefficients")
    parser.add_argument('--type', type=str, default='lowpass',
                        choices=['lowpass', 'highpass', 'bandpass', 'bandstop'])
    parser.add_argument('--taps', type=int, default=63, help='Number of taps')
    parser.add_argument('--fc', type=float, nargs='+', default=[0.2],
                        help='Cutoff frequency (normalized to Nyquist)')
    parser.add_argument('--width', type=int, default=16, help='Bit width')
    parser.add_argument('--frac', type=int, default=15, help='Fractional bits')
    parser.add_argument('--window', type=str, default='hamming',
                        help='Window function')
    parser.add_argument('--output', type=str, default='fir_coeffs.hex')
    parser.add_argument('--plot', action='store_true', help='Plot frequency response')
    args = parser.parse_args()

    cutoff = args.fc if len(args.fc) > 1 else args.fc[0]
    coeffs = design_filter(args.type, args.taps, cutoff, args.window)

    coeffs_fixed = quantize_coefficients(coeffs, args.width, args.frac)

    # Report quantization error
    coeffs_reconstructed = coeffs_fixed / (1 << args.frac)
    max_error = np.max(np.abs(coeffs - coeffs_reconstructed))
    print(f"Max quantization error: {max_error:.6e} ({20*np.log10(max_error):.1f} dB)")

    header = f"{args.type} FIR, {args.taps} taps, fc={args.fc}, {args.window} window"
    write_hex_file(coeffs_fixed, args.width, args.output, header)

    if args.plot:
        import matplotlib.pyplot as plt
        w, h = signal.freqz(coeffs, worN=8000)
        w_q, h_q = signal.freqz(coeffs_reconstructed, worN=8000)

        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
        ax1.plot(w/np.pi, 20*np.log10(np.abs(h)), 'b', label='Float')
        ax1.plot(w_q/np.pi, 20*np.log10(np.abs(h_q)), 'r--', label='Quantized')
        ax1.set_xlabel('Normalized Frequency')
        ax1.set_ylabel('Magnitude (dB)')
        ax1.set_title(f'FIR Filter: {header}')
        ax1.legend()
        ax1.grid(True)
        ax1.set_ylim([-80, 5])

        ax2.stem(range(len(coeffs_fixed)), coeffs_fixed)
        ax2.set_xlabel('Tap Index')
        ax2.set_ylabel('Coefficient Value (fixed-point)')
        ax2.set_title('Quantized Coefficients')
        ax2.grid(True)

        plt.tight_layout()
        plt.savefig(args.output.replace('.hex', '_response.png'), dpi=150)
        print(f"Plot saved to {args.output.replace('.hex', '_response.png')}")


if __name__ == '__main__':
    main()
