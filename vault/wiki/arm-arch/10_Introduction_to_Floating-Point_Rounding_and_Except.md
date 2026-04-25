---
title: ARM Architecture Chapter 10 Floating-Point Rounding
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 10: Floating-Point Rounding and Exceptions

## 10.1 Rounding Modes

Computations are done as if to infinite precision and then rounded to a representable value. 
The IEEE 754-2008 standard specifies five rounding modes. Cortex-M4 supports four:

| Mode | Abbreviation | Description |
|------|--------------|-------------|
| roundTiesToEven | RNE | (Default) Round to nearest. If exactly halfway, round to make LSB even. |
| roundTowardPositive | RP | Round toward +∞ (ceiling) |
| roundTowardNegative | RM | Round toward -∞ (floor) |
| roundTowardZero | RZ | Round toward zero (truncate) |

### Guard, Sticky, and L Bits
Internal precision uses extra bits to determine rounding correctly:
- **L bit**: Least-Significant bit of the pre-rounded normalized significand.
- **Guard (G) bit**: The bit immediately lower in rank than the L bit (adds exactly 1/2 of the LSB value).
- **Sticky (S) bit**: Formed by ORing all bits with lower significance than the guard bit.

### RNE Rounding Logic
Increment the significand if: `(L & G) | (G & S)`
- **G=0**: No increment (fraction < 1/2)
- **G=1, S=1**: Increment (fraction > 1/2)
- **G=1, S=0 (Tie)**: Increment only if L=1 (rounds up to make LSB even)

### Directed Rounding Logic
- **RP (Positive)**: Increment if `~sign & (G|S)`
- **RM (Negative)**: Increment if `sign & (G|S)`
- **RZ (Zero/Truncate)**: Never increment.

## 10.2 Floating-Point Exceptions

Floating-point exceptions signal unusual conditions. The IEEE 754-2008 standard requires that a default result be written to the destination, a flag be set, and processing continue uninterrupted.

| Exception | Flag | Trigger | Default Result |
|-----------|------|---------|----------------|
| Division by Zero | DZC | Normal/subnormal divided by 0 | Properly signed infinity (±∞) |
| Invalid Operation | IOC | 0/0, ∞-∞, 0×∞, √(-1), or sNaN operand | Quiet NaN (qNaN) |
| Overflow | OFC | Absolute result too large for format | ±∞ (RNE) or max normal (RZ) |
| Underflow | UFC | Absolute result too small (before rounding) | Subnormal or ±0 |
| Inexact | IXC | Result was rounded | Rounded value |

*Note: Inexact (IXC) often occurs concurrently with Overflow or Underflow.*

### Invalid Operation Conditions
- Operations with Signaling NaNs (sNaNs).
- Addition: (+∞) + (-∞)
- Subtraction: (+∞) - (+∞)
- Multiplication: 0 × ±∞
- Division: 0/0 or ∞/∞
- Square root: x < 0
- Conversion to integer: value is NaN, Infinity, or out of range for the integer type (returns largest integer value).

### Overflow Defaults
| Rounding Mode | Positive Overflow Result | Negative Overflow Result |
|---------------|--------------------------|--------------------------|
| RNE | +infinity | -infinity |
| RP | +infinity | -maximum normal |
| RM | +maximum normal | -infinity |
| RZ | +maximum normal | -maximum normal |

## 10.3 Algebraic Laws in Floating-Point

Because of rounding and finite precision, standard mathematical laws do not always apply in floating-point arithmetic.

- **Commutative Law (A + B = B + A)**: Holds for individual FP addition and multiplication.
- **Associative Law ((A + B) + C = A + (B + C))**: **FAILS**. Order of operations matters due to rounding and loss of precision (e.g., adding a very small number to a very large number).
- **Distributive Law (A × (B + C) = (A × B) + (A × C))**: **FAILS**.

## 10.4 Normalization and Cancelation

- **Post-normalization**: If a multiplication results in a significand in the range [2.0, 4.0), it must be shifted right by 1, and the exponent incremented. This can sometimes push the exponent out of range, causing Overflow.
- **Effective Subtraction (Cancelation)**: Subtracting two numbers of similar magnitude can cancel out the upper bits, leaving leading zeros. The result must be shifted left to normalize (leading 1), and the exponent is decremented. This can push the exponent out of bounds, causing Underflow.