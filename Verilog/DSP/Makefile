# FPGA Signal Processing & Guitar Amp Project
# Open-source toolchain: Icarus Verilog + cocotb + Yosys + nextpnr

TOPLEVEL_LANG = verilog
SIM = icarus

# Python/cocotb
export COCOTB_REDUCED_LOG_FMT = 1
export PYTHONPATH := $(PWD)/scripts:$(PWD)/tb:$(PYTHONPATH)

# Source directories
RTL_COMMON   = rtl/common
RTL_DSP      = rtl/dsp_library
RTL_FFT      = rtl/dsp_library/fft
RTL_AMP      = rtl/guitar_amp
RTL_FX       = rtl/guitar_amp/effects
RTL_IF       = rtl/guitar_amp/interfaces
RTL_TOP      = rtl/top

# All RTL sources
COMMON_SRC   = $(wildcard $(RTL_COMMON)/*.v)
DSP_SRC      = $(wildcard $(RTL_DSP)/*.v) $(wildcard $(RTL_FFT)/*.v)
AMP_SRC      = $(wildcard $(RTL_FX)/*.v) $(wildcard $(RTL_IF)/*.v) $(wildcard $(RTL_AMP)/*.v)
ALL_SRC      = $(COMMON_SRC) $(DSP_SRC) $(AMP_SRC) $(wildcard $(RTL_TOP)/*.v)

# Synthesis target (Lattice ECP5 by default)
SYNTH_DEVICE = LFE5U-45F
SYNTH_PACKAGE = CABGA381
SYNTH_TOP    = system_top

# ============================================================
# Testing
# ============================================================

.PHONY: test test-dsp test-amp test-fft clean synth lint

test: test-dsp test-amp

test-dsp:
	@echo "=== Running DSP library tests ==="
	cd tb/dsp_library && $(MAKE) all

test-amp:
	@echo "=== Running Guitar Amp tests ==="
	cd tb/guitar_amp && $(MAKE) all

test-fft:
	cd tb/dsp_library && $(MAKE) test-fft

# Individual block tests
test-%:
	cd tb/dsp_library && $(MAKE) $@

# ============================================================
# Linting
# ============================================================

lint:
	verilator --lint-only -Wall $(ALL_SRC)

# ============================================================
# Synthesis (Yosys + nextpnr-ecp5)
# ============================================================

synth: synth/$(SYNTH_TOP).bit

synth/$(SYNTH_TOP).json: $(ALL_SRC)
	yosys -p "read_verilog $(ALL_SRC); synth_ecp5 -top $(SYNTH_TOP) -json $@"

synth/$(SYNTH_TOP).config: synth/$(SYNTH_TOP).json synth/constraints.lpf
	nextpnr-ecp5 --$(SYNTH_DEVICE) --package $(SYNTH_PACKAGE) \
		--json $< --lpf synth/constraints.lpf --textcfg $@

synth/$(SYNTH_TOP).bit: synth/$(SYNTH_TOP).config
	ecppack $< --bit $@

# ============================================================
# Utilities
# ============================================================

# Generate coefficient files
gen-coeffs:
	python3 scripts/gen_twiddle.py --output rtl/dsp_library/fft/twiddle.hex
	python3 scripts/gen_fir_coeffs.py --output rtl/dsp_library/fir_coeffs.hex
	python3 scripts/gen_window.py --output rtl/dsp_library/window.hex
	python3 scripts/gen_waveshape_lut.py --output rtl/guitar_amp/effects/waveshape.hex
	python3 scripts/gen_biquad_coeffs.py --tone-stack --output rtl/guitar_amp/effects/tone_coeffs.hex
	python3 scripts/gen_cab_ir.py --synthetic lowpass --output rtl/guitar_amp/effects/cab_ir_default.hex

clean:
	find . -name "*.vcd" -delete
	find . -name "results.xml" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "sim_build" -type d -exec rm -rf {} + 2>/dev/null || true
	rm -f synth/*.json synth/*.config synth/*.bit
