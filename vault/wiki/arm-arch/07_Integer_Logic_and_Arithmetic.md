---
title: ARM Architecture Chapter 7 Integer Logic and Arithmetic
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 7: Integer Logic and Arithmetic

## 7.1 Status Flags

CPSR (ARM7TDMI) or xPSR (Cortex-M4) condition code flags (bits 31-28):

| Flag | Bit | Meaning |
|------|-----|---------|
| N | 31 | Negative result (MSB is 1) |
| Z | 30 | Zero result |
| C | 29 | Carry/borrow |
| V | 28 | Overflow (signed) |

**Setting flags**:
- Comparison instructions (`CMP`, `CMN`, `TST`, `TEQ`) always set flags.
- Arithmetic/logic instructions only set flags if the `S` suffix is appended (e.g., `ADDS`, `SUBS`, `ANDS`).
- Direct PSR access (`MRS`, `MSR`).

### Flag Details

**N (Negative)**: Indicates a negative result in two's complement (the most significant bit is set).
```asm
MOV   r3, #-1
MOV   r4, #-2
ADDS  r3, r4, r3    ; -1 + -2 = -3, N flag is set
```

**V (Overflow)**: Set when a signed result exceeds the 32-bit range.
- Addition: carry into MSB ≠ carry out
- Subtraction: carry into MSB ≠ carry out
```asm
LDR   r3, =0x7B000000
LDR   r4, =0x30000000
ADDS  r5, r4, r3    ; V is set: positive + positive = negative (overflow)
```

**Z (Zero)**: Set when all 32 bits of the result are zero.
```asm
SUBS  r7, r7, #1    ; decrement, Z set when r7 reaches 0
BNE   loop          ; branch if not equal to zero
```

**C (Carry)**: Set when:
- Addition produces a result ≥ 2^32.
- Subtraction produces a positive result (no borrow). *Note: Carry is inverted for subtraction.*
- A barrel shifter operation produces a carry.

## 7.2 Comparison Instructions

These instructions only update the flags; they do not save the result.

| Instruction | Operation | Use |
|-------------|-----------|-----|
| CMP | Rn - Operand2 | Compare values |
| CMN | Rn + Operand2 | Compare negative (inverse of CMP) |
| TST | Rn & Operand2 | Test bits (AND) |
| TEQ | Rn ^ Operand2 | Test equivalence (XOR) |

```asm
CMP   r8, #0          ; r8 == 0?
BEQ   routine         ; branch if equal

TST   r4, r3          ; test bits (e.g., r3 = 0xC0000000 tests bits 31,30)
TEQ   r9, r4, LSL #3  ; test if r9 equals the shifted value of r4
```

## 7.3 Data Processing Instructions

**Format**: `instruction{S}{<cond>} Rd, Rn, <operand2>`

### Arithmetic

| Instruction | Operation |
|-------------|-----------|
| ADD | Rd = Rn + operand2 |
| ADC | Rd = Rn + operand2 + C |
| SUB | Rd = Rn - operand2 |
| SBC | Rd = Rn - operand2 - NOT(C) |
| RSB | Rd = operand2 - Rn |
| RSC | Rd = operand2 - Rn - NOT(C) |

*Note: `RSB` (Reverse Subtract) is useful because the barrel shifter only operates on the second operand. `RSB r0, r2, r3, LSL #2` calculates `r3*4 - r2`.*

### 64-bit Subtraction Example
```asm
; 0x7000BEEFC0000000 − 0x3000BABE80000000
LDR   r0, =0xC0000000   ; lower 32-bits
LDR   r1, =0x7000BEEF   ; upper 32-bits
LDR   r2, =0x80000000   ; lower 32-bits
LDR   r3, =0x3000BABE   ; upper 32-bits
SUBS  r4, r0, r2        ; set C bit for next subtraction
SBC   r5, r1, r3        ; upper 32 bits use the carry flag
```

### Logical

| Instruction | Operation |
|-------------|-----------|
| AND | Rd = Rn & operand2 |
| ORR | Rd = Rn \| operand2 |
| EOR | Rd = Rn ^ operand2 (XOR) |
| BIC | Rd = Rn & ~operand2 (Bit Clear) |
| MVN | Rd = ~operand2 (Move NOT / one's complement) |

```asm
AND   r1, r2, r3        ; r1 = r2 AND r3
BIC   r1, r2, r3        ; r1 = r2 AND NOT r3 (clear bits specified by r3)
MOVN  r5, #0            ; r5 = 0xFFFFFFFF (-1 in two's complement)
```

## 7.4 Shift Operations

| Instruction | Operation |
|-------------|-----------|
| LSL | Logical Shift Left (multiply by 2^n) |
| LSR | Logical Shift Right (divide by 2^n, unsigned/zero fill) |
| ASR | Arithmetic Shift Right (divide by 2^n, signed/sign fill) |
| ROR | Rotate Right |
| RRX | Rotate Right through Carry (1 bit) |

Shifts can be applied to `operand2` in data processing instructions:
```asm
ADD   r0, r1, r2, LSL #3   ; r0 = r1 + (r2 << 3)
```

## 7.5 Multiplication

Multiplication instructions do not use the barrel shifter.

| Instruction | Operation |
|-------------|-----------|
| MUL | Rd = Rm × Rs (32-bit product) |
| MLA | Rd = Rm × Rs + Rn (Multiply-accumulate, 32-bit) |
| MLS | Rd = Rn - (Rm × Rs) (Cortex-M4) |
| SMULL | RdHi:RdLo = Rm × Rs (64-bit signed product) |
| UMULL | RdHi:RdLo = Rm × Rs (64-bit unsigned product) |
| SMLAL | RdHi:RdLo += Rm × Rs (64-bit signed MAC) |
| UMLAL | RdHi:RdLo += Rm × Rs (64-bit unsigned MAC) |

### Multiplication by a Constant (using Barrel Shifter)
ARM compilers often use shifts and adds instead of the multiplier array to save power/cycles:
```asm
ADD   r0, r1, r1, LSL #2   ; r0 = r1 + (r1*4) = r1*5
RSB   r0, r2, r2, LSL #3   ; r0 = (r2*8) - r2 = r2*7
```

## 7.6 Division (Cortex-M4 only)

ARM7TDMI requires software division routines. Cortex-M4 includes hardware dividers:
```asm
UDIV   r3, r1, r2       ; unsigned: r3 = r1 / r2
SDIV   r3, r1, r2       ; signed: r3 = r1 / r2
```

## 7.7 Saturation Arithmetic (Cortex-M4)

Used heavily in DSP to prevent overflow/wraparound. If bounds are exceeded, the value is clipped, and the `Q` flag (sticky) is set in the APSR.

| Instruction | Description |
|-------------|-------------|
| SSAT | Signed saturate to range |
| USAT | Unsigned saturate to range |

```asm
SSAT  r4, #16, r3       ; saturate r3 to signed 16-bit range (-32768 to 32767)
USAT  r4, #16, r3       ; saturate r3 to unsigned 16-bit range (0 to 65535)
```

## 7.8 Bit Manipulation (Cortex-M4)

Extracting, inserting, and clearing specific bit fields:

| Instruction | Description |
|-------------|-------------|
| BFI | Bit Field Insert |
| UBFX | Unsigned Bit Field Extract |
| SBFX | Signed Bit Field Extract |
| BFC | Bit Field Clear |
| RBIT | Reverse Bit Order |

```asm
BFI   r1, r0, #8, #8    ; insert 8 bits from r0 into r1 starting at bit 8
UBFX  r1, r0, #12, #8   ; extract 8 unsigned bits from r0 starting at bit 12
BFC   r1, #4, #4        ; clear 4 bits in r1 starting at bit 4
RBIT  r1, r1            ; reverse bit order of r1
```

## 7.9 DSP Extensions (Cortex-M4)

Specialized instructions for algorithms:
- `SMMLA` / `SMMLAR`: Multiply two 32-bit values, take top 32 bits, and accumulate. (R adds rounding).
- `USAD8`: Sum of absolute differences (used in image processing/motion estimation).
- `USADA8`: Accumulated sum of absolute differences.

## 7.10 Fractional (Q) Notation

A software convention for representing fractions using integers.
- **Q15 notation**: 1 sign bit, 15 fraction bits (values between -1 and ~1).
- Multiplication: Qn × Qm = Q(n+m).
- Example: Q15 × Q15 = Q30. Requires left shifting by 1 to convert back to Q31.

```asm
; Multiply two Q15 numbers on Cortex-M4
LDR   r3, =0x6487        ; pi/4 in Q15
LDR   r2, =0xCE71        ; -0.3872 in Q15
SMULBB r5, r2, r3        ; product in Q30
LSL   r5, r5, #1         ; shift left 1 bit to normalize to Q31
```