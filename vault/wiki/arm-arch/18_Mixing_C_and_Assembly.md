---
title: ARM Architecture Chapter 18 Mixing C and Assembly
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 18: Mixing C and Assembly

## 18.1 Methods of Mixing

There are two primary ways to incorporate assembly language into a C or C++ application:
1. **Inline Assembler**: Writing assembly instructions directly inside C functions.
2. **Embedded Assembler**: Declaring complete assembly functions within C modules, or linking separate assembly (`.s`) files with C files.

## 18.2 Inline Assembler (Keil)

Used for optimizing short, critical sections of code or accessing CPU features not exposed by C (like coprocessor instructions, saturation math, or PSR access).

**Syntax**:
```c
__asm {
    instruction [; instruction]
    ...
}
```

**Key Features & Restrictions**:
- You can use C variables directly in the assembly instructions (the compiler handles the physical register mapping).
- You **must not** save/restore registers manually (like `PUSH`/`POP`); the compiler handles this.
- You **cannot** manually modify the `PC`, `SP`, or `LR`.
- Pseudo-instructions like `ADR`, `ADRL`, and `LDR =,` are not supported.
- `BX`, `BLX`, and `SVC` instructions are not supported.

**Example**: Q15 Fractional Multiply-Accumulate
```c
#define Q_Flag 0x08000000 

__inline int satmac(int a, int x, int y) {
    int i;
    __asm {
        SMULBB i, x, y     // signed multiply bottom 16-bits
        QDADD  a, a, i     // saturating double and add
    }
    return a;
}

__inline void Clear_Q_flag(void) {
    int temp;
    __asm {
        MRS temp, CPSR
        BIC temp, temp, #Q_Flag
        MSR CPSR_f, temp
    }
}
```

## 18.3 Embedded Assembler

Used for larger routines where full access to the instruction set (and pseudo-instructions) is needed. Functions written with `__asm` have the overhead of standard function calls.

**Syntax**:
```c
__asm return-type function-name(parameter-list) {
    instruction
    ...
    BX lr    // Must manually return!
}
```
- Argument names from the parameter list *cannot* be used in the body. You must use AAPCS registers (`r0`-`r3`).
- You can use the `__cpp` keyword to access C constants/expressions from assembly.
- Embedded assembler functions guarantee that the compiler will emit the instructions exactly as written.

## 18.4 Calling Between C and Separate Assembly Files

This is the standard approach in modern embedded systems. 

**Rule**: All cross-language calls must adhere strictly to the **ARM Architecture Procedure Call Standard (AAPCS)**.
- `r0`-`r3`: Arguments and return values.
- `r4`-`r11`: Must be preserved by the callee (saved to stack and restored).

### Calling a C Function from Assembly

**C Code**:
```c
int g(int a, int b, int c, int d, int e) {
    return a + b + c + d + e;
}
```

**Assembly Code**:
```asm
      IMPORT g              ; Declare external C function
      
      ; Assume arguments are calculated and placed in r0-r3
      STR   r4, [sp, #-4]!  ; 5th argument goes on the stack
      BL    g               ; Call C function. Result is in r0.
      ADD   sp, sp, #4      ; Clean up stack
```

### Calling an Assembly Function from C

**Assembly Code**:
```asm
      AREA SCopy, CODE, READONLY
      EXPORT strcopy
strcopy
      ; r0 = dest, r1 = src
      LDRB  r2, [r1], #1
      STRB  r2, [r0], #1
      CMP   r2, #0
      BNE   strcopy
      BX    lr
      END
```

**C Code**:
```c
extern void strcopy(char *d, const char *s);

int main() {
    const char *src = "Hello";
    char dst[10];
    strcopy(dst, src);
    return 0;
}
```

## 18.5 Using Hardware Features not present in C

Hardware conversion instructions (like fixed-point to floating-point) are highly efficient but not natively accessible in C. They can be wrapped in a separate assembly file.

**Assembly Routine**:
```asm
      AREA FixedFloatCvtRoutines, CODE, READONLY
      THUMB
      EXPORT CvtShorts8x8ToFloat

CvtShorts8x8ToFloat
      ; Input short is in r0
      VMOV.F32     s0, r0        ; Move to FPU register
      VCVT.F32.S16 s0, s0, #8    ; Convert signed 16-bit (8 fractional bits) to float
      BX           lr
      END
```

**C Usage**:
```c
extern float CvtShorts8x8ToFloat(short i);

short input = 1408;  // Represents 5.5 in S16 8x8 format
float result = CvtShorts8x8ToFloat(input);
```
