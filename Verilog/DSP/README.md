# DSP IP Library + Guitar Amplifier FPGA

A library of reusable DSP IP blocks in Verilog, integrated into a guitar amplifier FPGA application.

## DSP Blocks

See [rtl/dsp_library/](rtl/dsp_library/) for the full library:

- FFT (radix-2 butterfly with bit-reversal and twiddle ROM)
- FIR filter
- IIR biquad filter
- CORDIC
- NCO (numerically controlled oscillator)
- Decimator / Interpolator
- Correlator
- Peak detector
- Magnitude estimator
- Windowing

## Guitar Amplifier Application

See [rtl/guitar_amp/](rtl/guitar_amp/) — a multi-effect audio processing chain:

- Gain stage, compressor, noise gate, limiter
- EQ (parametric), tone stack, wah
- Delay, reverb, chorus, flanger, tremolo
- Pitch shift, cabinet simulator, tuner
- I2S / SPI / UART interfaces

## Common Infrastructure

See [rtl/common/](rtl/common/) — shared building blocks (AXI-Stream interface, FIFOs, RAMs, rounding/saturation).

## Testing

Testbenches use cocotb (Python) — see [tb/](tb/).

```bash
make -C tb/dsp_library
```
