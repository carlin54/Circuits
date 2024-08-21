COMPILER=iverilog
SIMULATOR=vvp
OUTPUT=design.vvp
SOURCES=l1ca_generator.v l1ca_generator_tb.v

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
