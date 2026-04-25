---
title: ARM Architecture Chapter 3 Introduction to Instruction Sets
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 3: Introduction to Instruction Sets (v4T and v7-M)

## 3.1 Instruction Types

| Type | Width | Processors |
|------|-------|------------|
| ARM | 32 bits | ARM7TDMI, ARM9, ARM10, ARM11 |
| Thumb | 16 bits | ARM7TDMI, ARM9, ARM11, Cortex-A/R |
| Thumb-2 | 16/32 bits | Cortex-M3, M4 (Thumb-only) |

**Thumb-2**: A superset of Thumb instructions, including new 32-bit instructions for more complex operations. Cortex-M3 and M4 execute only Thumb-2 instructions (no traditional ARM instructions).

## 3.2 Basic Instruction Format

For most instructions (with some exceptions), the general format is:
`instruction destination, source, source`

Example:
`ADD r0, r0, r2`  ; r0 = r0 + r2

## 3.3 Example Programs

### Program 1: Shifting Data (ARM7TDMI)

```asm
AREA Prog1, CODE, READONLY
ENTRY
MOV       r0, #0x11          ; load initial value
LSL       r1, r0, #1         ; shift 1 bit left (result: 0x22)
LSL       r2, r1, #1         ; shift 1 bit left (result: 0x44)
stop      B         stop     ; infinite loop
END
```
*Note: The `B` instruction uses the Program Counter to create an address. It takes a 24-bit offset, shifts it left by two bits, and adds it to the PC.*

### Program 2: Factorial Calculation (ARM7TDMI)

Demonstrates conditional execution.

```asm
AREA Prog2, CODE, READONLY
ENTRY
MOV       r6, #10            ; load n into r6
MOV       r7, #1             ; if n = 0, at least n! = 1
loop      CMP       r6, #0   ; set flags
MULGT     r7, r6, r7         ; multiply conditionally if > 0
SUBGT     r6, r6, #1         ; decrement n conditionally if > 0
BGT       loop               ; branch if > 0
stop      B         stop     ; stop program
END
```

### Program 2b: Factorial Calculation (Cortex-M4)

Thumb-2 uses an IF-THEN (`IT`) block instead of conditional suffixes on every instruction.

```asm
MOV       r6, #10            ; load n into r6
MOV       r7, #1             ; if n = 0, at least n! = 1
loop      CMP       r6, #0
ITTT      GT                 ; start of IF-THEN block (3 THENs)
MULGT     r7, r6, r7
SUBGT     r6, r6, #1
BGT       loop               ; end of IF-THEN block
stop      B         stop     ; stop program
```

### Program 3: Swapping Register Contents

Uses Exclusive OR (EOR) to swap values without an intermediate register.

```asm
AREA Prog3, CODE, READONLY
ENTRY
LDR   r0, =0xF631024C  ; pseudo-instruction to load constant
LDR   r1, =0x17539ABD  ; pseudo-instruction to load constant
EOR   r0, r0, r1       ; r0 = r0 XOR r1
EOR   r1, r0, r1       ; r1 = r1 XOR r0
EOR   r0, r0, r1       ; r0 = r0 XOR r1
stop  B     stop       ; stop program
END
```

### Program 4: Playing with Floating-Point Numbers (Cortex-M4)

Enabling the FPU and performing a single-precision addition.

```asm
LDR         r0, =0xE000ED88  ; address of Coprocessor Access Control Register
LDR         r1, [r0]
ORR         r1, r1, #(0xF << 20) ; Enable CP10, CP11
STR         r1, [r0]

VMOV.F      s0, #0x3F800000  ; move single-precision 1.0 into s0
VMOV.F      s1, s0           ; copy to s1
VADD.F      s2, s1, s0       ; add. Result in s2 = 2.0 (0x40000000)
```

### Program 5: Moving Values Between Integer and Floating-Point Registers

```asm
; (Assuming FPU enabled as above)
LDR         r3, =0x3F800000  ; single precision 1.0 into integer reg
VMOV.F      s3, r3           ; transfer from ARM integer to FPU register
VLDR.F      s4, =6.0221415e23 ; load Avogadro's constant into FPU
VMOV.F      r4, s4           ; transfer from FPU back to ARM integer reg
```

## 3.4 Programming Guidelines

1. **Break the problem down**: Write and test small pieces.
2. **Always test**: Run a test case, even if it looks obvious. Check corner cases.
3. **Use software tools**: Utilize breakpoints, watchpoints, and register views.
4. **Comment your code**: Don't use obscure names. Note what you are thinking.
5. **Keep it simple**: Cleverness often leads to errors.
6. **Focus on functioning code first**: Optimize later.
7. **Experiment**: Don't be afraid to try instructions and observe the memory/register effects.
8. **Initialization**: Always explicitly initialize registers/variables to a known state before use, especially memory-mapped registers.
