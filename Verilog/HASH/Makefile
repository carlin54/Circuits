COMPILER=iverilog
SIMULATOR=vvp
OUTPUT=design.vvp
SOURCES=md5_core.v md5.v md5_tb.v

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
