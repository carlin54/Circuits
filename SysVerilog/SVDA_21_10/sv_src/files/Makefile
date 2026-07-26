SRC = typedefs.sv mem.sv alu.sv control.sv counter.sv register.sv scale_mux.sv cpu.sv cpu_test.sv
TOP = cpu_test #register_tb  memory_top controller_tb counter_tb register_tb mux_tb
LOG = compile_sim.log

VLOG = vlog
VSIM = vsim
VLIB = vlib
VSIM_FLAGS = -c -do "run -all; exit"

all: clean compile

compile: create_lib
	$(VLOG) $(SRC) | tee $(LOG)

simulate: compile
	$(VSIM) $(VSIM_FLAGS) $(TOP) | tee -a $(LOG)

clean:
	rm -rf $(LOG) transcript vsim.wlf work

create_lib:
	$(VLIB) work

.PHONY: all compile simulate clean create_lib
