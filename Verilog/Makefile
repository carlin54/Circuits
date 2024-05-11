# Makefile for Verilog projects using Icarus Verilog

# Specify the compiler
COMPILER=iverilog
# Specify the simulator
SIMULATOR=vvp
# Designate the output file
OUTPUT=design.vvp
# List all Verilog source files
SOURCES=alu.v alu_tb.v multiplexor.v multiplexor_tb.v driver.v driver_tb.v
# Define the waveform output file
WAVEFORM=waveform.vcd

# Default target to compile and simulate
all: $(OUTPUT)

$(OUTPUT): $(SOURCES)
	$(COMPILER) -o $@ $^

# Target to run the simulation
simulate: $(OUTPUT)
	$(SIMULATOR) $(OUTPUT)

# Target to generate waveform using GTKWave if needed
waveform: simulate
	gtkwave $(WAVEFORM)

# Clean up generated files
clean:
	rm -f $(OUTPUT) $(WAVEFORM)

# Specify the .PHONY rule to distinguish targets that do not produce output files
.PHONY: all simulate waveform clean
