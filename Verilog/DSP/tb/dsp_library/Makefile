# cocotb Makefile for DSP library tests

TOPLEVEL_LANG = verilog
SIM = icarus

RTL_DIR = ../../rtl/dsp_library
RTL_COMMON = ../../rtl/common
FFT_DIR = $(RTL_DIR)/fft

export PYTHONPATH := $(shell pwd)/..:$(shell pwd)/../helpers:$(PYTHONPATH)

# Defaults
TOPLEVEL ?= iir_biquad
MODULE ?= test_iir_biquad
VERILOG_SOURCES ?= $(RTL_DIR)/iir_biquad.v

include $(shell cocotb-config --makefiles)/Makefile.sim

# Convenience targets
.PHONY: test-fft test-fir-filter test-iir-biquad test-cordic test-nco \
        test-windowing test-decimator test-interpolator test-magnitude \
        test-peak-detector test-correlator all-tests

test-fft:
	$(MAKE) sim TOPLEVEL=fft_top MODULE=test_fft \
		VERILOG_SOURCES="$(FFT_DIR)/fft_top.v $(FFT_DIR)/butterfly.v $(FFT_DIR)/twiddle_rom.v $(FFT_DIR)/bit_reversal.v" \
		SIM_BUILD=sim_build_fft

test-fir-filter:
	$(MAKE) sim TOPLEVEL=fir_filter MODULE=test_fir_filter \
		VERILOG_SOURCES="$(RTL_DIR)/fir_filter.v" \
		SIM_BUILD=sim_build_fir

test-iir-biquad:
	$(MAKE) sim TOPLEVEL=iir_biquad MODULE=test_iir_biquad \
		VERILOG_SOURCES="$(RTL_DIR)/iir_biquad.v" \
		SIM_BUILD=sim_build_iir

test-cordic:
	$(MAKE) sim TOPLEVEL=cordic MODULE=test_cordic \
		VERILOG_SOURCES="$(RTL_DIR)/cordic.v" \
		SIM_BUILD=sim_build_cordic

test-nco:
	$(MAKE) sim TOPLEVEL=nco MODULE=test_nco \
		VERILOG_SOURCES="$(RTL_DIR)/nco.v $(RTL_DIR)/cordic.v" \
		SIM_BUILD=sim_build_nco

test-windowing:
	$(MAKE) sim TOPLEVEL=windowing MODULE=test_windowing \
		VERILOG_SOURCES="$(RTL_DIR)/windowing.v" \
		SIM_BUILD=sim_build_windowing

test-decimator:
	$(MAKE) sim TOPLEVEL=decimator MODULE=test_decimator \
		VERILOG_SOURCES="$(RTL_DIR)/decimator.v" \
		SIM_BUILD=sim_build_decimator

test-interpolator:
	$(MAKE) sim TOPLEVEL=interpolator MODULE=test_interpolator \
		VERILOG_SOURCES="$(RTL_DIR)/interpolator.v" \
		SIM_BUILD=sim_build_interpolator

test-magnitude:
	$(MAKE) sim TOPLEVEL=magnitude MODULE=test_magnitude \
		VERILOG_SOURCES="$(RTL_DIR)/magnitude.v $(RTL_DIR)/cordic.v" \
		SIM_BUILD=sim_build_magnitude

test-peak-detector:
	$(MAKE) sim TOPLEVEL=peak_detector MODULE=test_peak_detector \
		VERILOG_SOURCES="$(RTL_DIR)/peak_detector.v" \
		SIM_BUILD=sim_build_peak_detector

test-correlator:
	$(MAKE) sim TOPLEVEL=correlator MODULE=test_correlator \
		VERILOG_SOURCES="$(RTL_DIR)/correlator.v" \
		SIM_BUILD=sim_build_correlator

all-tests: test-fft test-fir-filter test-iir-biquad test-cordic test-nco \
           test-windowing test-decimator test-interpolator test-magnitude \
           test-peak-detector test-correlator
