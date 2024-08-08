SRC = register.sv register_tb.sv
EXE = simulation
LOG = compile_sim.log

IVERILOG = iverilog
IVERILOG_FLAGS = -g2012 -DTESTBENCH_PRINT_ASSERT_PASS

all: compile simulate

compile:
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(EXE) $(SRC) | tee $(LOG)

simulate: compile
	vvp $(EXE)

clean:
	rm -rf $(EXE) $(LOG)

.PHONY: all compile simulate clean
