---
title: ARM Architecture Chapter 8 Branches and Loops
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 8: Branches and Loops

## 8.1 Branch Instructions

### ARM7TDMI Branches (v4T)

| Instruction | Description |
|-------------|-------------|
| B | Branch (unconditional or conditional) |
| BX | Branch indirect (register target) |
| BL | Branch with Link (subroutine call) |

**Encoding**: `B` and `BL` use a 24-bit offset field. The offset is added to the PC after being shifted left by 2 bits.
**Range**: ±32 MB.

```asm
B     label          ; branch unconditionally
BL    subroutine     ; branch, saving return address in lr (r14)
BX    r14            ; return from subroutine
```
*Note: The Program Counter (PC) can also be directly modified: `MOV pc, #0x04000000` or `LDR pc, =0xBE000000`.*

### Cortex-M4 Branches (v7-M)

| Instruction | Description | Range |
|-------------|-------------|-------|
| B | Branch | ±16MB (32-bit), ±1MB (16-bit outside IT), ±256 bytes (inside IT) |
| BX | Branch indirect | - |
| BL | Branch with Link | ±16MB |
| BLX | Branch indirect with Link | - |
| CBZ / CBNZ | Compare and Branch if Zero/Nonzero | 4-130 bytes forward |

*Note for `BX`/`BLX`: The LSB of the address in the register must be 1, indicating Thumb state, otherwise a UsageFault occurs.*

```asm
BEQ.W label          ; Force 32-bit instruction for maximum range
CBZ   r2, label      ; If r2 == 0, branch forward to label
CBNZ  r2, label      ; If r2 != 0, branch forward to label
```

## 8.2 Condition Codes

Can be appended to branch instructions (and data processing instructions on v4T).

| Mnemonic | Flags Required | Meaning |
|----------|----------------|---------|
| EQ | Z=1 | Equal / Zero |
| NE | Z=0 | Not equal / Nonzero |
| CS / HS | C=1 | Carry Set / Unsigned ≥ |
| CC / LO | C=0 | Carry Clear / Unsigned < |
| MI | N=1 | Minus / Negative |
| PL | N=0 | Plus / Positive or Zero |
| VS | V=1 | Overflow Set |
| VC | V=0 | Overflow Clear |
| HI | C=1 & Z=0 | Unsigned > |
| LS | C=0 \| Z=1 | Unsigned ≤ |
| GE | N=V | Signed ≥ |
| LT | N≠V | Signed < |
| GT | Z=0 & N=V | Signed > |
| LE | Z=1 \| N≠V | Signed ≤ |

## 8.3 Conditional Execution

Branches flush the pipeline. Avoiding branches improves performance and code density.

### v4T Conditional Execution (ARM7TDMI)
Every ARM instruction contains a 4-bit condition field. Any instruction can be conditionally executed.

**Example**: Greatest Common Divisor
```asm
; Input: r0 = a, r1 = b
gcd   CMP    r0, r1
      SUBGT  r0, r0, r1      ; Executes only if r0 > r1
      SUBLT  r1, r1, r0      ; Executes only if r0 < r1
      BNE    gcd             ; Loops until equal
```

### v7-M Conditional Execution (Cortex-M4)
Thumb-2 uses the `IT` (If-Then) instruction to build conditional blocks of up to 4 instructions.

**Syntax**: `IT[x[y[z]]] <cond>`
- `T` = Then (condition matches)
- `E` = Else (inverse condition matches)
- First instruction following IT must be `T`.

**Example**:
```c
if (r6 == 8) r6 = 2; else r6 = r6 * 2;
```
```asm
CMP    r6, #8
ITE    EQ              ; If-Then-Else based on EQ condition
MOVEQ  r6, #2          ; THEN: executes if r6 == 8
LSLNE  r6, r6, #1      ; ELSE: executes if r6 != 8 (inverse of EQ is NE)
```

## 8.4 Loop Structures

### While Loop
Test condition at the start.
```asm
      MOV    r3, #100       ; j = 100
Loop  CBZ    r3, Exit       ; test condition
      ; ... do something ...
      SUB    r3, r3, #1     ; j--
      B      Loop
Exit
```

### For Loop (Optimized to count down)
Count down to zero to save instructions (the subtraction sets the Z flag).
```asm
      MOV    r1, #10        ; j = 10
Loop  ; ... do something ...
      SUBS   r1, r1, #1     ; j = j - 1 (sets flags)
      BNE    Loop           ; branch if j != 0
```

## 8.5 Loop Unrolling & Straight-Line Coding

To maximize speed, small loops can be "unrolled" by simply repeating the instructions sequentially, completely eliminating the branch overhead (pipeline flushes).

*Note: For normalizing values or counting leading zeros, Cortex-M4 includes a hardware instruction:*
```asm
CLZ   r2, r3             ; Count leading zeros in r3, place count in r2
```