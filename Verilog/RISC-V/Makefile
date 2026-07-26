# === Tools ===
RISCV_GCC      = riscv64-unknown-elf-gcc
RISCV_OBJCOPY  = riscv64-unknown-elf-objcopy
IVERILOG       = iverilog
VVP            = vvp
YOSYS          = yosys

# === Flags ===
MARCH          = rv64imafd
MABI           = lp64d
CFLAGS         = -march=$(MARCH) -mabi=$(MABI) -mcmodel=medany -fno-builtin -nostdlib -nostartfiles -I tools -T tools/linker.ld

# === Directories ===
BUILD          = build
RTL            = rtl
TB             = tb

# === Default ===
.PHONY: test test_unit test_isa test_arch test_c sim schematic clean

test:
	./run_tests.sh

test_unit:
	@echo "Unit tests not yet available (no unit testbenches written yet)"

test_isa:
	@echo "ISA tests not yet available (requires Steps 2-3 implementation)"

test_arch:
	@echo "Arch tests not yet available (requires Steps 2-7 implementation)"

test_c:
	@echo "C tests not yet available (requires Steps 2-3 implementation)"

# === Compile and simulate a single C program ===
# Usage: make sim SRC=test/c/factorial.c
sim: $(BUILD)/sim.vvp
	$(VVP) $(BUILD)/sim.vvp

$(BUILD)/sim.vvp: $(BUILD)/test.hex $(RTL)/*.v $(TB)/tb_c_test.v
	$(IVERILOG) -g2012 -o $@ -I $(RTL) $(RTL)/*.v $(TB)/tb_c_test.v \
		-DTEST_HEX=\"$(BUILD)/test.hex\"

$(BUILD)/test.hex: $(BUILD)/test.elf
	$(RISCV_OBJCOPY) -O verilog --change-addresses=-0x80000000 $< $@

$(BUILD)/test.elf: $(SRC) tools/crt0.s tools/printf.c tools/linker.ld | $(BUILD)
	$(RISCV_GCC) $(CFLAGS) tools/crt0.s tools/printf.c $(SRC) -o $@

$(BUILD):
	mkdir -p $(BUILD)

# === Schematic ===
schematic: $(BUILD)/top.svg

$(BUILD)/top.json: $(RTL)/*.v | $(BUILD)
	$(YOSYS) -p "read_verilog $(RTL)/*.v; prep -top top; write_json $@"

$(BUILD)/top.svg: $(BUILD)/top.json
	netlistsvg $< -o $@

# === Clean ===
clean:
	rm -rf $(BUILD)
