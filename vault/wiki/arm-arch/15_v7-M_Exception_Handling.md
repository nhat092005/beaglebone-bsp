---
title: ARM Architecture Chapter 15 v7-M Exception Handling
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 15: v7-M Exception Handling

## 15.1 Operation Modes and Privilege Levels

The Cortex-M3/M4 (v7-M) has a simplified mode model compared to earlier ARM cores.

**Two Operation Modes**:
- **Thread mode**: Used for normal application execution.
- **Handler mode**: Used exclusively for exception handling. (Always privileged).

**Two Privilege Levels**:
- **Privileged**: Full access to all resources (MPU, NVIC, system control).
- **User (Unprivileged)**: Restricted access. Cannot change its own privilege level.

*Transition*: The processor starts in Privileged Thread mode. Software can drop to User mode by modifying the `CONTROL` register. To return to Privileged mode, an exception (like an SVC call) must be triggered to enter Handler mode.

## 15.2 Vector Table

Unlike the ARM7TDMI (which uses branch instructions), the v7-M vector table contains **addresses** pointing to the handlers. The LSB of every address must be `1` to indicate Thumb state.

| Exception No. | Exception Type | Priority | Vector Address | Description |
|---------------|----------------|----------|----------------|-------------|
| - | Top of Stack | - | `0x00000000` | Initial Main Stack Pointer (MSP) value |
| 1 | Reset | -3 (highest) | `0x00000004` | Reset handler address |
| 2 | NMI | -2 | `0x00000008` | Non-Maskable Interrupt |
| 3 | Hard Fault | -1 | `0x0000000C` | Catch-all for disabled or escalated faults |
| 4 | Mem Mgmt Fault | Programmable | `0x00000010` | MPU violation or illegal access |
| 5 | Bus Fault | Programmable | `0x00000014` | AHB bus error (instruction or data) |
| 6 | Usage Fault | Programmable | `0x00000018` | Undefined instruction, divide by zero, unaligned access |
| 11 | SVCall | Programmable | `0x0000002C` | Supervisor Call (software interrupt) |
| 14 | PendSV | Programmable | `0x00000038` | Pendable Service Call (used by OS for context switching) |
| 15 | SysTick | Programmable | `0x0000003C` | System Tick Timer |
| 16+ | External Interrupts | Programmable | `0x00000040+` | Peripherals (UART, Timers, GPIO, etc.) |

## 15.3 Exception Entry and Stacking

When an exception occurs, the hardware automatically pushes an 8-word **stack frame** to the current stack (MSP or PSP).

**Registers pushed (in order)**:
1. `xPSR`
2. `PC` (Return Address)
3. `LR` (r14)
4. `r12`
5. `r3`, `r2`, `r1`, `r0`

*(If the FPU is active, it may also push `s0-s15` and the `FPSCR`).*

The processor then:
1. Reads the handler address from the vector table.
2. Loads a special `EXC_RETURN` value into the `LR`.

### EXC_RETURN Values
This value tells the processor how to return and which stack to use when exiting the exception.
- `0xFFFFFFE1`: Return to Handler mode, use MSP, Restore FPU state.
- `0xFFFFFFE9`: Return to Thread mode, use MSP, Restore FPU state.
- `0xFFFFFFED`: Return to Thread mode, use PSP, Restore FPU state.
- `0xFFFFFFF1`: Return to Handler mode, use MSP.
- `0xFFFFFFF9`: Return to Thread mode, use MSP.
- `0xFFFFFFFD`: Return to Thread mode, use PSP.

## 15.4 Exception Exit

To return from an exception, the software simply moves the `EXC_RETURN` value from the `LR` into the `PC`. The hardware detects this special value and automatically un-stacks the registers.

```asm
; Typical exit if LR wasn't modified
BX  lr
```

## 15.5 Configuring Exceptions (NVIC and SCB)

Many faults (Usage, Bus, MemMgmt) are disabled by default. If a disabled fault occurs, it escalates to a **Hard Fault**.

**Enabling Usage Faults and Divide-By-Zero trapping**:
```asm
NVICBase     EQU 0xE000E000
SYSHNDCTRL   EQU 0xD24       ; System Handler Control and State
CCR          EQU 0xD14       ; Configuration and Control Register

LDR r6, =NVICBase

; Enable divide-by-zero trap (Bit 4 of CCR)
LDR r1, [r6, #CCR]
ORR r1, #0x10
STR r1, [r6, #CCR]

; Enable Usage Fault (Bit 18 of SYSHNDCTRL)
LDR r1, [r6, #SYSHNDCTRL]
ORR r1, #0x40000
STR r1, [r6, #SYSHNDCTRL]
```

## 15.6 Interrupts via NVIC

The Nested Vectored Interrupt Controller (NVIC) handles external interrupts. Each peripheral interrupt must be explicitly enabled in the NVIC.

**Example: Enabling Timer 0A Interrupt**
Timer 0A is typically IRQ 19 (Check device datasheet). To enable it, write to the NVIC Interrupt Set Enable Register (ISER0 at offset `0x100`).

```asm
NVICBase EQU 0xE000E000
ISER0    EQU 0x100

LDR r6, =NVICBase
MOV r1, #(1 << 19)       ; Bit 19 corresponds to IRQ 19
STR r1, [r6, #ISER0]
```
