# RV64G Instruction Specification

Complete behavioral specification for every instruction in RV64IMAFD.
Each entry defines the exact operation the processor must perform.

Notation:
- `x[rd]` = integer register rd (64-bit)
- `f[rd]` = floating-point register rd (64-bit)
- `M[addr]` = memory at byte address addr
- `sext(v)` = sign-extend to 64 bits
- `zext(v)` = zero-extend to 64 bits
- `sext32(v)` = sign-extend bits [31:0] to 64 bits
- `imm` = sign-extended immediate from instruction
- `shamt` = shift amount (bits [5:0] for 64-bit, [4:0] for 32-bit W ops)

---

## RV64I — Base Integer Instructions

### Arithmetic

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| ADD rd, rs1, rs2 | R-type, funct7=0000000, funct3=000 | `x[rd] = x[rs1] + x[rs2]` |
| ADDI rd, rs1, imm | I-type, funct3=000 | `x[rd] = x[rs1] + sext(imm[11:0])` |
| SUB rd, rs1, rs2 | R-type, funct7=0100000, funct3=000 | `x[rd] = x[rs1] - x[rs2]` |
| ADDW rd, rs1, rs2 | R-type, funct7=0000000, funct3=000, opcode=0111011 | `x[rd] = sext32((x[rs1] + x[rs2])[31:0])` |
| ADDIW rd, rs1, imm | I-type, funct3=000, opcode=0011011 | `x[rd] = sext32((x[rs1] + sext(imm))[31:0])` |
| SUBW rd, rs1, rs2 | R-type, funct7=0100000, funct3=000, opcode=0111011 | `x[rd] = sext32((x[rs1] - x[rs2])[31:0])` |

### Logical

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| AND rd, rs1, rs2 | R-type, funct7=0000000, funct3=111 | `x[rd] = x[rs1] & x[rs2]` |
| ANDI rd, rs1, imm | I-type, funct3=111 | `x[rd] = x[rs1] & sext(imm[11:0])` |
| OR rd, rs1, rs2 | R-type, funct7=0000000, funct3=110 | `x[rd] = x[rs1] \| x[rs2]` |
| ORI rd, rs1, imm | I-type, funct3=110 | `x[rd] = x[rs1] \| sext(imm[11:0])` |
| XOR rd, rs1, rs2 | R-type, funct7=0000000, funct3=100 | `x[rd] = x[rs1] ^ x[rs2]` |
| XORI rd, rs1, imm | I-type, funct3=100 | `x[rd] = x[rs1] ^ sext(imm[11:0])` |

### Shifts

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| SLL rd, rs1, rs2 | R-type, funct7=0000000, funct3=001 | `x[rd] = x[rs1] << x[rs2][5:0]` |
| SLLI rd, rs1, shamt | I-type, funct3=001, imm[11:6]=000000 | `x[rd] = x[rs1] << shamt[5:0]` |
| SRL rd, rs1, rs2 | R-type, funct7=0000000, funct3=101 | `x[rd] = x[rs1] >> x[rs2][5:0]` (logical) |
| SRLI rd, rs1, shamt | I-type, funct3=101, imm[11:6]=000000 | `x[rd] = x[rs1] >> shamt[5:0]` (logical) |
| SRA rd, rs1, rs2 | R-type, funct7=0100000, funct3=101 | `x[rd] = x[rs1] >>> x[rs2][5:0]` (arithmetic) |
| SRAI rd, rs1, shamt | I-type, funct3=101, imm[11:6]=010000 | `x[rd] = x[rs1] >>> shamt[5:0]` (arithmetic) |
| SLLW rd, rs1, rs2 | R-type, funct7=0000000, funct3=001, opcode=0111011 | `x[rd] = sext32((x[rs1][31:0] << x[rs2][4:0])[31:0])` |
| SLLIW rd, rs1, shamt | I-type, funct3=001, imm[11:5]=0000000, opcode=0011011 | `x[rd] = sext32((x[rs1][31:0] << shamt[4:0])[31:0])` |
| SRLW rd, rs1, rs2 | R-type, funct7=0000000, funct3=101, opcode=0111011 | `x[rd] = sext32((x[rs1][31:0] >> x[rs2][4:0])[31:0])` |
| SRLIW rd, rs1, shamt | I-type, funct3=101, imm[11:5]=0000000, opcode=0011011 | `x[rd] = sext32((x[rs1][31:0] >> shamt[4:0])[31:0])` |
| SRAW rd, rs1, rs2 | R-type, funct7=0100000, funct3=101, opcode=0111011 | `x[rd] = sext32((x[rs1][31:0] >>> x[rs2][4:0])[31:0])` |
| SRAIW rd, rs1, shamt | I-type, funct3=101, imm[11:5]=0100000, opcode=0011011 | `x[rd] = sext32((x[rs1][31:0] >>> shamt[4:0])[31:0])` |

### Compare (Set Less Than)

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| SLT rd, rs1, rs2 | R-type, funct7=0000000, funct3=010 | `x[rd] = (signed)x[rs1] < (signed)x[rs2] ? 1 : 0` |
| SLTI rd, rs1, imm | I-type, funct3=010 | `x[rd] = (signed)x[rs1] < (signed)sext(imm) ? 1 : 0` |
| SLTU rd, rs1, rs2 | R-type, funct7=0000000, funct3=011 | `x[rd] = (unsigned)x[rs1] < (unsigned)x[rs2] ? 1 : 0` |
| SLTIU rd, rs1, imm | I-type, funct3=011 | `x[rd] = (unsigned)x[rs1] < (unsigned)sext(imm) ? 1 : 0` |

### Loads

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| LB rd, imm(rs1) | I-type, funct3=000, opcode=0000011 | `x[rd] = sext(M[x[rs1]+imm][7:0])` |
| LBU rd, imm(rs1) | I-type, funct3=100, opcode=0000011 | `x[rd] = zext(M[x[rs1]+imm][7:0])` |
| LH rd, imm(rs1) | I-type, funct3=001, opcode=0000011 | `x[rd] = sext(M[x[rs1]+imm][15:0])` |
| LHU rd, imm(rs1) | I-type, funct3=101, opcode=0000011 | `x[rd] = zext(M[x[rs1]+imm][15:0])` |
| LW rd, imm(rs1) | I-type, funct3=010, opcode=0000011 | `x[rd] = sext(M[x[rs1]+imm][31:0])` |
| LWU rd, imm(rs1) | I-type, funct3=110, opcode=0000011 | `x[rd] = zext(M[x[rs1]+imm][31:0])` |
| LD rd, imm(rs1) | I-type, funct3=011, opcode=0000011 | `x[rd] = M[x[rs1]+imm][63:0]` |

### Stores

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| SB rs2, imm(rs1) | S-type, funct3=000 | `M[x[rs1]+imm][7:0] = x[rs2][7:0]` |
| SH rs2, imm(rs1) | S-type, funct3=001 | `M[x[rs1]+imm][15:0] = x[rs2][15:0]` |
| SW rs2, imm(rs1) | S-type, funct3=010 | `M[x[rs1]+imm][31:0] = x[rs2][31:0]` |
| SD rs2, imm(rs1) | S-type, funct3=011 | `M[x[rs1]+imm][63:0] = x[rs2][63:0]` |

### Branches

All branches: if condition true, `PC = PC + sext(imm)`, else `PC = PC + 4`.

| Instruction | Encoding | Condition |
|-------------|----------|-----------|
| BEQ rs1, rs2, offset | B-type, funct3=000 | `x[rs1] == x[rs2]` |
| BNE rs1, rs2, offset | B-type, funct3=001 | `x[rs1] != x[rs2]` |
| BLT rs1, rs2, offset | B-type, funct3=100 | `(signed)x[rs1] < (signed)x[rs2]` |
| BGE rs1, rs2, offset | B-type, funct3=101 | `(signed)x[rs1] >= (signed)x[rs2]` |
| BLTU rs1, rs2, offset | B-type, funct3=110 | `(unsigned)x[rs1] < (unsigned)x[rs2]` |
| BGEU rs1, rs2, offset | B-type, funct3=111 | `(unsigned)x[rs1] >= (unsigned)x[rs2]` |

### Jumps

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| JAL rd, offset | J-type | `x[rd] = PC + 4; PC = PC + sext(imm)` |
| JALR rd, rs1, imm | I-type, funct3=000, opcode=1100111 | `x[rd] = PC + 4; PC = (x[rs1] + sext(imm)) & ~1` |

### Upper Immediate

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| LUI rd, imm | U-type, opcode=0110111 | `x[rd] = sext(imm[31:12] << 12)` |
| AUIPC rd, imm | U-type, opcode=0010111 | `x[rd] = PC + sext(imm[31:12] << 12)` |

### System

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| ECALL | I-type, imm=0x000, opcode=1110011 | Halt (in our impl) |
| EBREAK | I-type, imm=0x001, opcode=1110011 | Halt (in our impl) |
| FENCE | I-type, funct3=000, opcode=0001111 | NOP (single core, no cache) |
| FENCE.I | I-type, funct3=001, opcode=0001111 | NOP (no I-cache to flush) |

### CSR Instructions

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| CSRRW rd, csr, rs1 | I-type, funct3=001, opcode=1110011 | `t=CSR[csr]; CSR[csr]=x[rs1]; x[rd]=t` |
| CSRRS rd, csr, rs1 | I-type, funct3=010, opcode=1110011 | `t=CSR[csr]; CSR[csr]=t\|x[rs1]; x[rd]=t` |
| CSRRC rd, csr, rs1 | I-type, funct3=011, opcode=1110011 | `t=CSR[csr]; CSR[csr]=t&~x[rs1]; x[rd]=t` |
| CSRRWI rd, csr, uimm | I-type, funct3=101, opcode=1110011 | `t=CSR[csr]; CSR[csr]=zext(uimm); x[rd]=t` |
| CSRRSI rd, csr, uimm | I-type, funct3=110, opcode=1110011 | `t=CSR[csr]; CSR[csr]=t\|zext(uimm); x[rd]=t` |
| CSRRCI rd, csr, uimm | I-type, funct3=111, opcode=1110011 | `t=CSR[csr]; CSR[csr]=t&~zext(uimm); x[rd]=t` |

`uimm` = rs1 field (5 bits) used as zero-extended immediate.

**CSR read/write suppression (important for side effects):**
- CSRRS/CSRRC with rs1=x0 (or CSRRSI/CSRRCI with uimm=0): do NOT write the CSR (read-only).
- CSRRW with rd=x0 (or CSRRWI with rd=x0): do NOT read the CSR (write-only).
- For our minimal CSR set (fflags/frm/fcsr) this has no observable effect, but the logic
  must be correct for potential future expansion and to pass compliance tests.

CSR addresses implemented:
- `0x001` fflags (FP exception flags, 5 bits)
- `0x002` frm (FP rounding mode, 3 bits)
- `0x003` fcsr (frm[7:5] | fflags[4:0])
- All other addresses: read returns 0, write is ignored (no illegal instruction exception)

---

## M Extension — Multiply/Divide

### 64-bit Operations

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| MUL rd, rs1, rs2 | R-type, funct7=0000001, funct3=000 | `x[rd] = (x[rs1] * x[rs2])[63:0]` |
| MULH rd, rs1, rs2 | R-type, funct7=0000001, funct3=001 | `x[rd] = ((signed)x[rs1] * (signed)x[rs2])[127:64]` |
| MULHSU rd, rs1, rs2 | R-type, funct7=0000001, funct3=010 | `x[rd] = ((signed)x[rs1] * (unsigned)x[rs2])[127:64]` |
| MULHU rd, rs1, rs2 | R-type, funct7=0000001, funct3=011 | `x[rd] = ((unsigned)x[rs1] * (unsigned)x[rs2])[127:64]` |
| DIV rd, rs1, rs2 | R-type, funct7=0000001, funct3=100 | `x[rd] = (signed)x[rs1] / (signed)x[rs2]` |
| DIVU rd, rs1, rs2 | R-type, funct7=0000001, funct3=101 | `x[rd] = (unsigned)x[rs1] / (unsigned)x[rs2]` |
| REM rd, rs1, rs2 | R-type, funct7=0000001, funct3=110 | `x[rd] = (signed)x[rs1] % (signed)x[rs2]` |
| REMU rd, rs1, rs2 | R-type, funct7=0000001, funct3=111 | `x[rd] = (unsigned)x[rs1] % (unsigned)x[rs2]` |

### 32-bit (W) Operations

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| MULW rd, rs1, rs2 | R-type, funct7=0000001, funct3=000, opcode=0111011 | `x[rd] = sext32((x[rs1][31:0] * x[rs2][31:0])[31:0])` |
| DIVW rd, rs1, rs2 | R-type, funct7=0000001, funct3=100, opcode=0111011 | `x[rd] = sext32((signed)x[rs1][31:0] / (signed)x[rs2][31:0])` |
| DIVUW rd, rs1, rs2 | R-type, funct7=0000001, funct3=101, opcode=0111011 | `x[rd] = sext32((unsigned)x[rs1][31:0] / (unsigned)x[rs2][31:0])` |
| REMW rd, rs1, rs2 | R-type, funct7=0000001, funct3=110, opcode=0111011 | `x[rd] = sext32((signed)x[rs1][31:0] % (signed)x[rs2][31:0])` |
| REMUW rd, rs1, rs2 | R-type, funct7=0000001, funct3=111, opcode=0111011 | `x[rd] = sext32((unsigned)x[rs1][31:0] % (unsigned)x[rs2][31:0])` |

### Division special cases (64-bit):
- Division by zero: `DIV` → -1 (all bits set), `DIVU` → 2^64-1, `REM` → dividend, `REMU` → dividend
- Signed overflow (INT64_MIN / -1): `DIV` → INT64_MIN, `REM` → 0

### Division special cases (32-bit W-variants):
- Division by zero: `DIVW` → sext32(-1), `DIVUW` → sext32(2^32-1), `REMW` → sext32(dividend[31:0]), `REMUW` → sext32(dividend[31:0])
- Signed overflow (INT32_MIN / -1): `DIVW` → sext32(INT32_MIN), `REMW` → 0
- All W-variant results are sign-extended from bit 31 to 64 bits

---

## F Extension — Single-Precision Floating-Point

All `.S` instructions operate on IEEE 754 binary32 (single-precision).
Values in FP registers are NaN-boxed: stored in lower 32 bits, upper 32 bits = 0xFFFFFFFF.
If upper bits != 0xFFFFFFFF on read for .S op, treat as canonical NaN (0x7FC00000).

### NaN-Boxing and Canonical NaN Rules

**NaN-boxing (write):** Any instruction that produces a single-precision result must store it
NaN-boxed: `{32'hFFFFFFFF, result[31:0]}` in the 64-bit FP register.

**NaN-boxing (read):** Any instruction that consumes a single-precision operand must check:
if `f[rs][63:32] != 32'hFFFFFFFF`, replace the operand with canonical NaN `32'h7FC00000`.

**Canonical NaN generation:** When any FP operation produces a NaN result (e.g., 0/0, ∞-∞,
sqrt(-1)), the output MUST be the canonical quiet NaN:
- Single: `32'h7FC00000` (sign=0, exp=0xFF, mantissa MSB=1, rest=0)
- Double: `64'h7FF8000000000000`
Do NOT propagate input NaN payloads.

### Rounding Mode Applicability

Not all FP operations use the rounding mode. Operations where rounding is irrelevant:
- FSGNJ, FSGNJN, FSGNJX: sign manipulation only (exact)
- FMIN, FMAX: comparison-based selection (exact)
- FEQ, FLT, FLE: comparisons produce integer (exact)
- FCLASS: classification produces integer (exact)
- FMV.X.W, FMV.W.X, FMV.X.D, FMV.D.X: bitwise copy (exact)
- FCVT.D.W, FCVT.D.WU: int32 → double always exact (double has enough precision)
- FCVT.D.S: single → double always exact (wider format)

All other FP operations (arithmetic, fused ops, FDIV, FSQRT, float→int, int→float where
precision may be lost) use the resolved rounding mode (`rm` field or `frm` CSR if `rm=111`).

### FP Arithmetic

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FADD.S rd, rs1, rs2 | R-type, funct7=0000000, opcode=1010011 | `f[rd] = f[rs1] + f[rs2]` (single) |
| FSUB.S rd, rs1, rs2 | R-type, funct7=0000100, opcode=1010011 | `f[rd] = f[rs1] - f[rs2]` (single) |
| FMUL.S rd, rs1, rs2 | R-type, funct7=0001000, opcode=1010011 | `f[rd] = f[rs1] × f[rs2]` (single) |
| FDIV.S rd, rs1, rs2 | R-type, funct7=0001100, opcode=1010011 | `f[rd] = f[rs1] / f[rs2]` (single) |
| FSQRT.S rd, rs1 | R-type, funct7=0101100, rs2=00000, opcode=1010011 | `f[rd] = √f[rs1]` (single) |

### Fused Multiply-Add

Single rounding at the end (not multiply then add separately).

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FMADD.S rd, rs1, rs2, rs3 | R4-type, fmt=00, opcode=1000011 | `f[rd] = f[rs1]×f[rs2] + f[rs3]` |
| FMSUB.S rd, rs1, rs2, rs3 | R4-type, fmt=00, opcode=1000111 | `f[rd] = f[rs1]×f[rs2] - f[rs3]` |
| FNMADD.S rd, rs1, rs2, rs3 | R4-type, fmt=00, opcode=1001111 | `f[rd] = -(f[rs1]×f[rs2]) - f[rs3]` |
| FNMSUB.S rd, rs1, rs2, rs3 | R4-type, fmt=00, opcode=1001011 | `f[rd] = -(f[rs1]×f[rs2]) + f[rs3]` |

Note: FNMADD negates both product AND addend. FNMSUB negates only the product.

### Sign Injection

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FSGNJ.S rd, rs1, rs2 | R-type, funct7=0010000, funct3=000 | `f[rd] = {sign(rs2), exp+frac(rs1)}` |
| FSGNJN.S rd, rs1, rs2 | R-type, funct7=0010000, funct3=001 | `f[rd] = {~sign(rs2), exp+frac(rs1)}` |
| FSGNJX.S rd, rs1, rs2 | R-type, funct7=0010000, funct3=010 | `f[rd] = {sign(rs1)^sign(rs2), exp+frac(rs1)}` |

Pseudoinstruction mappings: `FMV.S rd,rs` = `FSGNJ.S rd,rs,rs`, `FNEG.S rd,rs` = `FSGNJN.S rd,rs,rs`, `FABS.S rd,rs` = `FSGNJX.S rd,rs,rs`

### Compare

Result written to INTEGER register rd.

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FEQ.S rd, rs1, rs2 | R-type, funct7=1010000, funct3=010 | `x[rd] = (f[rs1] == f[rs2]) ? 1 : 0` |
| FLT.S rd, rs1, rs2 | R-type, funct7=1010000, funct3=001 | `x[rd] = (f[rs1] < f[rs2]) ? 1 : 0` |
| FLE.S rd, rs1, rs2 | R-type, funct7=1010000, funct3=000 | `x[rd] = (f[rs1] <= f[rs2]) ? 1 : 0` |

NaN handling: FEQ returns 0 if either is NaN (signals NV only for signaling NaN). FLT/FLE return 0 if either is NaN (always signal NV).

### Min/Max

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FMIN.S rd, rs1, rs2 | R-type, funct7=0010100, funct3=000 | `f[rd] = min(f[rs1], f[rs2])` |
| FMAX.S rd, rs1, rs2 | R-type, funct7=0010100, funct3=001 | `f[rd] = max(f[rs1], f[rs2])` |

NaN handling: If one operand is NaN, return the other. If both NaN, return canonical NaN. -0 < +0 for FMIN, +0 > -0 for FMAX.

### Conversions (Float ↔ Integer)

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FCVT.W.S rd, rs1 | funct7=1100000, rs2=00000 | `x[rd] = sext32((int32)f[rs1])` |
| FCVT.WU.S rd, rs1 | funct7=1100000, rs2=00001 | `x[rd] = sext32((uint32)f[rs1])` |
| FCVT.L.S rd, rs1 | funct7=1100000, rs2=00010 | `x[rd] = (int64)f[rs1]` |
| FCVT.LU.S rd, rs1 | funct7=1100000, rs2=00011 | `x[rd] = (uint64)f[rs1]` |
| FCVT.S.W rd, rs1 | funct7=1101000, rs2=00000 | `f[rd] = (float)(int32)x[rs1]` |
| FCVT.S.WU rd, rs1 | funct7=1101000, rs2=00001 | `f[rd] = (float)(uint32)x[rs1]` |
| FCVT.S.L rd, rs1 | funct7=1101000, rs2=00010 | `f[rd] = (float)(int64)x[rs1]` |
| FCVT.S.LU rd, rs1 | funct7=1101000, rs2=00011 | `f[rd] = (float)(uint64)x[rs1]` |

Overflow: clamp to max/min of target integer type, signal NV.
NaN input: convert to max positive integer value (INT_MAX or UINT_MAX), signal NV.

### Move (bitwise, no conversion)

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FMV.X.W rd, rs1 | funct7=1110000, rs2=00000, funct3=000 | `x[rd] = sext32(f[rs1][31:0])` |
| FMV.W.X rd, rs1 | funct7=1111000, rs2=00000, funct3=000 | `f[rd] = NaN-box(x[rs1][31:0])` |

### Classify

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FCLASS.S rd, rs1 | funct7=1110000, rs2=00000, funct3=001 | `x[rd] = classify(f[rs1])` |

Result is a 10-bit mask in x[rd]:
| Bit | Class |
|-----|-------|
| 0 | Negative infinity |
| 1 | Negative normal |
| 2 | Negative subnormal |
| 3 | Negative zero |
| 4 | Positive zero |
| 5 | Positive subnormal |
| 6 | Positive normal |
| 7 | Positive infinity |
| 8 | Signaling NaN |
| 9 | Quiet NaN |

### FP Load/Store

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FLW rd, imm(rs1) | I-type, funct3=010, opcode=0000111 | `f[rd] = NaN-box(M[x[rs1]+imm][31:0])` |
| FSW rs2, imm(rs1) | S-type, funct3=010, opcode=0100111 | `M[x[rs1]+imm][31:0] = f[rs2][31:0]` |

---

## D Extension — Double-Precision Floating-Point

All `.D` instructions operate on IEEE 754 binary64 (double-precision).
Values use the full 64-bit FP register.

### FP Arithmetic

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FADD.D rd, rs1, rs2 | R-type, funct7=0000001, opcode=1010011 | `f[rd] = f[rs1] + f[rs2]` (double) |
| FSUB.D rd, rs1, rs2 | R-type, funct7=0000101, opcode=1010011 | `f[rd] = f[rs1] - f[rs2]` (double) |
| FMUL.D rd, rs1, rs2 | R-type, funct7=0001001, opcode=1010011 | `f[rd] = f[rs1] × f[rs2]` (double) |
| FDIV.D rd, rs1, rs2 | R-type, funct7=0001101, opcode=1010011 | `f[rd] = f[rs1] / f[rs2]` (double) |
| FSQRT.D rd, rs1 | R-type, funct7=0101101, rs2=00000, opcode=1010011 | `f[rd] = √f[rs1]` (double) |

### Fused Multiply-Add

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FMADD.D rd, rs1, rs2, rs3 | R4-type, fmt=01, opcode=1000011 | `f[rd] = f[rs1]×f[rs2] + f[rs3]` |
| FMSUB.D rd, rs1, rs2, rs3 | R4-type, fmt=01, opcode=1000111 | `f[rd] = f[rs1]×f[rs2] - f[rs3]` |
| FNMADD.D rd, rs1, rs2, rs3 | R4-type, fmt=01, opcode=1001111 | `f[rd] = -(f[rs1]×f[rs2]) - f[rs3]` |
| FNMSUB.D rd, rs1, rs2, rs3 | R4-type, fmt=01, opcode=1001011 | `f[rd] = -(f[rs1]×f[rs2]) + f[rs3]` |

### Sign Injection

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FSGNJ.D rd, rs1, rs2 | R-type, funct7=0010001, funct3=000 | `f[rd] = {sign(rs2), exp+frac(rs1)}` |
| FSGNJN.D rd, rs1, rs2 | R-type, funct7=0010001, funct3=001 | `f[rd] = {~sign(rs2), exp+frac(rs1)}` |
| FSGNJX.D rd, rs1, rs2 | R-type, funct7=0010001, funct3=010 | `f[rd] = {sign(rs1)^sign(rs2), exp+frac(rs1)}` |

### Compare

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FEQ.D rd, rs1, rs2 | R-type, funct7=1010001, funct3=010 | `x[rd] = (f[rs1] == f[rs2]) ? 1 : 0` |
| FLT.D rd, rs1, rs2 | R-type, funct7=1010001, funct3=001 | `x[rd] = (f[rs1] < f[rs2]) ? 1 : 0` |
| FLE.D rd, rs1, rs2 | R-type, funct7=1010001, funct3=000 | `x[rd] = (f[rs1] <= f[rs2]) ? 1 : 0` |

### Min/Max

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FMIN.D rd, rs1, rs2 | R-type, funct7=0010101, funct3=000 | `f[rd] = min(f[rs1], f[rs2])` |
| FMAX.D rd, rs1, rs2 | R-type, funct7=0010101, funct3=001 | `f[rd] = max(f[rs1], f[rs2])` |

### Conversions (Float ↔ Integer)

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FCVT.W.D rd, rs1 | funct7=1100001, rs2=00000 | `x[rd] = sext32((int32)f[rs1])` |
| FCVT.WU.D rd, rs1 | funct7=1100001, rs2=00001 | `x[rd] = sext32((uint32)f[rs1])` |
| FCVT.L.D rd, rs1 | funct7=1100001, rs2=00010 | `x[rd] = (int64)f[rs1]` |
| FCVT.LU.D rd, rs1 | funct7=1100001, rs2=00011 | `x[rd] = (uint64)f[rs1]` |
| FCVT.D.W rd, rs1 | funct7=1101001, rs2=00000 | `f[rd] = (double)(int32)x[rs1]` |
| FCVT.D.WU rd, rs1 | funct7=1101001, rs2=00001 | `f[rd] = (double)(uint32)x[rs1]` |
| FCVT.D.L rd, rs1 | funct7=1101001, rs2=00010 | `f[rd] = (double)(int64)x[rs1]` |
| FCVT.D.LU rd, rs1 | funct7=1101001, rs2=00011 | `f[rd] = (double)(uint64)x[rs1]` |

### Conversions (Single ↔ Double)

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FCVT.S.D rd, rs1 | funct7=0100000, rs2=00001 | `f[rd] = NaN-box((float)f[rs1])` |
| FCVT.D.S rd, rs1 | funct7=0100001, rs2=00000 | `f[rd] = (double)f[rs1][31:0]` |

### Move (bitwise)

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FMV.X.D rd, rs1 | funct7=1110001, rs2=00000, funct3=000 | `x[rd] = f[rs1]` (64-bit bitwise copy) |
| FMV.D.X rd, rs1 | funct7=1111001, rs2=00000, funct3=000 | `f[rd] = x[rs1]` (64-bit bitwise copy) |

### Classify

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FCLASS.D rd, rs1 | funct7=1110001, rs2=00000, funct3=001 | `x[rd] = classify(f[rs1])` |

Same 10-bit mask as FCLASS.S.

### FP Load/Store

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| FLD rd, imm(rs1) | I-type, funct3=011, opcode=0000111 | `f[rd] = M[x[rs1]+imm][63:0]` |
| FSD rs2, imm(rs1) | S-type, funct3=011, opcode=0100111 | `M[x[rs1]+imm][63:0] = f[rs2]` |

---

## A Extension — Atomic Memory Operations

All atomics perform: `t = M[x[rs1]]; M[x[rs1]] = op(t, x[rs2]); x[rd] = t`
(Load old value into rd, write new value to memory.)

For our single-core implementation: all atomics trivially complete (no contention).

### Word (32-bit) Atomics

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| LR.W rd, (rs1) | funct7[6:2]=00010, rs2=00000, funct3=010 | `x[rd] = sext32(M[x[rs1]][31:0]); reserve addr` |
| SC.W rd, rs2, (rs1) | funct7[6:2]=00011, funct3=010 | if reservation valid and addr matches: `M[x[rs1]][31:0] = x[rs2][31:0]; x[rd] = 0`; else `x[rd] = 1` (no write) |
| AMOSWAP.W rd, rs2, (rs1) | funct7[6:2]=00001, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=x[rs2][31:0]; x[rd]=t` |
| AMOADD.W rd, rs2, (rs1) | funct7[6:2]=00000, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=(t+x[rs2])[31:0]; x[rd]=t` |
| AMOAND.W rd, rs2, (rs1) | funct7[6:2]=01100, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=(t&x[rs2])[31:0]; x[rd]=t` |
| AMOOR.W rd, rs2, (rs1) | funct7[6:2]=01000, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=(t\|x[rs2])[31:0]; x[rd]=t` |
| AMOXOR.W rd, rs2, (rs1) | funct7[6:2]=00100, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=(t^x[rs2])[31:0]; x[rd]=t` |
| AMOMAX.W rd, rs2, (rs1) | funct7[6:2]=10100, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=max_s32(t[31:0],x[rs2][31:0]); x[rd]=t` |
| AMOMIN.W rd, rs2, (rs1) | funct7[6:2]=10000, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=min_s32(t[31:0],x[rs2][31:0]); x[rd]=t` |
| AMOMAXU.W rd, rs2, (rs1) | funct7[6:2]=11100, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=max_u32(t[31:0],x[rs2][31:0]); x[rd]=t` |
| AMOMINU.W rd, rs2, (rs1) | funct7[6:2]=11000, funct3=010 | `t=sext32(M[addr][31:0]); M[addr][31:0]=min_u32(t[31:0],x[rs2][31:0]); x[rd]=t` |

### Doubleword (64-bit) Atomics

Same operations but with funct3=011, operating on 64-bit values. No sign extension needed.

| Instruction | Encoding | Operation |
|-------------|----------|-----------|
| LR.D rd, (rs1) | funct7[6:2]=00010, rs2=00000, funct3=011 | `x[rd] = M[x[rs1]][63:0]; reserve addr` |
| SC.D rd, rs2, (rs1) | funct7[6:2]=00011, funct3=011 | if reservation valid and addr matches: `M[x[rs1]][63:0] = x[rs2]; x[rd] = 0`; else `x[rd] = 1` (no write) |
| AMOSWAP.D rd, rs2, (rs1) | funct7[6:2]=00001, funct3=011 | `t=M[addr]; M[addr]=x[rs2]; x[rd]=t` |
| AMOADD.D rd, rs2, (rs1) | funct7[6:2]=00000, funct3=011 | `t=M[addr]; M[addr]=t+x[rs2]; x[rd]=t` |
| AMOAND.D rd, rs2, (rs1) | funct7[6:2]=01100, funct3=011 | `t=M[addr]; M[addr]=t&x[rs2]; x[rd]=t` |
| AMOOR.D rd, rs2, (rs1) | funct7[6:2]=01000, funct3=011 | `t=M[addr]; M[addr]=t\|x[rs2]; x[rd]=t` |
| AMOXOR.D rd, rs2, (rs1) | funct7[6:2]=00100, funct3=011 | `t=M[addr]; M[addr]=t^x[rs2]; x[rd]=t` |
| AMOMAX.D rd, rs2, (rs1) | funct7[6:2]=10100, funct3=011 | `t=M[addr]; M[addr]=max_s(t,x[rs2]); x[rd]=t` |
| AMOMIN.D rd, rs2, (rs1) | funct7[6:2]=10000, funct3=011 | `t=M[addr]; M[addr]=min_s(t,x[rs2]); x[rd]=t` |
| AMOMAXU.D rd, rs2, (rs1) | funct7[6:2]=11100, funct3=011 | `t=M[addr]; M[addr]=max_u(t,x[rs2]); x[rd]=t` |
| AMOMINU.D rd, rs2, (rs1) | funct7[6:2]=11000, funct3=011 | `t=M[addr]; M[addr]=min_u(t,x[rs2]); x[rd]=t` |

Note: `aq` and `rl` bits (funct7[1:0]) are ordering hints — ignored in our single-core design.

---

## Instruction Encoding Formats

### R-type (register-register)
```
[31:25]  [24:20] [19:15] [14:12] [11:7]  [6:0]
funct7   rs2     rs1     funct3  rd      opcode
```

### I-type (immediate)
```
[31:20]          [19:15] [14:12] [11:7]  [6:0]
imm[11:0]        rs1     funct3  rd      opcode
```

### S-type (store)
```
[31:25]  [24:20] [19:15] [14:12] [11:7]  [6:0]
imm[11:5] rs2    rs1     funct3  imm[4:0] opcode
```

### B-type (branch)
```
[31]    [30:25]  [24:20] [19:15] [14:12] [11:8]  [7]     [6:0]
imm[12] imm[10:5] rs2   rs1     funct3  imm[4:1] imm[11] opcode
```

### U-type (upper immediate)
```
[31:12]              [11:7]  [6:0]
imm[31:12]           rd      opcode
```

### J-type (jump)
```
[31]    [30:21]    [20]    [19:12]  [11:7]  [6:0]
imm[20] imm[10:1]  imm[11] imm[19:12] rd   opcode
```

### R4-type (fused multiply-add)
```
[31:27] [26:25] [24:20] [19:15] [14:12] [11:7]  [6:0]
rs3     fmt     rs2     rs1     rm      rd      opcode
```

---

## IEEE 754 Implementation Notes

### Single-Precision (binary32)
- 1 sign bit + 8 exponent bits + 23 fraction bits
- Exponent bias: 127
- Denormal: exponent=0, fraction≠0 (implicit leading 0)
- Zero: exponent=0, fraction=0
- Infinity: exponent=255, fraction=0
- NaN: exponent=255, fraction≠0
- Quiet NaN: fraction[22]=1
- Signaling NaN: fraction[22]=0, fraction≠0

### Double-Precision (binary64)
- 1 sign bit + 11 exponent bits + 52 fraction bits
- Exponent bias: 1023
- Denormal: exponent=0, fraction≠0
- Zero: exponent=0, fraction=0
- Infinity: exponent=2047, fraction=0
- NaN: exponent=2047, fraction≠0
- Quiet NaN: fraction[51]=1
- Signaling NaN: fraction[51]=0, fraction≠0

### Rounding Modes
| rm | Mode | Behavior |
|----|------|----------|
| 000 | RNE | Round to nearest, ties to even (default) |
| 001 | RTZ | Round towards zero (truncate) |
| 010 | RDN | Round down (towards -∞) |
| 011 | RUP | Round up (towards +∞) |
| 100 | RMM | Round to nearest, ties away from zero |
| 111 | DYN | Use frm CSR value |

### NaN-boxing (for single-precision in 64-bit registers)
When writing a single-precision result to an FP register:
`f[rd] = {32'hFFFFFFFF, result_32bit}`

When reading for a single-precision operation:
```
if (f[rs][63:32] == 32'hFFFFFFFF)
    operand = f[rs][31:0]
else
    operand = 32'h7FC00000  // canonical NaN
```

### Canonical NaN
- Single: `0x7FC00000` (quiet NaN, positive, fraction MSB set)
- Double: `0x7FF8000000000000`

### Exception Flag Accumulation
`fflags` bits are sticky — once set, they stay set until explicitly cleared via CSR write.
Each FP operation OR's its flags into `fflags`: `fflags = fflags | new_flags`

---

## Total Instruction Count

| Extension | Instructions | Notes |
|-----------|-------------|-------|
| RV64I + Zicsr + Zifencei | 59 | Base integer + W variants + 6 CSR + FENCE.I |
| M | 13 | Multiply/divide + W variants |
| F | 30 | Single-precision FP |
| D | 32 | Double-precision FP (includes S↔D conversions) |
| A | 22 | Atomics (.W and .D) |
| **Total** | **156** | |
