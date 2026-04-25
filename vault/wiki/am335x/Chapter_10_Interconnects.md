---
title: AM335x Chapter 10 Interconnects
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 10 Interconnects

## 10.1 Architecture Overview

Two-level hierarchical interconnect: **L3** (high-performance, Network-on-Chip) and **L4** (peripheral, low-latency). Both comply with OCPIP 2.2 reference standard.

**Terminology:**

- **Initiator:** Module that can initiate read/write requests (processors, DMA, etc.).
- **Target:** Module that only responds to requests (peripherals, memory controllers). Note: a module can be both initiator and target via separate ports.
- **Agent:** Adaptation between module and interconnect. Target → target agent (TA); initiator → initiator agent (IA).
- **Register Target (RT):** Special TA for accessing interconnect configuration registers.
- **ConnID:** In-band transaction qualifier uniquely identifying the initiator; used for error logging.
- **Out-of-band Error:** Error-reporting signal not associated with a precise transaction (interrupts and DMA requests are NOT routed by the interconnect).

---

## 10.2 L3 Interconnect

Packet-based NoC protocol; transactions tagged by ConnID. L3 is split into two clock domains:

- **L3F** — L3 Fast clock domain
- **L3S** — L3 Slow clock domain

L3 returns an **address-hole error** if an initiator accesses a target to which it has no connection.

### 10.2.1 L3 Initiator Ports

**L3F:**

- Cortex-A8 MPUSS: 128-bit port0, 64-bit port1
- SGX530: 128-bit
- 3× TPTC: 128-bit read ports (TPTC0–2)
- 3× TPTC: 128-bit write ports (TPTC0–2)
- LCDC: 32-bit
- 2× PRU-ICSS: 32-bit
- 2-port Gigabit Ethernet Switch (2PGSW): 32-bit
- Debug Subsystem: 32-bit

**L3S:**

- USB CPPI DMA: 32-bit
- USB Queue Manager: 32-bit
- P1500 (IEEE 1500): 32-bit

### 10.2.2 L3 Target Ports

**L3F:**

- EMIF: 128-bit
- 3× TPTC CFG: 32-bit
- TPCC CFG: 32-bit
- OCM RAM0: 64-bit
- DebugSS: 32-bit
- SGX530: 64-bit
- L4_FAST: 32-bit

**L3S:**

- 4× L4_PER peripheral: 32-bit
- GPMC: 32-bit
- McASP0: 32-bit
- McASP1: 32-bit
- ADC_TSC: 32-bit
- USB: 32-bit
- MMCHS2: 32-bit
- L4_WKUP: 32-bit

### 10.2.3 L3 Master–Slave Connectivity (Table 10-1)

`R` = connection exists.

| Master ID | Master             | EMIF | OCMC-RAM | TPCC | TPTC0–2 CFG | L4_Fast | L4_PER P0–P3 | L4_WKUP | GPMC | MMCHS2 | SGX530 | DebugSS | USB CFG | ADC/TSC | Expansion | NOC Regs |
| --------- | ------------------ | ---- | -------- | ---- | ----------- | ------- | ------------ | ------- | ---- | ------ | ------ | ------- | ------- | ------- | --------- | -------- |
| 0x00      | MPUSS M1 (128-bit) | R    |          |      |             |         |              |         |      |        |        |         |         |         |           |          |
| 0x00      | MPUSS M2 (64-bit)  | R    | R        | R    | R           | R       | R            | R       | R    | R      | R      | R       | R       | R       | R         | R        |
| 0x18      | TPTC0 RD           | R    | R        |      | R           | R       | R            | R       | R    | R      | R      | R       |         |         |           |          |
| 0x19      | TPTC0 WR           | R    | R        |      | R           | R       | R            | R       | R    | R      | R      | R       | R       |         |           |          |
| 0x1A      | TPTC1 RD           | R    | R        |      | R           | R       | R            | R       | R    | R      | R      | R       |         |         |           |          |
| 0x1B      | TPTC1 WR           | R    | R        |      | R           | R       | R            | R       | R    | R      | R      | R       | R       |         |           |          |
| 0x1C      | TPTC2 RD           | R    | R        |      | R           | R       | R            | R       | R    | R      | R      | R       |         |         |           |          |
| 0x1D      | TPTC2 WR           | R    | R        |      | R           | R       | R            | R       | R    | R      | R      | R       | R       |         |           |          |
| 0x24      | LCD Controller     |      | R        |      |             |         |              |         |      |        |        |         |         |         | R         | R        |
| 0x0E      | PRU-ICSS PRU0      | R    | R        | R    | R           | R       | R            | R       | R    | R      | R      | R       | R       |         |           |          |
| 0x0F      | PRU-ICSS PRU1      | R    | R        | R    | R           | R       | R            | R       | R    | R      | R      | R       | R       |         |           |          |
| 0x30      | GEMAC              |      | R        |      |             |         |              |         |      |        |        |         |         |         | R         | R        |
| 0x20      | SGX530             | R    | R        | R    |             |         |              |         |      |        |        |         |         |         |           |          |
| 0x34      | USB0 DMA           | R    | R        |      |             |         |              |         |      |        |        |         |         |         |           |          |
| 0x35      | USB1 Queue Mgr     |      | R        |      |             |         | R            |         |      |        |        |         |         |         |           |          |
| 0x04      | EMU (DAP)          | R    | R        | R    | R           | R       | R            | R       | R    | R      | R      | R       | R       | R       | R         | R        |
| 0x05      | IEEE1500           | R    | R        | R    | R           | R       | R            | R       | R    | R      | R      | R       | R       | R       | R         | R        |

---

## 10.3 L4 Interconnect

Non-blocking peripheral interconnect; low latency for large numbers of low-bandwidth targets. Handles up to 4 initiators and up to 63 targets.

Three L4 interfaces:

- **L4_PER** — Standard peripherals (connected via L3S)
- **L4_FAST** — High-speed peripherals (connected via L3F)
- **L4_WKUP** — Wakeup peripherals (connected via L3S)

### 10.3.1 L4_PER Peripherals

DCAN0/1, DMTIMER2–7, eCAP/eQEP/ePWM0–2, eFuse Ctl, ELM, GPIO1–3, I2C1/2, IEEE1500, LCD Ctlr, Mailbox0, McASP0/1 CFG, MMCHS0/1, OCP Watchpoint, SPI0/1, Spinlock, UART1–5

### 10.3.2 L4_FAST Peripherals

GEMAC, McASP0 CFG, McASP1 CFG, PRU-ICSS, DebugSS, PRCM, HWMaster1

### 10.3.3 L4_WKUP Peripherals

ADC_TSC, Control Module, DMTIMER0, DMTIMER1_1MS, GPIO0, I2C0, M3 UMEM, M3 DMEM, RTC, SmartReflex 0/1, UART0, WDT1
