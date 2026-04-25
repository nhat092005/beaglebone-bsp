---
title: AM335x Chapter 4 — PRU-ICSS
tags:
  - am335x
  - pru
  - icss
  - reference
source: "AM335x TRM Chapter 4"
---

# 4 Programmable Real-Time Unit Subsystem and Industrial Communication Subsystem (PRU-ICSS)

## 4.1 Introduction

The PRU-ICSS is a low-latency subsystem with two 32-bit load/store RISC cores (PRU0, PRU1) operating independently of the ARM MPU. It is designed for deterministic, real-time industrial communication protocols.

### 4.1.1 PRU-ICSS Submodules

| Submodule | Description |
|-----------|-------------|
| PRU0 / PRU1 | Dual 32-bit RISC cores, 200 MHz, single-cycle 32-bit multiply; 3 banks of 30 × 32-bit scratchpad registers |
| Instruction RAM | 8 KB per PRU (IRAM0, IRAM1) |
| Data RAM | 8 KB per PRU (DRAM0, DRAM1), plus 12 KB shared DRAM |
| INTC | PRU-ICSS Interrupt Controller — 64 system events → 10 host interrupts |
| IEP | Industrial Ethernet Peripheral — 64-bit hardware timer, CMP events |
| UART0 | 16550-compatible UART, baud up to 12 Mbps |
| ECAP | Enhanced Capture module for time-stamping |
| MII_RT | MII Real-Time sub-block for PRU Ethernet |
| CFG | Configuration / control registers |
| MDIO | MDIO interface for PHY management |

### 4.1.2 Key Features

- Two 32-bit RISC cores at 200 MHz (5 ns cycle time); 4-bus Harvard architecture (1 instruction, 3 data)
- 30 × 32-bit general-purpose registers (R1–R30) per core; R0 is the indexing register; R31 is external status/output
- Single-cycle 32-bit multiply, dedicated MAC (Multiply-Accumulate) instruction
- 3 scratchpad banks (Bank0/Bank1/Bank2), each 30 × 32-bit registers; accessed via XIN/XOUT with device IDs 10/11/12 respectively; device ID 14 = direct PRU-to-PRU connect
- 64 system-event inputs; 10 host-interrupt outputs (Host-0…Host-9)
- Host-2 through Host-9 are connected to ARM INTC; Host-0/1 are internal to PRU cores
- Direct access to device I/O pins via R30 (output) and R31 (input) special registers
- Cycle counter and stall counter per PRU core

---

## 4.2 Integration

### 4.2.1 Memory Map

| Region | Base Address | Size | Description |
|--------|-------------|------|-------------|
| DRAM0 | 0x4A30_0000 | 8 KB | PRU0 Data RAM |
| DRAM1 | 0x4A30_2000 | 8 KB | PRU1 Data RAM |
| Shared DRAM | 0x4A31_0000 | 12 KB | Shared Data RAM |
| IRAM0 | 0x4A33_4000 | 8 KB | PRU0 Instruction RAM |
| IRAM1 | 0x4A33_8000 | 8 KB | PRU1 Instruction RAM |
| INTC | 0x4A32_0000 | 8 KB | Interrupt Controller |
| CFG | 0x4A32_6000 | 512 B | PRU-ICSS Config |
| IEP | 0x4A32_E000 | 4 KB | Industrial Ethernet Peripheral |
| UART0 | 0x4A32_8000 | 4 KB | UART |
| ECAP0 | 0x4A33_0000 | 256 B | Enhanced Capture |
| MII_RT | 0x4A33_2000 | 4 KB | MII Real-Time |
| MDIO | 0x4A33_2400 | 256 B | MDIO |

### 4.2.2 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | PD_PER_PRU_ICSS_GCLK |
| Max Clock | 200 MHz (PRU cores), 200 MHz (L3) |
| Reset | PER_DOM_RST_N |
| Idle/Wakeup | Smart Idle |
| Interrupts to ARM | 8 (Host-2…Host-9, via ARM INTC crossbar) |
| DMA Requests | None (uses its own EDMA event outputs) |
| L3 Physical Address | L3 Fast slave port |

### 4.2.3 PRU-ICSS Pin Interface (MII)

| Pin | Direction | Description |
|-----|-----------|-------------|
| MII1_TXCLK | I | MII Port 1 TX Clock |
| MII1_TXEN | O | MII Port 1 TX Enable |
| MII1_TXD[3:0] | O | MII Port 1 TX Data |
| MII1_RXCLK | I | MII Port 1 RX Clock |
| MII1_RXDV | I | MII Port 1 RX Data Valid |
| MII1_RXER | I | MII Port 1 RX Error |
| MII1_RXD[3:0] | I | MII Port 1 RX Data |
| MII1_CRS | I | MII Port 1 Carrier Sense |
| MII1_COL | I | MII Port 1 Collision |
| MII0_* | I/O | MII Port 0 (same signals) |
| MDIO_CLK | O | MDIO Clock |
| MDIO_DATA | I/O | MDIO Data |
| PR1_UART0_TXD | O | PRU UART Transmit |
| PR1_UART0_RXD | I | PRU UART Receive |
| PR1_UART0_CTS | I | PRU UART CTS |
| PR1_UART0_RTS | O | PRU UART RTS |
| PR1_ECAP0_IN | I | ECAP capture input |

---

## 4.3 PRU Core Architecture

### 4.3.1 Register File

Each PRU has 32 internal registers total:
- **R0**: Indexing register (also used for XIN/XOUT shift amount)
- **R1–R29**: General purpose (29 registers)
- **R30**: Output register — drives device I/O pins (GPO) directly
- **R31**: Dual-purpose: reading returns GPI pin status; writing generates a system event to the INTC

> **GP register count per raw TRM:** 30 GP registers (R1–R30), R0 = indexing, R31 = external status — total 32 accessible registers.

### 4.3.2 Instruction Set Summary

| Category | Instructions |
|----------|-------------|
| Arithmetic | ADD, ADC, SUB, SUC, RSB, RSC, LSL, LSR, ROR |
| Logic | AND, OR, XOR, NOT, CLR, SET |
| Multiply | MPY (32-bit result), MPYU (unsigned) |
| Memory | LBBO (load via base+offset), SBBO (store), LBCO/SBCO (via constant table) |
| Branch | QBxx (quick branch on condition), JMP, JAL, CALL, RET |
| Bit ops | LMBD (left-most bit detect), SCAN, LOOP |
| Special | XIN/XOUT (scratchpad exchange), SXIN/SXOUT (shift exchange) |

### 4.3.3 Control Registers (CFG block)

| Register | Offset | Description |
|----------|--------|-------------|
| REVID | 0x00 | Revision ID |
| SYSCFG | 0x04 | System Config (STANDBY_INIT, SUB_MWAIT) |
| GPCFG0 | 0x08 | PRU0 GP output driven/input sampled mode |
| GPCFG1 | 0x0C | PRU1 GP output driven/input sampled mode |
| CGR | 0x10 | Clock Gating Register (PRU0_CLK_STOP, PRU1_CLK_STOP, IEP_CLK_STOP, ECAP_CLK_STOP) |
| ISRP | 0x14 | IEP Sync Route Register |
| ISP | 0x18 | IEP Sync Polarity Register |
| IESP | 0x1C | IEP Sync Enable Register |
| SCRP | 0x24 | Scratch Pad Route |
| PMAO | 0x28 | PRU Master OCP Address Offset |
| MII_RT_EVENT_EN | 0x2C | MII_RT Event Enable |

---

## 4.4 PRU-ICSS Interrupt Controller (INTC)

### 4.4.1 Architecture

- **64 system event inputs** (numbered 0–63) from device peripherals and from PRU cores
- **10 host interrupts** (Host-0 through Host-9)
  - Host-0 → PRU0 internal interrupt (bit 30 of R31)
  - Host-1 → PRU1 internal interrupt (bit 31 of R31)
  - Host-2…Host-9 → Connected to ARM INTC (pr1_host_intr[0:7])
- **10 channels** (CH0–CH9): system events are mapped to channels, channels to host interrupts
- Priority: lower channel number = higher priority; within a channel, lower event number = higher priority

### 4.4.2 INTC Register Summary

| Register | Offset | Reset | Description |
|----------|--------|-------|-------------|
| REVID | 0x000 | — | Revision |
| CR | 0x004 | 0h | Control: NESTHINT_EN enables auto-nesting |
| GER | 0x010 | 0h | Global Enable Register; bit 0 = EN |
| GNLR | 0x01C | 100h | Global Nesting Level |
| SISR | 0x020 | 0h | System Interrupt Status Indexed Set |
| SICR | 0x024 | 0h | System Interrupt Status Indexed Clear |
| EISR | 0x028 | 0h | System Interrupt Enable Indexed Set |
| EICR | 0x02C | 0h | System Interrupt Enable Indexed Clear |
| HIEISR | 0x034 | 0h | Host Interrupt Enable Indexed Set |
| HIDISR | 0x038 | 0h | Host Interrupt Enable Indexed Clear |
| GPIR | 0x080 | 0h | Global Prioritized Index Register (read highest pending event) |
| SRSR0 | 0x200 | 0h | System Event Raw Status [31:0] |
| SRSR1 | 0x204 | 0h | System Event Raw Status [63:32] |
| SECR0 | 0x280 | 0h | System Event Enable Clear [31:0] |
| SECR1 | 0x284 | 0h | System Event Enable Clear [63:32] |
| CMR0–CMR15 | 0x400–0x43C | 0h | Channel Map Registers — 4 events per 32-bit register, 4 bits per event |
| HMR0–HMR2 | 0x800–0x808 | 0h | Host Map Registers — 4 channels per 32-bit register |
| HIPIR0–HIPIR9 | 0x900–0x924 | 100h | Host Interrupt Prioritized Index |
| HINLR0–HINLR9 | 0x1100–0x1124 | 100h | Host Interrupt Nesting Level |
| SITR0 | 0xD80 | 0h | System Interrupt Type [31:0] (0=pulse, 1=edge) |
| SITR1 | 0xD84 | 0h | System Interrupt Type [63:32] |

**Key INTC flow:**
1. Set event-to-channel mapping in CMR0–CMR15 (4 bits per event in nibble)
2. Set channel-to-host mapping in HMR0–HMR2 (4 bits per channel)
3. Enable host interrupts via HIEISR
4. Enable system event captures via EISR
5. Set GER[0]=1 to globally enable INTC

---

## 4.5 IEP — Industrial Ethernet Peripheral

### 4.5.1 Features

- 64-bit free-running counter at IEP clock (200 MHz → 5 ns resolution)
- Programmable compare registers (CMP0–CMP7)
- CMP0 triggers counter reset and optional sync output
- CMP1–CMP7 trigger configurable output events
- Compensation register for fractional nanosecond correction
- Digital Waveform Generator (DWG)
- Capture registers for timestamping external events

### 4.5.2 Key IEP Registers

| Register | Offset | Description |
|----------|--------|-------------|
| IEP_GLOBAL_CFG | 0x00 | Default_INC (bits 7:0) = counter increment per cycle; CMP_INC (19:8) = compare increment; CNT_ENABLE (bit 0) |
| IEP_GLOBAL_STATUS | 0x04 | CNT_OVF — counter overflow flag |
| IEP_COMPEN | 0x08 | Compensation counter — adds extra increment when non-zero |
| IEP_COUNT | 0x10 | 64-bit free-running counter (low 32-bit) |
| IEP_COUNT_HI | 0x14 | 64-bit counter high 32-bit |
| IEP_CMP_CFG | 0x70 | CMP_EN[7:0] — enable each compare; SHD_SEL — shadow select |
| IEP_CMP_STATUS | 0x74 | CMP_HIT[7:0] — indicates compare event fired (W1C) |
| IEP_CMP0 | 0x78 | Compare 0 value (triggers counter reset if CMP0_RST_CNT_EN set) |
| IEP_CMP1–IEP_CMP7 | 0x80–0x98 | Compare values 1–7 |

---

## 4.6 PRU UART

### 4.6.1 Features

- 16550-compatible UART
- 16-byte transmit FIFO, 16-byte receive FIFO
- Baud rate up to 12 Mbps (at 192 MHz input clock)
- Data formats: 5, 6, 7, or 8 data bits; optional parity; 1, 1.5, or 2 stop bits
- Autoflow control via RTS/CTS
- 16× oversampling receive clock

### 4.6.2 UART Register Map

| Register | Offset | Description |
|----------|--------|-------------|
| RBR/THR/DLL | 0x00 | Receive Buffer / Transmit Hold / Divisor Latch Low |
| IER/DLH | 0x04 | Interrupt Enable / Divisor Latch High |
| IIR/FCR | 0x08 | Interrupt ID (R) / FIFO Control (W) |
| LCR | 0x0C | Line Control: WLS[1:0]=data bits; STB=stop bits; PEN=parity; BC=break; DLAB=divisor access |
| MCR | 0x10 | Modem Control: DTR, RTS, LOOP (loopback), AFE (autoflow) |
| LSR | 0x14 | Line Status: DR, OE, PE, FE, BI, THRE, TEMT, RXFIFOE |
| MSR | 0x18 | Modem Status: DCTS, DDSR, TERI, DDCD, CTS, DSR, RI, DCD |
| SCR | 0x1C | Scratch |
| MDR | 0x20 | Mode: OSM_SEL (0=16×, 1=13×) |
| UTRST/URRST | 0x24 | TX/RX reset and enable (PWREMU_MGMT) |

**Baud rate**: `Baud = InputClk / (16 × DivisorLatch)` where DivisorLatch = DLH:DLL.

**FIFO trigger levels** (FCR bits): 1, 4, 8, or 14 bytes.

**Interrupt priority** (IIR): Line Status > Receive Data Ready/Timeout > THRE > Modem Status.

---

## 4.7 PRU-ICSS MII_RT (MII Real-Time)

The MII_RT sub-block provides direct MII signal routing and control for PRU Ethernet:

| Function | Description |
|----------|-------------|
| RX_MII_SEL | Select MII0 or MII1 as source for PRU0/PRU1 RX |
| TX_MII_SEL | Select MII0 or MII1 as output for PRU0/PRU1 TX |
| RXCFG | Receive configuration — ENABLE, RX_L2_EN, cut-through |
| TXCFG | Transmit configuration — ENABLE, TX_AUTO_PREAMBLE, cut-through |
| TX_IPG | Inter-packet gap configuration |
| PORT_STATUS | Link status per port |

---

## 4.8 PRU Programming Notes

### Accessing Device Peripherals

PRU cores access all device memory-mapped registers via `LBCO`/`SBCO` (using constant table entries CT_INTC, CT_IEP, etc.) or via `LBBO`/`SBBO` with explicit base addresses.

### Scratchpad (XFR Bank) Exchange

Three independent scratchpad banks, each 30 × 32-bit registers (R29:0). Note: scratchpad banks have no R30 or R31.

| Device ID | Resource |
|-----------|----------|
| 10 | Scratch Pad Bank 0 |
| 11 | Scratch Pad Bank 1 |
| 12 | Scratch Pad Bank 2 |
| 14 | Direct PRU-to-PRU connect (XOUT on sender + XIN on receiver simultaneously) |

- `XIN <devID>, reg_start, byte_count` — load from scratchpad or other PRU into registers
- `XOUT <devID>, reg_start, byte_count` — store registers into scratchpad or other PRU
- XFR collision: if two cores write same bank simultaneously, PRU0 gets priority; PRU1 stalls
- Direct connect timeout: stall > 1024 cycles generates `pr1_xfr_timeout` event to INTC

### R31 Interrupt Generation

Writing to R31 simultaneously with **bit 5 = 1** (`pru(n)_r31_vec_valid`) and **bits [3:0]** = channel number (0–15) generates a pulse on INTC system events 16–31 (`pr1_pru_mst_intr[0:15]_intr_req`). The channel number in bits[3:0] maps to system event number = channel + 16.

Examples:
- Write `0b100000` (bit5=1, bits[3:0]=0) → pulse on `pr1_pru_mst_intr[0]` (system event 16)
- Write `0b101111` (bit5=1, bits[3:0]=15) → pulse on `pr1_pru_mst_intr[15]` (system event 31)
- Write `0b0xxxxx` (bit5=0) → no event generated

Outputs from both PRU cores are ORed together at the INTC inputs.
