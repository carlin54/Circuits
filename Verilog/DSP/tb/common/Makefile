# cocotb Makefile for common infrastructure tests
# Run individual tests by setting TOPLEVEL and MODULE on command line, e.g.:
#   make TOPLEVEL=fifo_sync MODULE=test_fifo_sync

TOPLEVEL_LANG = verilog
SIM = icarus

RTL_DIR = ../../rtl/common

export PYTHONPATH := $(shell pwd)/..:$(shell pwd)/../helpers:$(PYTHONPATH)

# Default: run fifo_sync test
TOPLEVEL ?= fifo_sync
MODULE ?= test_fifo_sync
VERILOG_SOURCES ?= $(RTL_DIR)/fifo_sync.v

include $(shell cocotb-config --makefiles)/Makefile.sim

# Convenience targets that invoke make recursively
.PHONY: test-fifo-sync test-fifo-async test-dual-port-ram test-single-port-ram \
        test-round-saturate test-axis-interface all-tests

test-fifo-sync:
	$(MAKE) sim TOPLEVEL=fifo_sync MODULE=test_fifo_sync \
		VERILOG_SOURCES=$(RTL_DIR)/fifo_sync.v \
		SIM_BUILD=sim_build_fifo_sync

test-fifo-async:
	$(MAKE) sim TOPLEVEL=fifo_async MODULE=test_fifo_async \
		VERILOG_SOURCES=$(RTL_DIR)/fifo_async.v \
		SIM_BUILD=sim_build_fifo_async

test-dual-port-ram:
	$(MAKE) sim TOPLEVEL=dual_port_ram MODULE=test_dual_port_ram \
		VERILOG_SOURCES=$(RTL_DIR)/dual_port_ram.v \
		SIM_BUILD=sim_build_dual_port_ram

test-single-port-ram:
	$(MAKE) sim TOPLEVEL=single_port_ram MODULE=test_single_port_ram \
		VERILOG_SOURCES=$(RTL_DIR)/single_port_ram.v \
		SIM_BUILD=sim_build_single_port_ram

test-round-saturate:
	$(MAKE) sim TOPLEVEL=round_saturate MODULE=test_round_saturate \
		VERILOG_SOURCES=$(RTL_DIR)/round_saturate.v \
		SIM_BUILD=sim_build_round_saturate

test-axis-interface:
	$(MAKE) sim TOPLEVEL=axis_interface MODULE=test_axis_interface \
		VERILOG_SOURCES=$(RTL_DIR)/axis_interface.v \
		SIM_BUILD=sim_build_axis_interface

all-tests: test-fifo-sync test-fifo-async test-dual-port-ram test-single-port-ram \
           test-round-saturate test-axis-interface
