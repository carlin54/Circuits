SRC = adder.sv adder_n.sv adder_tb.sv
TOP = adder_tb_8
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
