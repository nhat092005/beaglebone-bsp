---
title: ARM Architecture Chapter 13 Subroutines and Stacks
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 13: Subroutines and Stacks

## 13.1 The Stack

Stacks are Last In-First Out (LIFO) queues. In ARM, the stack pointer is `r13` (`SP`).

### LDM and STM Instructions
Load/Store Multiple instructions transfer one or more words using a base register. 
- Reduces code size and execution time compared to multiple single transfers.

**Syntax (ARM7TDMI)**: `LDM|STM <address-mode> {<cond>} <Rn> {!}, <reg-list> {^}`
**Syntax (Cortex-M4)**: `LDM|STM <address-mode> {<cond>} <Rn> {!}, <reg-list>`

- `!` updates the base register (`Rn`) after the transfer.
- The lowest register in the list is always mapped to the lowest memory address.

### Addressing Modes (ARM7TDMI)
- **IA**: Increment After
- **IB**: Increment Before
- **DA**: Decrement After
- **DB**: Decrement Before

*Note: Cortex-M4 only supports `IA` and `DB` for `LDM`/`STM`.*

### PUSH and POP
Synonymous with `STMDB` and `LDMIA` using the Stack Pointer (`SP`). Preferred in modern UAL.

```asm
PUSH {r3, r4}        ; Pushes r3, then r4 to the stack. SP is decremented.
POP  {r5, r6}        ; Pops values into r5, then r6. SP is incremented.
```

### Stack Types
ARM and Thumb C/C++ compilers use a **Full Descending** stack by default.
- **Descending**: Stack grows downward (high address to low address).
- **Full**: SP points to the last item placed on the stack (not the next empty space).

| Stack Type | PUSH equivalent | POP equivalent |
|------------|-----------------|----------------|
| Full descending | STMFD (STMDB) | LDMFD (LDMIA) |
| Empty descending| STMED (STMDA) | LDMED (LDMIB) |
| Full ascending | STMFA (STMIB) | LDMFA (LDMDA) |
| Empty ascending | STMEA (STMIA) | LDMEA (LDMDB) |

## 13.2 Subroutines

Called using the Branch and Link (`BL`) instruction. `BL` transfers the return address into the Link Register (`LR` / `r14`).

To make subroutines **reentrant** (capable of being safely interrupted or calling other subroutines), you must preserve the Link Register and any corrupted working registers on the stack immediately upon entry.

**Entry and Return Pattern**:
```asm
Myroutine
    PUSH  {r4-r7, lr}    ; Save working registers and return address
    ; ... subroutine code ...
    POP   {r4-r7, pc}    ; Restore registers and pop return address directly into PC
```

## 13.3 Passing Parameters

### 1. Passing in Registers
Fastest method. Subroutine expects data in specific registers.
```asm
MOV   r0, #0x40000000    ; param 1
MOV   r1, #2             ; param 2
BL    saturate           ; result returned in r2
```

### 2. Passing by Reference
Pass the memory address of the parameters. Efficient for large blocks of data.
```asm
LDR   r3, =SRAM_BASE + 100 ; Pointer to parameters
STMIA r3, {r1, r2}         ; Store params in memory
BL    saturate             ; Subroutine reads from [r3]
```

### 3. Passing on the Stack
Push parameters to the stack before calling. The subroutine reads them using offsets from the `SP`.
```asm
PUSH  {r1, r2}             ; Push parameters
BL    saturate
POP   {r1, r2}             ; Clean up stack / get result
```
*Note: Inside the subroutine, after pushing `r4-r7` and `lr` (5 words = 20 bytes/0x14), the first parameter is located at `[SP, #0x14]`.*

## 13.4 ARM Application Procedure Call Standard (AAPCS)

Defines a contract between calling and called routines to ensure interoperability.

**Register Usage**:
- `r0-r3` (a1-a4): Arguments passed into a function, and results returned.
- `r4-r8, r10, r11`: Local variables. **Must be preserved** (pushed/popped) by the subroutine if used.
- `r12` (IP): Scratch register / Intra-Procedure-call register (corruptible).
- `r13` (SP): Stack pointer. Stack must be 8-byte aligned.
- `r14` (LR): Link Register.
- `r15` (PC): Program Counter.

**Floating-Point**:
- `s0-s15`: Parameters/scratch (corruptible).
- `s16-s31`: **Must be preserved** by the subroutine.