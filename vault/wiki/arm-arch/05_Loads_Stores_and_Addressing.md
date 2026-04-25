---
title: ARM Architecture Chapter 5 Loads, Stores, and Addressing
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 5: Loads, Stores, and Addressing

## 5.1 Load/Store Instructions

RISC architectures require explicit Load/Store instructions - data must be moved between memory and registers using dedicated instructions.

### Basic Instructions

| Load | Store | Data Size |
|------|-------|-----------|
| LDR | STR | Word (32 bits) |
| LDRB | STRB | Byte (8 bits) |
| LDRH | STRH | Halfword (16 bits) |
| LDRSB | - | Signed byte |
| LDRSH | - | Signed halfword |
| LDM | STM | Multiple words |

**Syntax**: `LDR|STR{<size>}{<cond>} <Rd>, <addressing_mode>`

### Signed vs Unsigned
- Signed loads (LDRSB, LDRSH): Sign-extend to 32 bits
- Unsigned loads: Zero-extend to 32 bits

## 5.2 Addressing Modes

Two main types: **pre-indexed** and **post-indexed**.

### Pre-Indexed Addressing
```
LDR|STR{<size>}{<cond>} <Rd>, [<Rn>, <offset>]{!}
```
- Offset added to base register before transfer
- Optional `!` writes effective address back to Rn

**Examples**:
```asm
LDR   r5, [r3]              ; ea = r3
STRB  r0, [r9]              ; store byte to ea <r9>
STR   r3, [r0, r5, LSL #3]  ; ea = r0 + (r5<<3)
LDR   r1, [r0, #4]!         ; load from r0+4, update r0
STRB  r7, [r6, #-1]!        ; store byte to r6-1, update r6
```

### Post-Indexed Addressing
```
LDR|STR{<size>}{<cond>} <Rd>, [<Rn>], <offset>
```
- Base register used unchanged for address
- Offset added after transfer, result written back to Rn

**Examples**:
```asm
LDR   r3, [r9], #4   ; load from r9, then r9 = r9+4
STR   r2, [r5], #8   ; store to r5, then r5 = r5+8
STRH  r2, [r5], #8   ; store halfword, then r5 = r5+8
```

### ARM7TDMI Addressing Options

| Type | Immediate Offset | Register Offset |
|------|------------------|-----------------|
| Word | 12 bits | Scaled (5-bit shift) |
| Halfword | 8 bits | Not supported |
| Unsigned byte | 12 bits | Scaled |

### Cortex-M4 Addressing Options

| Type | Immediate Offset | Register Offset |
|------|------------------|-----------------|
| Word | -255 to 4095 | LSL #0-3 only |
| Halfword | -255 to 255 | Supported |
| Signed byte/halfword | Supported | Supported |

## 5.3 Endianness

### Little-Endian
Least significant byte stored at lowest address.

**Example**: 0x0A0B0C0D stored at 0x400-0x403:
```
0x400: 0x0D
0x401: 0x0C
0x402: 0x0B
0x403: 0x0A
```

### Big-Endian
Most significant byte stored at lowest address.

**Example**: Same value 0x0A0B0C0D:
```
0x400: 0x0A
0x401: 0x0B
0x402: 0x0C
0x403: 0x0D
```

Default is little-endian (configurable on ARM7TDMI via BIGEND pin).

### Byte Swap (Cortex-M4)

```asm
; Single instruction
REV   r1, r0    ; reverse byte order (A B C D -> D C B A)
RBIT  r0, r0    ; reverse bit order
```

## 5.4 Bit-Banded Memory

Cortex-M3/M4: Map individual bits to unique addresses.

**Formula**:
```
bit-band alias = bit-band base + (byte_offset × 32) + (bit_number × 4)
```

**Regions**:
- SRAM: 0x20000000-0x20007FFF → alias 0x22000000-0x220FFFFF
- Peripherals: 0x40000000-0x400FFFFF → alias 0x42000000-0x43FFFFFF

**Example**: Set bit 7 of CAN controller at 0x40040000
```asm
; Alias = 0x42000000 + (0x40000*32) + (7*4) = 0x4280001C
LDR   r3, =0x4280001C
MOV   r4, #1
STR   r4, [r3]         ; single bit set operation
```

## 5.5 String Copy Example

```asm
SRAM_BASE EQU 0x04000000   ; 0x20000000 for Cortex-M4

AREA  StrCopy, CODE
ENTRY
Main    ADR   r1, srcstr       ; source pointer
LDR    r0, =SRAM_BASE        ; destination pointer
strcopy LDRB  r2, [r1], #1     ; load byte, increment
STRB   r2, [r0], #1          ; store byte, increment
CMP    r2, #0                ; check terminator
BNE    strcopy               ; continue if not done
stop   B     stop
srcstr DCB   "This is my (source) string", 0
END
```