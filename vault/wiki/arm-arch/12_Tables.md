---
title: ARM Architecture Chapter 12 Tables
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 12: Tables

## 12.1 Integer Lookup Tables

Lookup tables are efficient replacements for complex mathematical routines (like `sin`, `cos`, `log`), trading memory space for execution speed.

To access elements in a table, ARM addressing modes allow for pre-indexed addressing with a scaled offset based on the element number and data size.

### Addressing Examples
Assume `r5` holds the table's base address and `r4` holds the index.

**Word Elements (32-bit, 4 bytes)**:
```asm
LDR r6, [r5, r4, LSL #2]  ; Address = r5 + (r4 * 4)
```

**Halfword Elements (16-bit, 2 bytes)**:
```asm
LDRH r6, [r4, r5, LSL #1] ; Address = r4 + (r5 * 2) 
```

### Example: Sine Lookup Table (Q31 Format)

Generates `sin(x)` for integers 0-360 degrees by only storing a table for 0-90 degrees.
*Note: In Q31 format, `1.0` cannot be represented, so `0x7FFFFFFF` is used as an approximation.*

```asm
; Cortex-M4 Implementation
; r1 = argument (angle in degrees 0-360)
; r0 = return value (sine in Q31 format)

MOV   r7, r1            ; Copy argument
LDR   r2, =270          
ADR   r4, sin_data      ; Load base address of table
CMP   r1, #90           ; Determine quadrant
BLE   retvalue          ; First quadrant

CMP   r1, #180          
ITT   LE
RSBLE r1, r1, #180      ; Second quadrant: angle = 180 - angle
BLE   retvalue

CMP   r1, r2
ITT   LE
SUBLE r1, r1, #180      ; Third quadrant: angle = angle - 180
BLE   retvalue

RSB   r1, r1, #360      ; Fourth quadrant: angle = 360 - angle

retvalue
LDR   r0, [r4, r1, LSL #2] ; Load sine value from table (scaled by 4)
CMP   r7, #180             ; Check original angle for sign
IT    GT
RSBGT r0, r0, #0           ; Negate result if in quadrant 3 or 4

done  B  done

ALIGN
sin_data
DCD 0x00000000, 0x023BE164, 0x04779630, 0x06B2F1D8
; ... (rest of 0-90 degree table) ...
```

## 12.2 Floating-Point Lookup Tables

Floating-point lookup tables operate exactly the same way, but use `VLDR` instructions.
```asm
VLDR.F s2, [r1, #20]    ; Load float from address r1 + 20
```

### Constant Pools / Literal Tables
For loading non-immediate floating-point constants, you can define a table and use offsets:
```asm
      VLDR.F s5, C_Pi
      VLDR.F s6, C_Ten
      VMUL.F s7, s5, s6

      ALIGN
C_Ten DCD 0x41200000 ; 10.0
C_Pi  DCD 0x40490FDB ; pi
```

## 12.3 Binary Searches

A binary search efficiently finds a key in a sorted table by repeatedly halving the search interval. It takes logarithmic time compared to a linear search.

### ARM Implementation Setup
Assume a table where each entry is 16 bytes (a 4-byte key followed by 12 bytes of data). The scale factor `ESIZE` is `4` (since 2^4 = 16).

```asm
NUM    EQU 14  ; Number of entries
ESIZE  EQU 4   ; log2 of entry size (16 bytes = 2^4)

LDR    r5, =0x200          ; Key to search for
ADR    r6, table_start     ; Base address
MOV    r0, #0              ; first = 0
MOV    r1, #NUM-1          ; last = NUM - 1

loop   CMP    r0, r1              ; Check if first <= last
       MOVGT  r2, #0              ; Not found
       BGT    done

       ADD    r2, r0, r1          ; first + last
       MOV    r2, r2, ASR #1      ; middle = (first + last) / 2

       LDR    r7, [r6, r2, LSL #ESIZE] ; Load key from table
       CMP    r5, r7              ; Compare search key vs table key

       ADDGT  r0, r2, #1          ; if search_key > table_key: first = middle + 1
       SUBLT  r1, r2, #1          ; if search_key < table_key: last = middle - 1
       BNE    loop                ; Repeat if not equal

done   MOV    r3, r2              ; r3 = index of found item
stop   B      stop

table_start
DCD    0x004
DCB    "PEPPERONI   "
; ... entries ...
```