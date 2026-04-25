---
title: AM335x Chapter 23 — CAN (Condensed Wiki)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 23 Controller Area Network (CAN)

## Overview

The device includes two DCAN controller instances: **DCAN0** and **DCAN1**. The core IP is provided by Bosch and is compliant with **CAN protocol version 2.0 part A, B (ISO 11898-1)**. Bit rates up to 1 MBit/s are supported.

**Unsupported feature:** GPIO pin mode of DCAN is not supported on this device. All GPIO functionality is mapped through the GPIO modules and muxed at the pins.

---

## Integration

### Key Features

- 64 message objects (16/32/64/128 instantiated as **64** on this device)
- Individual identifier mask per message object
- Programmable FIFO mode for message objects
- Programmable loop-back modes for self-test
- Suspend mode for debug support
- Software module reset
- Automatic bus-on after Bus-Off (programmable 32-bit timer)
- Message RAM parity check
- Direct access to Message RAM in test mode
- Two interrupt lines + one parity-error interrupt line
- RAM initialization
- DMA support

### Connectivity Attributes

| Attribute        | Value                                                                |
| ---------------- | -------------------------------------------------------------------- |
| Power Domain     | Peripheral Domain                                                    |
| Clock Domain     | PD_PER_L4LS_GCLK (OCP), PD_PER_CAN_CLK (Func)                        |
| Reset Signal     | PER_DOM_RST_N                                                        |
| Idle/Wakeup      | Smart Idle                                                           |
| Interrupts       | 3 per instance: Intr0 (error/status/msg), Intr1 (msg), Uerr (parity) |
|                  | DCAN0 interrupts → MPU Subsystem + PRU-ICSS                          |
|                  | DCAN1 interrupts → MPU Subsystem only                                |
| DMA Requests     | 3 per instance to EDMA (CAN_IFxDMA)                                  |
| Physical Address | L4 Peripheral slave port                                             |

### Clock Signals

| Clock Signal             | Max Freq | Source            |
| ------------------------ | -------- | ----------------- |
| DCAN_ocp_clk (Interface) | 100 MHz  | CORE_CLKOUTM4 / 2 |
| DCAN_io_clk (Functional) | 26 MHz   | CLK_M_OSC         |

### Pin List

| Pin      | Type | Description        |
| -------- | ---- | ------------------ |
| DCANx_TX | O    | DCAN transmit line |
| DCANx_RX | I    | DCAN receive line  |

---

## Functional Description

### Block Structure

- **CAN Core:** CAN protocol controller and Rx/Tx shift register. Handles all ISO 11898-1 protocol functions.
- **Message Handler:** State machine controlling data transfer between message RAM and CAN core. Handles acceptance filtering, interrupt/DMA request generation.
- **Message RAM:** Stores 64 CAN message objects (DCAN0 and DCAN1).
- **Message RAM Interface:** Three interface register sets: IF1 (R/W), IF2 (R/W), IF3 (read only). Same word-length as message RAM.
- **Module Interface:** 32-bit peripheral bus interface for CPU/software register access.

### Dual Clock Source

Two clock domains: L3_SLOW_GCLK (peripheral synchronous) and CLK_M_OSC (CAN_CLK, asynchronous functional).

---

## CAN Module Initialization

### Step 1: Configure CAN Bit Timing

**Initialization flow:**

1. Set Init=1 in CTL register (enters initialization mode; CAN_TX is recessive, error counters not updated).
2. Set CCE=1 in CTL register (enables write access to BTR).
3. Wait for Init=1 to confirm initialization mode entry.
4. Write bit timing values to BTR register.
5. Clear CCE=0 and Init=0 in CTL register.
6. Wait for Init=0 to confirm return to normal mode.

**BTR register (Bit Timing Register):**
Defines BRP (Baud Rate Prescaler), SJW (Synchronization Jump Width), TSEG1, TSEG2. See Section 23.3.16.2 for calculation from target bit timing.

### Step 2: Configure Message Objects

Each message object is configured through the interface registers IF1 or IF2. For each message object:

1. Write configuration to IFx_ARB, IFx_MCTL, IFx_MASK, IFx_DATA registers.
2. Write the message object number to IFx_CMDREQ to trigger RAM write.
3. Wait for Busy bit in IFx_CMDREQ to clear.

Message objects not needed should be deactivated (MsgVal=0 in IFx_ARB).

### Complete Initialization Example

```
1. Set CTL.Init = 1
2. Set CTL.CCE = 1
3. Wait for CTL.Init = 1
4. Write CTL.Test = 1 (if test mode needed)
5. Configure bit timing: write BTR
6. Initialize all 64 message RAM objects:
   - Set IFx_CMDMSK for write access
   - Set IFx_ARB, IFx_MCTL, IFx_MASK, IFx_DATAAB
   - Write object number to IFx_CMDREQ
   - Wait for IFx_CMDREQ.Busy = 0
7. Clear CTL.CCE = 0, CTL.Init = 0
8. Wait for CTL.Init = 0
```

---

## Message Objects

### Message Object Types

| Type             | Function                                             |
| ---------------- | ---------------------------------------------------- |
| Transmit         | Send data/remote frame on CAN bus                    |
| Receive          | Receive data/remote frame matching acceptance filter |
| Receive with DLC | Receive frames, store DLC in addition to data        |
| Remote Request   | Auto-respond to remote frames with stored data       |
| FIFO             | Multiple message objects chained for FIFO operation  |

### Message Object RAM Structure (per object)

Each message object stores: Arbitration registers (ID, direction, MsgVal), Mask registers (acceptance mask), Message Control (DLC, TxRqst, RxIE, TxIE, etc.), and Data bytes (up to 8 bytes).

### FIFO Mode

Message objects with EoB=0 form a FIFO buffer; the last object in the FIFO has EoB=1. The message handler stores received messages sequentially in the FIFO objects.

---

## Interrupt Handling

### Interrupt Lines

| Line                | Signal       | Sources                                                 |
| ------------------- | ------------ | ------------------------------------------------------- |
| Intr0 (DCANx_INT0)  | Error+Status | CAN error, bus status, any message object (Int_Pnd bit) |
| Intr1 (DCANx_INT1)  | Message only | Message objects with IntPnd=1 and IE1=1                 |
| Uerr (DCANx_PARITY) | Parity error | Message RAM parity error                                |

### Interrupt Register Flow

1. **INT register** identifies the interrupt source (0=no interrupt; 0x8000=status interrupt; 1–128 = message object number).
2. For status interrupt: read SR (Status Register) to identify cause, then write 0x_F_F_F_F to clear.
3. For message object interrupt: service the message object, clear IntPnd bit.

---

## DMA Support

Three DMA requests per instance:

- `CAN_IF1DMA` — triggered by IF1 access completion
- `CAN_IF2DMA` — triggered by IF2 access completion
- `CAN_IF3DMA` — triggered by IF3 access completion

The IF3 register set is read-only and specifically designed for DMA use without impacting normal CPU access through IF1/IF2.

---

## Debug and Test Modes

### Loop-back Modes

| Mode                 | Description                                             |
| -------------------- | ------------------------------------------------------- |
| Internal Loop-back   | TX connected to RX internally; CAN_TX remains recessive |
| External Loop-back   | TX connected to RX and CAN_TX pin is active             |
| Silent Mode          | DCAN only receives; CAN_TX stays recessive              |
| Silent + Internal LB | No traffic on CAN bus                                   |

Set via CTL.Test=1 and TEST register (LBack, Silent bits).

### Suspend Mode

When the processor is halted during debug, the DCAN module can be suspended via the Debug Resource Manager (DRM). Suspend Control Register at DRM offset: 240h (CAN_0), 244h (CAN_1). Values: 0x0 = normal mode; 0x9 = suspend during debug halt.

---

## Register Map Summary

### CAN Control Registers

| Offset  | Acronym     | Register Name                   |
| ------- | ----------- | ------------------------------- |
| 0h      | CTL         | CAN Control Register            |
| 4h      | SR          | Error and Status Register       |
| 8h      | ERRC        | Error Counter Register          |
| Ch      | BTR         | Bit Timing Register             |
| 10h     | INT         | Interrupt Register              |
| 14h     | TEST        | Test Register                   |
| 18h     | PERR        | Parity Error Code Register      |
| 1Ch     | ABOTR       | Auto-Bus-On Time Register       |
| 20h     | TXRQ_X      | Transmission Request X Register |
| 24h–40h | TXRQ12–78   | Transmission Request Registers  |
| 44h     | NWDAT_X     | New Data X Register             |
| 48h–64h | NWDAT12–78  | New Data Registers              |
| 68h     | INTPND_X    | Interrupt Pending X Register    |
| 6Ch–88h | INTPND12–78 | Interrupt Pending Registers     |
| 8Ch     | MSGVAL_X    | Message Valid X Register        |
| 90h–ACh | MSGVAL12–78 | Message Valid Registers         |
| B0h     | INTMUX12    | Interrupt Multiplexer Registers |
| ...     | ...         | ...                             |
| 120h    | IF1CMD      | IF1 Command Register            |
| 124h    | IF1MSK      | IF1 Mask Register               |
| 128h    | IF1ARB      | IF1 Arbitration Register        |
| 12Ch    | IF1MCTL     | IF1 Message Control Register    |
| 130h    | IF1DATA     | IF1 Data A Register             |
| 134h    | IF1DATB     | IF1 Data B Register             |
| 140h    | IF2CMD      | IF2 Command Register            |
| 144h    | IF2MSK      | IF2 Mask Register               |
| 148h    | IF2ARB      | IF2 Arbitration Register        |
| 14Ch    | IF2MCTL     | IF2 Message Control Register    |
| 150h    | IF2DATA     | IF2 Data A Register             |
| 154h    | IF2DATB     | IF2 Data B Register             |
| 160h    | IF3OBS      | IF3 Observation Register        |
| 164h    | IF3MSK      | IF3 Mask Register               |
| 168h    | IF3ARB      | IF3 Arbitration Register        |
| 16Ch    | IF3MCTL     | IF3 Message Control Register    |
| 170h    | IF3DATA     | IF3 Data A Register             |
| 174h    | IF3DATB     | IF3 Data B Register             |
| 180h    | IF3UPD12    | IF3 Update Enable Registers     |
| ...     | ...         | ...                             |
| 1E0h    | TIOC        | CAN TX I/O Control Register     |
| 1E4h    | RIOC        | CAN RX I/O Control Register     |

### Key CTL Register Fields

| Bits | Field | Function                                                |
| ---- | ----- | ------------------------------------------------------- |
| 15   | PMD   | Parity on/off (0=enabled with parity, 1=disabled)       |
| 10   | ABO   | Auto-Bus-On enable (0=disabled, 1=enabled)              |
| 7    | CCE   | Configuration Change Enable (write BTR when Init+CCE=1) |
| 6    | DAR   | Disable Automatic Retransmission                        |
| 5    | EIE   | Error Interrupt Enable                                  |
| 4    | SIE   | Status Change Interrupt Enable                          |
| 3    | IE1   | Interrupt line 1 Enable                                 |
| 2    | IE0   | Interrupt line 0 Enable                                 |
| 0    | Init  | Initialization mode (1=init, 0=normal operation)        |

### Key BTR Register Fields

| Bits  | Field | Function                             |
| ----- | ----- | ------------------------------------ |
| 22–20 | BRPE  | Baud Rate Prescaler Extension (MSBs) |
| 15–14 | SJW   | Synchronization Jump Width           |
| 13–12 | TSEG2 | Time Segment 2                       |
| 11–8  | TSEG1 | Time Segment 1                       |
| 5–0   | BRP   | Baud Rate Prescaler                  |

**Bit time = (BRP+1+((BRPE+1)<<6)) / DCAN_io_clk × (TSEG1+TSEG2+3)**
