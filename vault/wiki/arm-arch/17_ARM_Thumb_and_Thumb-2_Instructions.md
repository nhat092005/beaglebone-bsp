---
title: ARM Architecture Chapter 17 ARM, Thumb and Thumb-2 Instructions
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 17: ARM, Thumb, and Thumb-2 Instructions

## 17.1 Instruction Sets Overview

| Architecture Version | Example Cores | Supported Instruction Sets |
|----------------------|---------------|----------------------------|
| v4T | ARM7TDMI, ARM9TDMI | ARM (32-bit), Thumb (16-bit) |
| v5TE(J) | ARM946, ARM926 | ARM, Thumb |
| v6 | ARM1136 | ARM, Thumb |
| v6T2 | ARM1156T2 | ARM, Thumb-2 |
| v6-M | Cortex-M0, Cortex-M1 | Thumb-2 subset |
| v7-A, v7-R | Cortex-A15, Cortex-R4 | ARM, Thumb-2 |
| v7-M, v7E-M | Cortex-M3, Cortex-M4 | Thumb-2 (Only) |

## 17.2 16-bit Thumb Instructions (Original)

Created to improve code density by compressing 32-bit instructions into 16-bit equivalents. Typically achieves ~65–70% of the size of ARM code.

**Restrictions in 16-bit Thumb:**
- Most instructions operate only on the "low registers" (`r0` to `r7`).
- The source and destination registers must often be the same (e.g., `ADD r2, #1` implies `r2 = r2 + 1`).
- No inline barrel shifter operations (e.g., `LSL`, `ASR` are separate instructions rather than modifiers).
- Most data processing instructions unconditionally update the status flags (acting like the `S` variant in ARM).
- Cannot conditionally execute instructions using a 4-bit prefix (except for `B` branch instructions).
- No direct access to `CPSR`/`SPSR`.

## 17.3 Thumb-2 Instructions

Introduced to overcome the limitations of 16-bit Thumb by mixing 16-bit and new 32-bit instructions in the same stream.
- Removes the need to switch back and forth between ARM and Thumb states.
- 32-bit Thumb-2 instructions can access high registers (`r8`-`r15`), include inline shifting, and specify whether to set condition flags.
- Uses `IT` (If-Then) blocks to allow conditional execution of Thumb instructions.

**Instruction Decoding**: The hardware determines if a fetched 16-bit halfword is a standalone 16-bit instruction or the first half of a 32-bit instruction based on the top 5 bits. (Patterns `0b11101`, `0b11110`, `0b11111` indicate a 32-bit instruction).

### UAL (Unified Assembly Language) Syntax
UAL allows writing code that looks identical for ARM and Thumb-2. 
- If using UAL, you must explicitly append `S` if you want flags updated (e.g., `ADDS`), even if compiling for Thumb. 
- The assembler automatically chooses the narrowest (16-bit) instruction possible. If you need the 32-bit version, use the `.W` (Wide) suffix: `ADD.W r0, r1, #1000`.

## 17.4 Switching States (ARM <-> Thumb)

*Applicable to cores that support both sets (e.g., ARM7TDMI, Cortex-A, Cortex-R).*

State is indicated by the **T bit** in the `CPSR`.
State transitions are achieved using the **Branch and Exchange (`BX`)** or `BLX` instructions.

```asm
BX Rn
```
- If the Least Significant Bit (LSB / Bit 0) of `Rn` is `1`: The processor switches to Thumb state.
- If the LSB of `Rn` is `0`: The processor switches to ARM state.

**Example (ARM7TDMI)**:
```asm
      ARM                   ; Tell assembler to generate ARM code
start ADR   r0, thumb_code + 1  ; Add 1 to address to set LSB
      BX    r0                  ; Branch and switch to Thumb state

      CODE16                ; Tell assembler to generate 16-bit Thumb
thumb_code
      MOV   r0, #10
```

*Note: Cortex-M processors (like Cortex-M4) only operate in Thumb state. If a branch target address has an LSB of 0, a UsageFault is triggered.*

## 17.5 ARM/Thumb Interworking

When compiling C/C++ code where some functions are ARM and some are Thumb, the compiler and linker manage the state switching via **Veneers**.

If `func1` (ARM) calls `func2` (Thumb):
- A standard `BL func2` does not change state.
- The linker intercepts the call and inserts a small block of code (a veneer).
- The `BL` goes to the veneer. The veneer uses a `BX` instruction to change state and jump to `func2`.

To return safely from any subroutine regardless of the state of the caller, use:
```asm
BX lr
```
This will automatically restore the correct state based on the LSB of the Link Register.
