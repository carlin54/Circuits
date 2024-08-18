SRC = typedefs.sv alu.sv alu_tb.sv #controller.sv controller_tb.sv counter.sv counter_tb.sv register.sv register_tb.sv mux.sv mux_tb.sv
TOP = alu_tb #controller_tb counter_tb register_tb mux_tb
LOG = compile_sim.log

# ModelSim commands
VLOG = vlog
VSIM = vsim
VLIB = vlib
VSIM_FLAGS = -c -do "run -all; exit"

all: clean compile

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
