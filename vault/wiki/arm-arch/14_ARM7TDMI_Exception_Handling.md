---
title: ARM Architecture Chapter 14 ARM7TDMI Exception Handling
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 14: ARM7TDMI Exception Handling (v4T)

## 14.1 Exception Types

| Exception | Vector | Mode |
|-----------|--------|------|
| Reset | 0x00000000 | SVC |
| Undefined instruction | 0x00000004 | UNDEF |
| SWI (Software Interrupt) | 0x00000008 | SVC |
| Prefetch abort | 0x0000000C | ABT |
| Data abort | 0x00000010 | ABT |
| IRQ | 0x00000018 | IRQ |
| FIQ | 0x0000001C | FIQ |

## 14.2 Exception Sequence

1. CPSR → SPSR_<mode>
2. Set CPSR: switch to mode, disable interrupts, enter ARM state
3. Return address → LR_<mode>
4. PC → vector address

## 14.3 Interrupt Types

**IRQ (Normal interrupt)**: Shared, lower priority
**FIQ (Fast interrupt)**: Dedicated register bank, higher priority

**Enable/Disable**:
```asm
; Enable IRQ
MRS   r0, cpsr
BIC   r0, r0, #0x80
MSR   cpsr_c, r0

; Disable IRQ
MRS   r0, cpsr
ORR   r0, r0, #0x80
MSR   cpsr_c, r0
```

## 14.4 Return from Exception

**Using SPSR and LR**:
```asm
; For IRQ, SVC, etc.
SUBS  pc, lr, #4    ; adjust for pipeline
; or
MSR   spsr_cxsf, r0 ; restore CPSR
MOVS  pc, lr

; For FIQ (no subtraction needed)
MOVS  pc, lr
```

## 14.5 SWI (Software Interrupt)

Used for OS calls:

```asm
; Call SWI
SWI   0x123456      ; software interrupt

; Handler
SVC_handler
    ; r0 contains SWI number
    LDR   r0, [lr, #-4]   ; get SWI instruction
    BIC   r0, r0, #0xFF000000
    ; handle request
    MOVS  pc, lr
```

## 14.6 Abort Handling

**Prefetch abort**: Instruction fetch failed
**Data abort**: Data access failed

```asm
DataAbort_Handler
    SUB   lr, lr, #8       ; address of failing instruction
    PUSH  {r0-r12, lr}
    ; investigate cause
    ; possibly fix and retry
    POP   {r0-r12, pc}^   ; restore and return
```

## 14.7 FIQ Handler

FIQ has dedicated registers (r8-r12) - faster:

```asm
FIQ_Handler
    ; use r8-r12 without saving
    ; ...
    SUBS  pc, lr, #4
```
