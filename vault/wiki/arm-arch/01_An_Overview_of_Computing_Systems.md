---
title: ARM Architecture Chapter 1 Computing Systems Overview
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 1: Computing Systems Overview

## 1.1 Introduction

Modern computing devices contain system-on-chips (SoCs) that combine processors, memory, and graphics chips. A typical SoC includes ARM cores, floating-point units, energy management, and various peripherals connected via busses.

Microcontrollers combine a processor with integrated peripherals (timers, UARTs, A/D converters) for low-cost embedded applications.

## 1.2 RISC History

Reduced Instruction Set Computer (RISC) principles developed at UC Berkeley (1981-1982):
- All instructions execute in single cycle
- Fixed instruction length and format
- Simple decode (register fields in consistent positions)
- No microcode - load/store architecture
- Explicit Load/Store instructions (arithmetic uses registers only)

### 1.2.1 ARM Origins

ARM (Acorn RISC Machine, later Advanced RISC Machine) began in 1983 at Acorn Computers:
- ARM1: First silicon April 26, 1985, <25,000 transistors, 4 MHz
- ARM2: Added multiply/multiply-accumulate, 12 MHz
- ARM3: 4K unified cache, 25 MHz

### 1.2.2 ARM Ltd Formation (1990)

Apple and Acorn formed ARM Holdings. Business model: license processor designs rather than sell chips. First licensee: VLSI Technology.

Key processors:
- ARM7TDMI (1993): Thumb instruction set, Debug/ICE extensions, best-selling ARM core
- ARM9, ARM10, ARM11 families
- Cortex-A: Application processors (A5-A15, A57, A53)
- Cortex-R: Real-time processors (R4-R7)
- Cortex-M: Microcontrollers (M0-M4)

## 1.3 Number Systems

### Binary to Decimal
```
110101₂ = 2⁵ + 2⁴ + 2² + 2⁰ = 32 + 16 + 4 + 1 = 53₁₀
```

### Hexadecimal
Digits: 0-9, A-F (representing 10-15)

**Example**: A5E9₁₆ = (10×16³) + (5×16²) + (14×16¹) + (9×16⁰) = 42,473₁₀

**Binary to Hex**: Group 4 bits
```
11011111000010101111₂ = DF0AF₁₆
```

## 1.4 Integer Representations

### Unsigned
All bits contribute positive value: 0 to 2^m - 1

### Signed Representations

**Two's Complement** (standard):
- MSB represents -2^(m-1)
- Range for m bits: -2^(m-1) to 2^(m-1) - 1

| Length | Bits | Range |
|--------|------|-------|
| Byte | 8 | -128 to 127 |
| Halfword | 16 | -32,768 to 32,767 |
| Word | 32 | -2,147,483,648 to 2,147,483,647 |

**Convert negative to two's complement**: invert bits, add 1

### Floating-Point (IEEE 754)

Single-precision (32-bit): F = (-1)^s × 1.f × 2^(e-bias)
- Sign: 1 bit
- Exponent: 8 bits (bias = 127)
- Fraction: 23 bits

Range: ±1.2×10^-38 to ±3.4×10^+38

**Example**: 1.5 = 0x3FC00000
- s = 0, f = 0.5, e = 127 (2^0 + bias)

## 1.5 Translating Bits to Commands

All processors are programmed with a set of instructions encoded as bit patterns (machine code). To make it easier for humans, these bit patterns are mapped to mnemonics (assembly language).

**Example**:
`MOV count, #8` (encoded as `0xE3A0D008` in ARM)
- `31:28` Condition (`0xE` = AL)
- `27:21` Opcode (MOV)
- `15:12` Destination Register (`Rd`)
- `11:0` Operand (`0x008`)

An assembler takes these mnemonics and translates them into the raw 1s and 0s that the processor executes.
