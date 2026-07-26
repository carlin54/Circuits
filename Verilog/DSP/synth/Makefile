# Synthesis Makefile for Lattice ECP5
# Toolchain: Yosys -> nextpnr-ecp5 -> ecppack

DEVICE = 85k
PACKAGE = CABGA381
SPEED = 6

TOP = system_top
CONSTRAINTS = constraints.lpf

# Source files
RTL_DIR = ../rtl
COMMON_SRC = $(wildcard $(RTL_DIR)/common/*.v)
DSP_SRC = $(wildcard $(RTL_DIR)/dsp_library/*.v) $(wildcard $(RTL_DIR)/dsp_library/fft/*.v)
AMP_SRC = $(wildcard $(RTL_DIR)/guitar_amp/effects/*.v) \
           $(wildcard $(RTL_DIR)/guitar_amp/interfaces/*.v) \
           $(RTL_DIR)/guitar_amp/amp_channel.v \
           $(RTL_DIR)/guitar_amp/guitar_amp_top.v
TOP_SRC = $(RTL_DIR)/top/system_top.v

ALL_SRC = $(COMMON_SRC) $(DSP_SRC) $(AMP_SRC) $(TOP_SRC)

# Output directory
BUILD_DIR = build
JSON = $(BUILD_DIR)/$(TOP).json
ASC = $(BUILD_DIR)/$(TOP).config
BIT = $(BUILD_DIR)/$(TOP).bit
SVG = $(BUILD_DIR)/$(TOP).svg

.PHONY: all synth pnr bitstream prog clean stats show

all: bitstream

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Synthesis (Yosys)
synth: $(JSON)
$(JSON): $(ALL_SRC) | $(BUILD_DIR)
	yosys -p "read_verilog -DSYNTHESIS $(ALL_SRC); \
	           synth_ecp5 -top $(TOP) -json $@"

# Place and Route (nextpnr)
pnr: $(ASC)
$(ASC): $(JSON) $(CONSTRAINTS)
	nextpnr-ecp5 --$(DEVICE) \
	             --package $(PACKAGE) \
	             --speed $(SPEED) \
	             --json $(JSON) \
	             --textcfg $@ \
	             --lpf $(CONSTRAINTS) \
	             --freq 100 \
	             --timing-allow-fail

# Bitstream generation
bitstream: $(BIT)
$(BIT): $(ASC)
	ecppack --compress --svf $(BUILD_DIR)/$(TOP).svf $< $@

# Program the FPGA via JTAG
prog: $(BIT)
	openFPGALoader -b ulx3s $(BIT)

# Program to flash (persistent)
prog-flash: $(BIT)
	openFPGALoader -b ulx3s -f $(BIT)

# Resource utilization report
stats: $(JSON)
	yosys -p "read_verilog -DSYNTHESIS $(ALL_SRC); \
	           synth_ecp5 -top $(TOP); \
	           stat"

# Generate gate-level SVG diagram
show: $(JSON)
	yosys -p "read_verilog -DSYNTHESIS $(ALL_SRC); \
	           synth_ecp5 -top $(TOP); \
	           show -format svg -prefix $(BUILD_DIR)/$(TOP)"

# Lint check with Verilator
lint:
	verilator --lint-only -Wall \
	          --top-module $(TOP) \
	          -DSYNTHESIS \
	          $(ALL_SRC)

clean:
	rm -rf $(BUILD_DIR)
