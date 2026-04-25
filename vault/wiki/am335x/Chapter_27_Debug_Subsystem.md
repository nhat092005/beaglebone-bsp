---
title: AM335x Chapter 27 — Debug Subsystem
tags:
  - am335x
  - debug
  - jtag
  - icepick
  - reference
source: "AM335x TRM Chapter 27"
---

# 27 Debug Subsystem

## 27.1 Introduction

The AM335x Debug Subsystem provides JTAG-based debug access to the Cortex-A8 MPU and other on-chip resources. It includes:

- **ICEPick-D** module for TAP management and power/clock control
- **Debug Resource Manager (DRM)** for peripheral suspend control during debug halt
- **IEEE 1149.1 JTAG** interface (5 standard signals + EMU pins)

### 27.1.1 Key Features

| Feature             | Description                                       |
| ------------------- | ------------------------------------------------- |
| JTAG ID Code        | 0x0B98_C02F (accessed via ICEPick)                |
| ICEPick Version     | ICEPick-D                                         |
| TAP Controllers     | Up to 16 dynamically insertable TAPs              |
| Debug Suspend       | 19 peripherals support debug halt suspend         |
| Boot Modes          | Controlled via EMU0/EMU1 pins at POR              |
| Wait-in-Reset (WIR) | Holds processors in reset until debugger releases |

---

## 27.2 JTAG Interface

### 27.2.1 IEEE 1149.1 Signals

| Signal | Type | Description                                          |
| ------ | ---- | ---------------------------------------------------- |
| nTRST  | I    | Test reset (active low); resets all test/debug logic |
| TCK    | I    | Test clock for JTAG TAP state machine                |
| TMS    | I    | Test mode select; directs TAP state transitions      |
| TDI    | I    | Test data input                                      |
| TDO    | O    | Test data output                                     |
| EMU0   | I/O  | Emulation 0: boot mode / trigger / trace             |
| EMU1   | I/O  | Emulation 1: boot mode / trigger / trace             |
| EMU2   | O    | Emulation 2: trace port (20-pin header only)         |
| EMU3   | O    | Emulation 3: trace port (20-pin header only)         |
| EMU4   | O    | Emulation 4: trace port (20-pin header only)         |

**JTAG header options:**

- 14-pin: nTRST, TCK, TMS, TDI, TDO, EMU[1:0], GND, VCC
- 20-pin: adds EMU[4:2] for trace port

---

## 27.3 ICEPick Module

### 27.3.1 Overview

ICEPick-D manages multiple JTAG TAPs in the SoC and provides power/reset/clock control for debug. The debugger connects to the device through ICEPick, which acts as the first-level debug interface.

### 27.3.2 ICEPick Capabilities

- **Dynamic TAP insertion**: Serially link up to 16 TAP controllers; individually select TAPs without disrupting others
- **Power/clock management**: Force power domains on, prevent clock gating during debug
- **Reset control**: Apply system reset, global/local WIR release, reset blocking
- **Debug connect logic**: Requires connect register key (predefined) to enable full JTAG instruction set

### 27.3.3 Boot Modes (EMU1:EMU0 at POR)

| EMU1 | EMU0 | Mode     | TAPs in TDI→TDO Path | Description                                  |
| ---- | ---- | -------- | -------------------- | -------------------------------------------- |
| 0    | 0    | Reserved | —                    | Do not use                                   |
| 0    | 1    | Reserved | —                    | Do not use                                   |
| 1    | 0    | WIR      | ICEPick only         | Wait-in-Reset mode; processors held in reset |
| 1    | 1    | Default  | ICEPick only         | Normal boot (recommended)                    |

**Default boot mode (EMU1=1, EMU0=1):**

- ICEPick TAP is the only TAP between TDI and TDO
- No secondary TAPs selected initially
- Recommended for normal operation

**Wait-in-Reset mode (EMU1=1, EMU0=0):**

- All processors with TAPs are held in reset until debugger releases them
- Allows debugger to attach before code execution
- Local release: individual processor
- Global release: all processors simultaneously
- **Note**: PRU cores in PRU-ICSS do **not** support WIR

---

## 27.4 Debug Resource Manager (DRM)

### 27.4.1 Peripheral Suspend Control

When the Cortex-A8 is halted by a debugger, peripherals must respond appropriately to avoid incorrect behavior (e.g., watchdog timer firing a reset during a long debug session).

The DRM provides per-peripheral suspend control registers to gate the debug suspend signal from the CPU to each peripheral.

### 27.4.2 Supported Peripherals

19 peripherals support debug suspend:

| Peripheral     | DRM Register Offset | Peripheral | DRM Register Offset |
| -------------- | ------------------- | ---------- | ------------------- |
| Watchdog Timer | 0x200               | I2C-0      | 0x228               |
| DMTimer 0      | 0x204               | I2C-1      | 0x22C               |
| DMTimer 1      | 0x208               | I2C-2      | 0x230               |
| DMTimer 2      | 0x20C               | eHRPWM-0   | 0x234               |
| DMTimer 3      | 0x210               | eHRPWM-1   | 0x238               |
| DMTimer 4      | 0x214               | eHRPWM-2   | 0x23C               |
| DMTimer 5      | 0x218               | CAN-0      | 0x240               |
| DMTimer 6      | 0x21C               | CAN-1      | 0x244               |
| DMTimer 7      | 0x260               | PRU-ICSS   | 0x248               |
| EMAC           | 0x220               | USB 2.0    | 0x224               |

**DRM base address**: DebugSS_DRM (see device memory map)

### 27.4.3 Suspend Control Register Format

Each peripheral has a 32-bit suspend control register:

| Bit  | Field                    | Type | Description                                                                                           |
| ---- | ------------------------ | ---- | ----------------------------------------------------------------------------------------------------- |
| 31:8 | Reserved                 | R    | —                                                                                                     |
| 7:4  | Suspend_Sel              | R/W  | Suspend signal selection (0000b = Cortex-A8 suspend; others reserved)                                 |
| 3    | Suspend_Default_Override | R/W  | 0 = use Suspend_Sel; 1 = use default suspend signal                                                   |
| 2:1  | Reserved                 | R    | —                                                                                                     |
| 0    | SensCtrl                 | R/W  | Sensitivity control: 0 = peripheral runs during debug halt; 1 = peripheral suspends during debug halt |

**Recommended values:**

- Normal mode (peripheral runs during debug): `0x0`
- Suspend peripheral during debug halt: `0x9` (Suspend_Sel=0, Suspend_Default_Override=1, SensCtrl=1)

**Important**: Some peripherals have local control to gate the suspend event. For example, the Watchdog Timer has an `EMUFREE` bit in the `WDSC` register. Ensure this bit is set correctly to allow the DRM suspend signal to reach the peripheral.

---

## 27.5 Programming Notes

### Enabling Debug Suspend for Watchdog Timer

1. Set DRM Watchdog_Timer_Suspend_Control register to `0x9`
2. Ensure WDT `WDSC.EMUFREE` bit is cleared (0) to allow suspend signal through
3. When debugger halts Cortex-A8, WDT will stop counting

### ICEPick Connect Sequence

1. Apply connect key to ICEPick connect register (consult debugger documentation for key value)
2. ICEPick enables full JTAG instruction set
3. Debugger can now insert secondary TAPs (Cortex-A8, etc.) into scan chain

### Wait-in-Reset Usage

1. Boot device with EMU1=1, EMU0=0
2. All processors held in reset
3. Debugger attaches via ICEPick
4. Debugger releases individual processors (local WIR release) or all at once (global WIR release)
5. Processors begin execution from reset vector

---

## 27.6 Integration

### 27.6.1 Connectivity Attributes

| Attribute     | Value                               |
| ------------- | ----------------------------------- |
| Power Domain  | Wakeup Domain (always on)           |
| Clock Domain  | Debug clock (always on)             |
| Reset         | POR_RSTn                            |
| External Pins | nTRST, TCK, TMS, TDI, TDO, EMU[4:0] |
| Interrupts    | None                                |

### 27.6.2 Debugger Tools

The AM335x debug subsystem is compatible with:

- TI Code Composer Studio (CCS)
- OpenOCD (open-source)
- Lauterbach TRACE32
- Segger J-Link (with appropriate configuration)

Refer to the tool vendor's documentation for AM335x-specific configuration files and connection procedures.
