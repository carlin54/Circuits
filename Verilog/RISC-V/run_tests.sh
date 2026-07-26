#!/usr/bin/env bash
set -euo pipefail

BUILD=build
RTL=rtl
TB=tb
IVERILOG=iverilog
VVP=vvp
RISCV_GCC=riscv64-unknown-elf-gcc
RISCV_OBJCOPY=riscv64-unknown-elf-objcopy
MARCH=rv64imafd
MABI=lp64d

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

mkdir -p "$BUILD"

pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
skip() { echo "  SKIP: $1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }

# ===== 1. Unit Tests =====
echo "=== Unit Tests ==="
UNIT_TBS=$(find "$TB" -name 'tb_*.v' \
    ! -name 'tb_isa_test.v' \
    ! -name 'tb_arch_test.v' \
    ! -name 'tb_c_test.v' 2>/dev/null || true)

if [ -z "$UNIT_TBS" ]; then
    skip "no unit testbenches found"
else
    for tb_file in $UNIT_TBS; do
        name=$(basename "$tb_file" .v)
        if $IVERILOG -g2012 -o "$BUILD/${name}.vvp" -I "$RTL" "$RTL"/*.v "$tb_file" 2>/dev/null; then
            result=$($VVP "$BUILD/${name}.vvp" 2>&1 | tail -1)
            if echo "$result" | grep -q "PASS"; then
                pass "$name"
            else
                fail "$name ($result)"
            fi
        else
            fail "$name (compile error)"
        fi
    done
fi

# ===== 2. ISA Tests =====
echo ""
echo "=== ISA Tests ==="
ISA_TEST_DIR=test/riscv-tests/isa
ISA_LINK=test/link_isa.ld
ISA_INC="-I $ISA_TEST_DIR/macros/scalar -I test/riscv-tests/env/p"
if [ ! -d "$ISA_TEST_DIR" ]; then
    skip "riscv-tests submodule not initialized"
else
    for suite in rv64ui rv64um rv64ua rv64uf rv64ud; do
        for src in "$ISA_TEST_DIR/$suite"/*.S; do
            [ -f "$src" ] || continue
            tname=$(basename "$src" .S)
            name="${suite}-p-${tname}"
            elf="$BUILD/$name"
            hex="$BUILD/${name}.hex"

            if ! $RISCV_GCC -march=$MARCH -mabi=$MABI -nostdlib -nostartfiles \
                $ISA_INC -T "$ISA_LINK" "$src" -o "$elf" 2>/dev/null; then
                fail "$name (gcc compile error)"
                continue
            fi

            $RISCV_OBJCOPY -O verilog --change-addresses=-0x80000000 "$elf" "$hex" 2>/dev/null

            tohost_addr=$(riscv64-unknown-elf-nm "$elf" 2>/dev/null | grep ' tohost$' | awk '{print $1}' || echo "")
            if [ -z "$tohost_addr" ]; then
                skip "$name (no tohost symbol)"
                continue
            fi

            tohost_offset=$(printf "%d" "0x$tohost_addr")
            tohost_offset=$((tohost_offset - 0x80000000))

            if $IVERILOG -g2012 -o "$BUILD/${name}.vvp" -I "$RTL" "$RTL"/*.v "$TB/tb_isa_test.v" \
                -DTEST_HEX=\""$hex"\" -DTOHOST_ADDR=$tohost_offset 2>/dev/null; then
                result=$(timeout 30 $VVP "$BUILD/${name}.vvp" 2>&1 | tail -1)
                if echo "$result" | grep -q "PASS"; then
                    pass "$name"
                else
                    fail "$name ($result)"
                fi
            else
                fail "$name (compile error)"
            fi
        done
    done
fi

# ===== 3. Arch Tests =====
echo ""
echo "=== Arch Tests ==="
ARCH_TEST_DIR=test/riscv-arch-test
if [ ! -d "$ARCH_TEST_DIR" ]; then
    skip "riscv-arch-test submodule not initialized"
else
    skip "arch-test framework integration pending"
fi

# ===== 4. C Tests =====
echo ""
echo "=== C Integration Tests ==="
C_TEST_DIR=test/c
if [ ! -d "$C_TEST_DIR" ]; then
    skip "no C test directory found"
else
    for src in "$C_TEST_DIR"/*.c; do
        [ -f "$src" ] || continue
        name=$(basename "$src" .c)
        elf="$BUILD/${name}.elf"
        hex="$BUILD/${name}.hex"

        if $RISCV_GCC -march=$MARCH -mabi=$MABI -mcmodel=medany -fno-builtin -nostdlib -nostartfiles \
            -I tools -T tools/linker.ld tools/crt0.s tools/printf.c "$src" -o "$elf" 2>/dev/null; then
            $RISCV_OBJCOPY -O verilog --change-addresses=-0x80000000 "$elf" "$hex"

            if $IVERILOG -g2012 -o "$BUILD/${name}.vvp" -I "$RTL" "$RTL"/*.v "$TB/tb_c_test.v" \
                -DTEST_HEX=\""$hex"\" 2>/dev/null; then
                result=$(timeout 60 $VVP "$BUILD/${name}.vvp" 2>&1 | tail -1)
                if echo "$result" | grep -q "PASS"; then
                    pass "$name"
                else
                    fail "$name ($result)"
                fi
            else
                fail "$name (verilog compile error)"
            fi
        else
            fail "$name (C compile error)"
        fi
    done
fi

# ===== Summary =====
echo ""
echo "=============================="
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  SKIP: $SKIP_COUNT"
echo "=============================="

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
