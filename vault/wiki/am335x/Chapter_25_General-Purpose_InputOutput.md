---
title: AM335x Chapter 25 — GPIO (Condensed Wiki)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 25 General-Purpose Input/Output (GPIO)

## Overview

Four GPIO modules (GPIO0–GPIO3), each with 32 pins, for a total of up to **128 GPIO pins**. Each pin can be used as: data I/O, keyboard interface with debounce, interrupt source, or wake-up source.

**Important:** Wake-up is only supported on **GPIO0** (Wakeup domain). GPIO1–GPIO3 are in the Peripheral domain.

---

## Module Base Addresses

| Module | Base Address | Domain     | Wake-up |
| ------ | ------------ | ---------- | ------- |
| GPIO0  | 0x44E07000   | Wakeup     | Yes     |
| GPIO1  | 0x4804C000   | Peripheral | No      |
| GPIO2  | 0x481AC000   | Peripheral | No      |
| GPIO3  | 0x481AE000   | Peripheral | No      |

---

## Integration

Each GPIO module has 32 I/O pins. Two interrupt lines per module for dual-processor operation. All GPIO registers are 8/16/32-bit accessible (little-endian).

---

## Operating Modes

| Mode     | Description                                                             |
| -------- | ----------------------------------------------------------------------- |
| Active   | Module running; interrupts can be generated                             |
| Idle     | Interface clock can be stopped; no interrupts; wake-up can be generated |
| Inactive | No activity; no interrupts; wake-up inhibited                           |
| Disabled | All internal clock paths gated; no interrupts or wake-up possible       |

IDLEMODE field in GPIO_SYSCONFIG controls Idle/Inactive behavior:

- 0h = Force-idle: module enters Inactive unconditionally; wake-up totally inhibited.
- 1h = No-idle: module never enters idle; Idle acknowledge never sent.
- 2h/3h = Smart-idle: module enters idle only when no internal activity (no pending interrupts, no data capture in progress).

> **Note:** GPIO enters Smart-idle only when GPIO_IRQSTATUS_RAW_n registers have no active bits.

---

## Clocking and Reset

### Two clock domains

- **Interface clock:** OCP bus clock. Clocks OCP interface and all internal logic. Used for event detection (rising edge sampling), data capture, and data output.
- **Debouncing clock:** 32 kHz. Used for the debounce sub-module only. Each tick = 31 µs.

### Clock gating

AUTOIDLE bit in GPIO_SYSCONFIG: 0 = interface clock free-running (2-cycle GPIO_DATAIN latency); 1 = auto-gating (3-cycle GPIO_DATAIN latency).

GATINGRATIO in GPIO_CTRL: divides interface clock for event detection (0=÷1, 1=÷2, 2=÷4, 3=÷8).

DISABLEMODULE in GPIO_CTRL: 1 = gate all internal clocks; takes precedence over all other bits.

### Reset

SOFTRESET bit in GPIO_SYSCONFIG: same effect as hardware reset. RESETDONE in GPIO_SYSSTATUS is set when reset is complete on both clock domains.

---

## Peripheral Features

### Data I/O

- **GPIO_OE** (reset = 0xFFFFFFFF): Output Enable. 0 = output, 1 = input (all pins default to input at reset).
- **GPIO_DATAIN:** Sampled input. Read-only. Captured 2 interface clock cycles after pin level change (or 3 cycles if AUTOIDLE=1).
- **GPIO_DATAOUT:** Written output value. Driven on pin when GPIO_OE bit = 0.

### Set/Clear Protocol (atomic bit operations)

To allow concurrent access by two processors without read-modify-write conflicts:

| Register           | Write 1 effect                       | Read returns        |
| ------------------ | ------------------------------------ | ------------------- |
| GPIO_SETDATAOUT    | Set corresponding GPIO_DATAOUT bit   | GPIO_DATAOUT value  |
| GPIO_CLEARDATAOUT  | Clear corresponding GPIO_DATAOUT bit | GPIO_DATAOUT value  |
| GPIO_SETIRQENABLE1 | Set corresponding IRQENABLE1 bit     | IRQENABLE1 value    |
| GPIO_SETIRQENABLE2 | Set corresponding IRQENABLE2 bit     | IRQENABLE2 value    |
| GPIO_SETWKUENA     | Set corresponding wakeup enable bit  | wakeup enable value |

### Interrupt Generation

Two interrupt lines per module (INTLINE_0 and INTLINE_1). Each pin can trigger interrupts on:

- Low level (GPIO_LEVELDETECT0)
- High level (GPIO_LEVELDETECT1)
- Rising edge (GPIO_RISINGDETECT)
- Falling edge (GPIO_FALLINGDETECT)

Enabling both level-detect0 and level-detect1 for the same pin creates a constant interrupt.

**Interrupt flow:**

1. Event detected → bit set in GPIO_IRQSTATUS_RAW_n (both enabled and disabled events).
2. If interrupt enabled (GPIO_IRQSTATUS_SET_n) → bit set in GPIO_IRQSTATUS_n → IRQ asserted.
3. Service interrupt → write 1 to GPIO_IRQSTATUS_n to clear (W1C).
4. For DMA: write 1 to GPIO_EOI after DMA completes.

### Debouncing

Enable debounce per pin in GPIO_DEBOUNCEENABLE (bit n = 1). Set debounce time in GPIO_DEBOUNCINGTIME (global for all pins in one module):

```
Debouncing time = (DEBOUNCETIME + 1) × 31 µs
```

Where DEBOUNCETIME is 0–255 (range: 31 µs to 7.936 ms).

Pin must be configured as input (GPIO_OE bit = 1) for debounce to function.

> **Note:** Check if debouncing clock is active in Idle mode. If inactive, debounce cannot be used and would gate all inputs.

### Keyboard Interface

Configure row channels as inputs with debounce enabled (external pull-up). Configure column channels as outputs driving low. When a key is pressed, the row-column intersection shorts, driving the row low and generating an interrupt. Software scans columns to identify pressed keys.

---

## Register Map

| Offset | Acronym              | Register Name                          |
| ------ | -------------------- | -------------------------------------- |
| 0h     | GPIO_REVISION        | Revision [reset=50600801h]             |
| 10h    | GPIO_SYSCONFIG       | System Configuration [reset=0h]        |
| 20h    | GPIO_EOI             | End of Interrupt (DMA ack) [reset=0h]  |
| 24h    | GPIO_IRQSTATUS_RAW_0 | IRQ Raw Status (line 0) [reset=0h]     |
| 28h    | GPIO_IRQSTATUS_RAW_1 | IRQ Raw Status (line 1) [reset=0h]     |
| 2Ch    | GPIO_IRQSTATUS_0     | IRQ Status (line 0) W1C [reset=0h]     |
| 30h    | GPIO_IRQSTATUS_1     | IRQ Status (line 1) W1C [reset=0h]     |
| 34h    | GPIO_IRQSTATUS_SET_0 | IRQ Enable Set (line 0) [reset=0h]     |
| 38h    | GPIO_IRQSTATUS_SET_1 | IRQ Enable Set (line 1) [reset=0h]     |
| 3Ch    | GPIO_IRQSTATUS_CLR_0 | IRQ Enable Clear (line 0) [reset=0h]   |
| 40h    | GPIO_IRQSTATUS_CLR_1 | IRQ Enable Clear (line 1) [reset=0h]   |
| 44h    | GPIO_IRQWAKEN_0      | IRQ Wakeup Enable (line 0) [reset=0h]  |
| 48h    | GPIO_IRQWAKEN_1      | IRQ Wakeup Enable (line 1) [reset=0h]  |
| 114h   | GPIO_SYSSTATUS       | System Status (RESETDONE) [reset=0h]   |
| 130h   | GPIO_CTRL            | Module Control [reset=0h]              |
| 134h   | GPIO_OE              | Output Enable [reset=FFFFFFFFh]        |
| 138h   | GPIO_DATAIN          | Data Input (read-only) [reset=0h]      |
| 13Ch   | GPIO_DATAOUT         | Data Output [reset=0h]                 |
| 140h   | GPIO_LEVELDETECT0    | Low-Level Detect [reset=0h]            |
| 144h   | GPIO_LEVELDETECT1    | High-Level Detect [reset=0h]           |
| 148h   | GPIO_RISINGDETECT    | Rising Edge Detect [reset=0h]          |
| 14Ch   | GPIO_FALLINGDETECT   | Falling Edge Detect [reset=0h]         |
| 150h   | GPIO_DEBOUNCENABLE   | Debounce Enable [reset=0h]             |
| 154h   | GPIO_DEBOUNCINGTIME  | Debouncing Time [reset=0h]             |
| 190h   | GPIO_CLEARDATAOUT    | Clear Data Output (set/clear protocol) |
| 194h   | GPIO_SETDATAOUT      | Set Data Output (set/clear protocol)   |

### Key Register Fields

**GPIO_SYSCONFIG:**

| Bits | Field     | Function                                                                |
| ---- | --------- | ----------------------------------------------------------------------- |
| 4–3  | IDLEMODE  | 0=Force-idle, 1=No-idle, 2=Smart-idle, 3=Smart-idle wakeup (GPIO0 only) |
| 2    | ENAWAKEUP | 0=wakeup disabled, 1=wakeup enabled                                     |
| 1    | SOFTRESET | Write 1 to trigger software reset (auto-clears)                         |
| 0    | AUTOIDLE  | 0=clock free-running, 1=auto clock gating                               |

**GPIO_CTRL:**

| Bits | Field         | Function                                      |
| ---- | ------------- | --------------------------------------------- |
| 2–1  | GATINGRATIO   | Event detection clock: 0=÷1, 1=÷2, 2=÷4, 3=÷8 |
| 0    | DISABLEMODULE | 0=enabled, 1=all clocks gated                 |

**GPIO_DEBOUNCINGTIME:**

| Bits | Field        | Function                        |
| ---- | ------------ | ------------------------------- |
| 7–0  | DEBOUNCETIME | 0–255; time = (value+1) × 31 µs |

---

## Quick-Reference Notes

1. All GPIO pins default to **INPUT** mode at reset (GPIO_OE = FFFFFFFFh).
2. Write **1 to clear** interrupt status (W1C pattern in GPIO_IRQSTATUS_0/1).
3. Use **GPIO_SETDATAOUT / GPIO_CLEARDATAOUT** for safe atomic output operations in multi-processor systems.
4. **Wakeup supported only on GPIO0**; must set ENAWAKEUP=1 in GPIO_SYSCONFIG and configure GPIO_IRQWAKEN registers.
5. GPIO_IRQSTATUS_RAW shows all events; GPIO_IRQSTATUS shows only enabled events.
6. GPIO_EOI must be written after DMA transfer completes to allow next DMA event.
7. **Smart-idle** will not enter idle if any bit is set in GPIO_IRQSTATUS_RAW_n registers.
