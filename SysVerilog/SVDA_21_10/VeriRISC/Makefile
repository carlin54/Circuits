SRC = typedefs.sv memory.sv memory_tb.sv memory_top.sv alu.sv alu_tb.sv controller.sv controller_tb.sv counter.sv counter_tb.sv register.sv register_tb.sv mux.sv mux_tb.sv cpu.sv cpu_tb.sv
TOP = cpu_tb
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
