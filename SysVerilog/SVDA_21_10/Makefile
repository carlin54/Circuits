SRC = register.sv register_tb.sv mux.sv mux_tb.sv
TOP = register_tb mux_tb
LOG = compile_sim.log

# ModelSim commands
VLOG = vlog
VSIM = vsim
VLIB = vlib
VSIM_FLAGS = -c -do "run -all; exit"

all: compile simulate

# Create the 'work' library before compiling
compile: create_lib
	$(VLOG) $(SRC) | tee $(LOG)

simulate: compile
	$(VSIM) $(VSIM_FLAGS) $(TOP) | tee -a $(LOG)

clean:
	rm -rf $(LOG) transcript vsim.wlf work

# Create the 'work' library
create_lib:
	$(VLIB) work

.PHONY: all compile simulate clean create_lib
