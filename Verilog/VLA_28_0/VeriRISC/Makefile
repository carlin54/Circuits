COMPILER=iverilog
SIMULATOR=vvp
OUTPUT=design.vvp
SOURCES=alu.v alu_tb.v controller.v controller_tb.v counter.v driver.v driver_tb.v memory.v memory_tb.v priority_n.v priority_n_tb.v multiplexor.v multiplexor_tb.v register.v register_tb.v risc.v risc_tb.v

WAVEFORM=waveform.vcd

all: $(OUTPUT)

$(OUTPUT): $(SOURCES)
	$(COMPILER) -o $@ $^

simulate: $(OUTPUT)
	$(SIMULATOR) $(OUTPUT)

waveform: simulate
	gtkwave $(WAVEFORM)

clean:
	rm -f $(OUTPUT) $(WAVEFORM)

.PHONY: all simulate waveform clean
