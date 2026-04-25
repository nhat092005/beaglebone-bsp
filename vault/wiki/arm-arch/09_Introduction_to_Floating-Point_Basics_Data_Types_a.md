---
title: ARM Architecture Chapter 9 Floating-Point Basics
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 9: Floating-Point Basics

## 9.1 IEEE 754 Formats

| Format | Bits | Exponent | Fraction | Bias | Range | Precision |
|--------|------|----------|----------|------|-------|-----------|
| Half-precision | 16 | 5 | 10 | 15 | ±6×10⁻⁵ to ±6×10⁴ | ~3.3 digits |
| Single-precision | 32 | 8 | 23 | 127 | ±1.2×10⁻³⁸ to ±3.4×10³⁸ | 6-9 digits |
| Double-precision | 64 | 11 | 52 | 1023 | ±2.2×10⁻³⁰⁸ to ±1.8×10³⁰⁸| 15-17 digits|

**Formula**: F = (-1)^s × 2^(exp-bias) × 1.f

Where:
- s = sign bit
- exp = biased exponent
- f = fraction (bits after decimal)
- 1.f = significand (always 1.x for normalized numbers)

## 9.2 Single-Precision Format

```
31    30         23 22                  0
s     exponent   fraction
1 bit 8 bits     23 bits
```

**Special exponents**:
- 0 (all zeros): Subnormals / Zeros
- 255 (all ones): Infinity / NaN
- 1-254: Normal numbers

## 9.3 Special Values

| Value | Exponent | Fraction |
|-------|----------|----------|
| +0 | 0 | 0 |
| -0 | 0 | 0 (sign=1) |
| +∞ | 255 | 0 |
| -∞ | 255 | 0 (sign=1) |
| NaN | 255 | non-zero |
| Subnormal | 0 | non-zero |

### Subnormals
When the exponent is 0, the implicit leading bit is `0.f` instead of `1.f`. The exponent is fixed at `-126`. 
- Single-precision formula: F = (-1)^s × 2⁻¹²⁶ × 0.f
- Smallest representable non-zero value decreases from 1.18×10⁻³⁸ down to 1.4×10⁻⁴⁵.

### NaNs (Not-a-Number)
- **Quiet NaN (qNaN)**: MSB of fraction = 1. Propagates through calculations without trapping.
- **Signaling NaN (sNaN)**: MSB of fraction = 0. Causes Invalid Operation exception if used.

## 9.4 FPU Registers (Cortex-M4)

32 single-precision registers (`s0` to `s31`). 
Registers are aliased to 16 double-precision registers (`d0` to `d15`).
- `d0` = `{s1, s0}`
- `d[x]` = `{s[2x+1], s[2x]}`

*Note: Cortex-M4 only supports single-precision FPU execution, but double-precision registers can be used for data transfer.*

### Enabling the FPU
Coprocessors 10 and 11 must be enabled via the Coprocessor Access Control Register (CPACR) at address `0xE000ED88`.
```asm
; Enable CP10 and CP11
LDR.W r0, =0xE000ED88
LDR   r1, [r0]
ORR   r1, r1, #(0xF << 20)
STR   r1, [r0]
DSB                      ; wait for store to complete
```

## 9.5 Floating-Point Status and Control Register (FPSCR)

```
31  30  29  28  27  26  25  24  23  22  21-8    7   6-5     4   3   2   1   0
N   Z   C   V   -   AHP DN  FZ  RMode   -       IDC -       IXC UFC OFC DZC IOC
```
- **AHP (26)**: Alternative Half-Precision format
- **DN (25)**: Default NaN mode (any NaN operation returns a default qNaN)
- **FZ (24)**: Flush-to-Zero mode (flushes subnormal inputs/outputs to zero for speed)
- **RMode (23:22)**: Rounding Mode
- **Exception Flags (7, 4:0)**: Sticky flags for Input Denormal (IDC), Inexact (IXC), Underflow (UFC), Overflow (OFC), DivByZero (DZC), Invalid Op (IOC)

## 9.6 Data Transfer Instructions

### Loading / Storing from Memory
```asm
VLDR.F32 s5, [r6, #8]    ; load from r6 + 8 into s5
VSTR.F32 s4, [r8, #16]   ; store s4 to r8 + 16
```

### Loading Constants (Pseudo-instruction)
```asm
VLDR.F32 s14, =6.0221415e23   ; load Avogadro's number
VLDR.F32 s17, =0f_7FC00000    ; load using hex notation
```

### Register to Register (ARM <-> FPU)
```asm
VMOV.F32 s7, r2          ; transfer integer r2 into FPU s7
VMOV.F32 r4, s5          ; transfer FPU s5 into integer r4
VMOV.F32 s1, s0          ; copy FPU to FPU
```

### Loading Immediate Constants
For constants that can be represented as `+/- (1.0 to 1.9375) * 2^(-3 to +4)`
```asm
VMOV.F32 s0, #1.5        ; no memory access required
```

## 9.7 Conversions

### Format Conversions
```asm
VCVTB.F32.F16 s2, s5     ; convert half-precision (bottom of s5) to single (s2)
VCVTT.F32.F16 s2, s5     ; convert half-precision (top of s5) to single (s2)
```

### Integer to/from Float
```asm
VCVT.S32.F32 s2, s2      ; float to signed 32-bit int (truncate toward zero)
VCVT.F32.U32 s2, s2      ; unsigned 32-bit int to float
```

### Fixed-Point to/from Float
Specifies the number of fractional bits (`#fbits`). Useful for ADC/DAC conversions without software scaling.
```asm
; Convert unsigned 16-bit fixed-point with 8 fractional bits to float
VCVT.F32.U16 s7, s7, #8
```