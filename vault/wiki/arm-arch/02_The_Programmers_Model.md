---
title: ARM Architecture Chapter 2 Programmer's Model
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 2: Programmer's Model

## 2.1 Data Types

| Type | Size |
|------|------|
| Byte | 8 bits |
| Halfword | 16 bits |
| Word | 32 bits |

ARM7TDMI: halfwords must be aligned to 2-byte boundaries, words to 4-byte boundaries.
Cortex-M4: allows unaligned accesses under certain conditions.

## 2.2 ARM7TDMI Processor Modes

Seven processor modes (Version 4T):

| Mode | Description |
|------|-------------|
| User | Normal program execution (Unprivileged) |
| Supervisor (SVC) | Entered on reset and when a Software Interrupt (SWI) instruction is executed |
| IRQ | Entered when a low priority (normal) interrupt is raised |
| FIQ | Entered when a high priority (fast) interrupt is raised |
| Abort | Used to handle memory access violations |
| Undefined | Used to handle undefined instructions |
| System | Privileged mode using the same registers as User mode |

### Registers (ARM7TDMI)

37 total registers: 30 general-purpose, 6 status, 1 PC.

**Banked registers** (swapped automatically based on processor mode):
- r13 (SP): Stack pointer, holds address of the stack in memory. Unique per mode (except System/User share).
- r14 (LR): Link register, holds subroutine/exception return addresses. Unique per mode (except System/User share).
- r15 (PC): Program Counter.
- SPSR: Saved Program Status Register. Preserves the value of CPSR during an exception. Unique per privileged mode (User/System do not have one).

**CPSR bits** (Current Program Status Register, bits 31-0):
- N (31): Negative
- Z (30): Zero
- C (29): Carry
- V (28): Overflow
- I (7): IRQ disable
- F (6): FIQ disable
- T (5): Thumb state (1 = executing 16-bit Thumb code)
- M[4:0]: Mode bits

**Mode Bit Encodings** (xPSR[4:0]):
- 10000: User mode
- 10001: FIQ mode
- 10010: IRQ mode
- 10011: Supervisor mode
- 10111: Abort mode
- 11011: Undefined mode
- 11111: System mode

### Exception Vector Table (ARM7TDMI)

Contains actual branch instructions (not just addresses).

| Exception Type | Mode | Vector Address |
|----------------|------|----------------|
| Reset | SVC | 0x00000000 |
| Undefined instruction | UNDEF | 0x00000004 |
| Software Interrupt (SVC) | SVC | 0x00000008 |
| Prefetch abort | ABT | 0x0000000C |
| Data abort | ABT | 0x00000010 |
| IRQ (interrupt) | IRQ | 0x00000018 |
| FIQ (fast interrupt) | FIQ | 0x0000001C |

## 2.3 Cortex-M4 Processor Modes

Two operation modes:
- **Thread mode**: Applications
- **Handler mode**: Exception handling (always privileged)

Two access levels (Thread mode only):
- **Privileged**: Full access
- **User**: Unprivileged

### Registers (Cortex-M4)

16 general-purpose registers (r0-r12), plus:
- r13 (SP): Two stack pointers - MSP (Main Stack Pointer) and PSP (Process Stack Pointer)
- r14 (LR): Link register
- r15 (PC): Program Counter

**xPSR** (program status register, three specialized views):
- APSR: Application program status (N, Z, C, V, Q, GE flags). Q is sticky saturation flag.
- IPSR: Interrupt program status (ISRNUM exception number)
- EPSR: Execution program status (ICI/IT bits, T bit)

**Special registers**:
- PRIMASK: Mask standard interrupts (1 bit)
- FAULTMASK: Mask hard faults (1 bit)
- BASEPRI: Set interrupt priority threshold (up to 8 bits)
- CONTROL: Access level (bit 0), stack selection (bit 1), FPCA (bit 2)

**FPU Registers** (if present):
- 32 single-precision floating-point registers (s0-s31) or 16 double-precision registers (d0-d15)

### Exception Vector Table (Cortex-M4)

Contains addresses to the exception handlers (not instructions). The LSB of the address must be set to 1 (indicating Thumb state).

| Exception Type | Exception No. | Vector Address |
|----------------|---------------|----------------|
| Top of Stack | - | 0x00000000 |
| Reset | 1 | 0x00000004 |
| NMI | 2 | 0x00000008 |
| Hard fault | 3 | 0x0000000C |
| Memory management fault| 4 | 0x00000010 |
| Bus fault | 5 | 0x00000014 |
| Usage fault | 6 | 0x00000018 |
| SVcall | 11 | 0x0000002C |
| Debug monitor | 12 | 0x00000030 |
| PendSV | 14 | 0x00000038 |
| SysTick | 15 | 0x0000003C |
| Interrupts | 16 and above | 0x00000040 and above |
