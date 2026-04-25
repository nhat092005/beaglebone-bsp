---
title: ARM Architecture Chapter 6 Constants and Literal Pools
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 6: Constants and Literal Pools

## 6.1 ARM Rotation Scheme

32-bit ARM instructions cannot hold full 32-bit constants. The solution: 8-bit value rotated by an even number of bits (0-30).

**Encoding**: 12 bits for immediate: 8-bit value + 4-bit rotation (×2 = right rotate amount)

### Generation Examples

| Constant | Rotation | Result |
|----------|----------|--------|
| 0xFF | none | 0-255 |
| 0xFF0 | ROR #28 | 0-4080 (step 16) |
| 0xFF00 | ROR #24 | 0-65280 (step 256) |
| 0xFF000000 | ROR #8 | 0-255×2^24 |

**Syntax**:
```asm
MOV   r0, #0xFF           ; r0 = 255
MOV   r0, #0xFF, 28       ; r0 = 4080 (0xFF << 4)
ADD   r0, r2, #0xFF000000 ; r0 = r2 + 0xFF000000
```

### Cortex-M4 Constants
Can generate:
- 8-bit value shifted by any amount
- Patterns: `0x00XY00XY`, `0xXY00XY00`, `0xXYXYXYXY`

```asm
MOV   r3, #0x55555555    ; works natively on Cortex-M4
```

### MVN (Move Negative)
Generate one's complement values:
```asm
MVN   r0, #0             ; r0 = 0xFFFFFFFF
MVN   r3, #0xEE          ; r3 = 0xFFFFFF11
```

## 6.2 Loading Constants (Pseudo-instructions)

Use LDR pseudo-instruction - assembler converts to optimal form:
```asm
LDR   r8, =0x20000040    ; load any 32-bit constant
VLDR.F32 s7, =3.14159    ; floating-point constant
```

**Assembler behavior**:
1. Try MOV/MVN first (rotation scheme)
2. If fails, place constant in literal pool, generate LDR with PC-relative offset

## 6.3 Literal Pools

Memory area holding constants near code. 
- ARM7TDMI PC-relative load range: ±4KB.
- Cortex-M4 (16-bit LDR): +1KB (cannot look backwards). Use `LDR.W` (32-bit Thumb-2) to extend range to ±4KB.

### Placement
- Default: at `END` of each `AREA`
- Manual placement: `LTORG` directive

### Example
```asm
AREA Example, CODE
ENTRY
BL    func1
stop  B    stop

func1 LDR   r0, =42         ; => MOV r0, #42
      LDR   r1, =0x12345678 ; => LDR r1, [PC, #offset]
      LDR   r2, =0xFFFFFFFF ; => MVN r2, #0
      BX    lr
      LTORG                 ; literal pool here, contains 0x12345678

func2 LDR   r3, =0x12345678 ; reuse from pool
      BX    lr
END
```

**Important**: Place `LTORG` after unconditional branches or subroutine returns to prevent executing constants as instructions.

## 6.4 Loading Constants with MOVW, MOVT (Cortex-M4)

If `LDR =` is not supported (e.g., pure CCS), you can load any 32-bit constant using two 16-bit moves:

```asm
; Load 0xBEEFFACE into r3
MOVW   r3, #0xFACE     ; loads lower 16 bits (0xFACE)
MOVT   r3, #0xBEEF     ; loads upper 16 bits (0xBEEF)
```

## 6.5 Loading Addresses into Registers

### ADR / ADRL
Calculates PC-relative offset to a label.
```asm
ADR   r1, DataArea      ; creates ADD/SUB instruction based on PC
ADRL  r2, DataArea+4300 ; handles larger offsets by using two instructions
```
- Label must be in the **same code section**.

### LDR =,label
Resolves addresses at link time, can reference labels in **other sections**, places address in literal pool.
```asm
LDR   r0, =start        ; places address of 'start' in literal pool
```