---
title: ARM Architecture Chapter 11 Floating-Point Instructions
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 11: Floating-Point Data-Processing Instructions

## 11.1 Instruction Syntax

```
V<operation>{cond}.F32 <Sd>, <Sn>, <Sm>
```

- `Sd`, `Sn`, `Sm`: Single-precision registers `s0` to `s31`
- All operands can be the same or different registers.
- All FPU data processing instructions in the Cortex-M4 operate on single-precision data (`.F32` or `.F`).

**Examples**:
```asm
VADD.F32 s0, s1, s2    ; s0 = s1 + s2
VMUL.F32 s0, s9, s9    ; s0 = s9 * s9 (square)
```

## 11.2 Arithmetic Instructions

| Instruction | Operation | Notes |
|-------------|-----------|-------|
| VADD.F32 | Sd = Sn + Sm | Addition |
| VSUB.F32 | Sd = Sn - Sm | Subtraction |
| VMUL.F32 | Sd = Sn × Sm | Multiplication |
| VDIV.F32 | Sd = Sn / Sm | Division |
| VABS.F32 | Sd = \|Sm\| | Absolute value (clears sign bit) |
| VNEG.F32 | Sd = -Sm | Negation (flips sign bit) |
| VSQRT.F32 | Sd = √Sm | Square root |

*Note: VABS and VNEG are considered "non-arithmetic" because they only modify the sign bit and do not trigger Invalid Operation exceptions for signaling NaNs.*

## 11.3 Multiply-Accumulate

### Chained (Rounded intermediate product)
| Instruction | Operation |
|-------------|-----------|
| VMLA.F32 | Sd = Sd + Round(Sn × Sm) |
| VMLS.F32 | Sd = Sd + Round(-(Sn × Sm)) |
| VNMLA.F32 | Sd = (-Sd) + Round(-(Sn × Sm)) |
| VNMLS.F32 | Sd = (-Sd) + Round(Sn × Sm) |

### Fused (Unrounded intermediate product)
More accurate because the product is kept at infinite precision before the addition.

| Instruction | Operation |
|-------------|-----------|
| VFMA.F32 | Sd = Sd + (Sn × Sm) |
| VFMS.F32 | Sd = Sd + (-(Sn) × Sm) |
| VFNMA.F32 | Sd = (-Sd) + (Sn × Sm) |
| VFNMS.F32 | Sd = (-Sd) + (-(Sn) × Sm) |

## 11.4 Comparison Instructions and Flags

FPU arithmetic operations **do not** set condition flags. Only comparison instructions set flags.

```asm
VCMP.F32 s0, s1    ; compare s0 - s1, set flags in FPSCR
VCMP.F32 s0, #0.0  ; compare s0 with zero
```

**NaN Handling**:
- `VCMP`: Sets Invalid Operation (IOC) flag only if an operand is a **Signaling NaN (sNaN)**.
- `VCMPE`: Sets IOC flag if an operand is **ANY NaN** (quiet or signaling).

**FPSCR flags after comparison**:
| Comparison Result | N | Z | C | V |
|-------------------|---|---|---|---|
| Less than | 1 | 0 | 0 | 0 |
| Equal (+0 == -0) | 0 | 1 | 1 | 0 |
| Greater than | 0 | 0 | 1 | 0 |
| Unordered (NaN) | 0 | 0 | 1 | 1 |

## 11.5 Accessing FPSCR Flags for Branching

To use the FPU flags for conditional branching (like `BEQ`, `VMOVGT`), they must be moved from the `FPSCR` to the integer `APSR` using the `VMRS` instruction.

```asm
VCMP.F32    s4, s5            ; compare s4 and s5
VMRS        APSR_nzcv, FPSCR  ; copy ONLY the NZCV flags to APSR

VMOVGT.F32  s8, s4            ; move s4 to s8 if s4 > s5
VMOVLE.F32  s8, s5            ; move s5 to s8 if s5 >= s4
```

*Note: `VMRS` and `VMSR` (write to FPSCR) are serializing instructions. They wait for all previous instructions to complete.*

## 11.6 Special Modes

Enabled via the `FPSCR` register:
- **Flush-to-Zero (FZ)**: Treats all subnormal inputs/outputs as zero (with original sign). Increases speed at the cost of IEEE 754 compliance.
- **Default NaN (DN)**: Any NaN operation returns a generic default Quiet NaN (0x7FC00000) regardless of the input NaN's payload.

## 11.7 Examples

### Quadratic: y = ax² + bx + c
```asm
; Assume: a in s0, b in s1, c in s2, x in s3
VMUL.F32 s4, s0, s3   ; s4 = a * x
VMUL.F32 s4, s4, s3   ; s4 = a * x²
VMLA.F32 s4, s1, s3   ; s4 = (a * x²) + (b * x)
VADD.F32 s4, s4, s2   ; s4 = (ax² + bx) + c
```

### Distance calculation: √(x² + y²)
```asm
; Assume x in s1, y in s3
VMUL.F32 s0, s1, s1   ; s0 = x²
VMUL.F32 s2, s3, s3   ; s2 = y²
VADD.F32 s0, s0, s2   ; s0 = x² + y²
VSQRT.F32 s0, s0      ; s0 = √(x² + y²)
```