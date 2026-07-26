# Cocotb Makefile for Guitar Amp testbenches
TOPLEVEL_LANG = verilog
SIM = icarus

RTL_DIR = ../../rtl
COMMON_DIR = $(RTL_DIR)/common
EFFECTS_DIR = $(RTL_DIR)/guitar_amp/effects
INTERFACES_DIR = $(RTL_DIR)/guitar_amp/interfaces
AMP_DIR = $(RTL_DIR)/guitar_amp
DSP_DIR = $(RTL_DIR)/dsp_library

export PYTHONPATH := $(shell pwd)/..:$(shell pwd)/../helpers:$(PYTHONPATH)

# Common source files needed by many modules
COMMON_SRCS = $(COMMON_DIR)/dual_port_ram.v \
              $(COMMON_DIR)/single_port_ram.v \
              $(COMMON_DIR)/fifo_sync.v

# Defaults
TOPLEVEL ?= noise_gate
MODULE ?= test_noise_gate
VERILOG_SOURCES ?= $(EFFECTS_DIR)/noise_gate.v

include $(shell cocotb-config --makefiles)/Makefile.sim

# Convenience targets
.PHONY: test-gain-stage test-tone-stack test-reverb test-delay-line \
        test-chorus test-flanger test-compressor test-noise-gate \
        test-cab-sim test-i2s-rx test-i2s-tx test-spi-slave test-uart \
        test-wah test-tremolo test-eq-parametric test-limiter \
        test-tuner test-pitch-shift test-amp-chain all-tests

test-gain-stage:
	$(MAKE) sim TOPLEVEL=gain_stage MODULE=test_gain_stage \
		VERILOG_SOURCES=$(EFFECTS_DIR)/gain_stage.v \
		SIM_BUILD=sim_build_gain_stage

test-tone-stack:
	$(MAKE) sim TOPLEVEL=tone_stack MODULE=test_tone_stack \
		"VERILOG_SOURCES=$(EFFECTS_DIR)/tone_stack.v $(DSP_DIR)/iir_biquad.v" \
		SIM_BUILD=sim_build_tone_stack

test-reverb:
	$(MAKE) sim TOPLEVEL=reverb MODULE=test_reverb \
		VERILOG_SOURCES=$(EFFECTS_DIR)/reverb.v \
		SIM_BUILD=sim_build_reverb

test-delay-line:
	$(MAKE) sim TOPLEVEL=delay_line MODULE=test_delay_line \
		"VERILOG_SOURCES=$(EFFECTS_DIR)/delay_line.v $(COMMON_SRCS)" \
		SIM_BUILD=sim_build_delay_line

test-chorus:
	$(MAKE) sim TOPLEVEL=chorus MODULE=test_chorus \
		VERILOG_SOURCES=$(EFFECTS_DIR)/chorus.v \
		SIM_BUILD=sim_build_chorus

test-flanger:
	$(MAKE) sim TOPLEVEL=flanger MODULE=test_flanger \
		VERILOG_SOURCES=$(EFFECTS_DIR)/flanger.v \
		SIM_BUILD=sim_build_flanger

test-compressor:
	$(MAKE) sim TOPLEVEL=compressor MODULE=test_compressor \
		VERILOG_SOURCES=$(EFFECTS_DIR)/compressor.v \
		SIM_BUILD=sim_build_compressor

test-noise-gate:
	$(MAKE) sim TOPLEVEL=noise_gate MODULE=test_noise_gate \
		VERILOG_SOURCES=$(EFFECTS_DIR)/noise_gate.v \
		SIM_BUILD=sim_build_noise_gate

test-cab-sim:
	$(MAKE) sim TOPLEVEL=cab_sim MODULE=test_cab_sim \
		VERILOG_SOURCES=$(EFFECTS_DIR)/cab_sim.v \
		SIM_BUILD=sim_build_cab_sim

test-i2s-rx:
	$(MAKE) sim TOPLEVEL=i2s_receiver MODULE=test_i2s \
		VERILOG_SOURCES=$(INTERFACES_DIR)/i2s_receiver.v \
		SIM_BUILD=sim_build_i2s_rx

test-i2s-tx:
	$(MAKE) sim TOPLEVEL=i2s_transmitter MODULE=test_i2s \
		VERILOG_SOURCES=$(INTERFACES_DIR)/i2s_transmitter.v \
		SIM_BUILD=sim_build_i2s_tx

test-spi-slave:
	$(MAKE) sim TOPLEVEL=spi_slave MODULE=test_spi_slave \
		VERILOG_SOURCES=$(INTERFACES_DIR)/spi_slave.v \
		SIM_BUILD=sim_build_spi_slave

test-uart:
	$(MAKE) sim TOPLEVEL=uart_interface MODULE=test_uart_interface \
		VERILOG_SOURCES=$(INTERFACES_DIR)/uart_interface.v \
		SIM_BUILD=sim_build_uart

test-wah:
	$(MAKE) sim TOPLEVEL=wah MODULE=test_wah \
		VERILOG_SOURCES=$(EFFECTS_DIR)/wah.v \
		SIM_BUILD=sim_build_wah

test-tremolo:
	$(MAKE) sim TOPLEVEL=tremolo MODULE=test_tremolo \
		VERILOG_SOURCES=$(EFFECTS_DIR)/tremolo.v \
		SIM_BUILD=sim_build_tremolo

test-eq-parametric:
	$(MAKE) sim TOPLEVEL=eq_parametric MODULE=test_eq_parametric \
		"VERILOG_SOURCES=$(EFFECTS_DIR)/eq_parametric.v $(DSP_DIR)/iir_biquad.v" \
		SIM_BUILD=sim_build_eq_parametric

test-limiter:
	$(MAKE) sim TOPLEVEL=limiter MODULE=test_limiter \
		VERILOG_SOURCES=$(EFFECTS_DIR)/limiter.v \
		SIM_BUILD=sim_build_limiter

test-tuner:
	$(MAKE) sim TOPLEVEL=tuner MODULE=test_tuner \
		VERILOG_SOURCES=$(EFFECTS_DIR)/tuner.v \
		SIM_BUILD=sim_build_tuner

test-pitch-shift:
	$(MAKE) sim TOPLEVEL=pitch_shift MODULE=test_pitch_shift \
		VERILOG_SOURCES=$(EFFECTS_DIR)/pitch_shift.v \
		SIM_BUILD=sim_build_pitch_shift

test-amp-chain:
	$(MAKE) sim TOPLEVEL=amp_channel MODULE=test_amp_chain \
		"VERILOG_SOURCES=$(AMP_DIR)/amp_channel.v $(EFFECTS_DIR)/gain_stage.v $(EFFECTS_DIR)/tone_stack.v $(EFFECTS_DIR)/reverb.v $(EFFECTS_DIR)/delay_line.v $(EFFECTS_DIR)/chorus.v $(EFFECTS_DIR)/flanger.v $(EFFECTS_DIR)/compressor.v $(EFFECTS_DIR)/noise_gate.v $(EFFECTS_DIR)/cab_sim.v $(EFFECTS_DIR)/wah.v $(EFFECTS_DIR)/tremolo.v $(EFFECTS_DIR)/eq_parametric.v $(EFFECTS_DIR)/limiter.v $(EFFECTS_DIR)/tuner.v $(EFFECTS_DIR)/pitch_shift.v $(DSP_DIR)/iir_biquad.v $(COMMON_SRCS)" \
		SIM_BUILD=sim_build_amp_chain

all-tests: test-gain-stage test-tone-stack test-reverb test-delay-line \
           test-chorus test-flanger test-compressor test-noise-gate \
           test-cab-sim test-spi-slave test-uart \
           test-wah test-tremolo test-eq-parametric test-limiter \
           test-tuner test-pitch-shift test-amp-chain
