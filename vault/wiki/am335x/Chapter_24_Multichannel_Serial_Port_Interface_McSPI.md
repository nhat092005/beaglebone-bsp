---
title: AM335x Chapter 24 — McSPI (Condensed Wiki)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 24 Multichannel Serial Port Interface (McSPI)

## Overview

McSPI is a master/slave SPI controller supporting full-duplex synchronous serial communication. It can interface with up to four slave devices or one external master. Two instances on this device: **SPI0** and **SPI1**.

**Unsupported features on this device:**

| Feature                     | Reason                                |
| --------------------------- | ------------------------------------- |
| Chip selects 2 and 3        | Not pinned out                        |
| Slave mode wakeup           | SWAKEUP not connected                 |
| Retention during power down | Module not synthesized with retention |

---

## Integration

### Connectivity Attributes

| Attribute        | Value                                                          |
| ---------------- | -------------------------------------------------------------- |
| Power Domain     | Peripheral Domain                                              |
| Clock Domain     | PD_PER_L4LS_GCLK (Interface), PD_PER_SPI_GCLK (Func)           |
| Reset Signal     | PER_DOM_RST_N                                                  |
| Idle/Wakeup      | Smart Idle                                                     |
| Interrupts       | SPI0: 1 interrupt to MPU + PRU-ICSS (McSPI0INT)                |
|                  | SPI1: 1 interrupt to MPU only (McSPI1INT)                      |
| DMA Requests     | 4 per instance to EDMA: SPIREVT0, SPIXEVT0, SPIREVT1, SPIXEVT1 |
| Physical Address | L4 Peripheral slave port                                       |

### Clock Signals

| Clock Signal           | Max Freq | Source            |
| ---------------------- | -------- | ----------------- |
| CLK (Interface)        | 100 MHz  | CORE_CLKOUTM4 / 2 |
| CLKSPIREF (Functional) | 48 MHz   | PER_CLKOUTM2 / 4  |

### Pin List

| Pin       | Type | Description                                            |
| --------- | ---- | ------------------------------------------------------ |
| SPIx_SCLK | I/O  | SPI serial clock (output=master, input=slave)          |
| SPIx_D0   | I/O  | Configurable MOSI or MISO                              |
| SPIx_D1   | I/O  | Configurable MOSI or MISO                              |
| SPIx_CS0  | I/O  | Chip select 0 (active low; output=master, input=slave) |
| SPIx_CS1  | I/O  | Chip select 1 (active low; output=master, input=slave) |

> **Note:** SCLK is also used as input to re-time data. CONF*\<module\>*\<pin\>\_RXACTIVE must be set to 1 for these signals. Place a 33-ohm resistor in series close to the processor.

---

## Functional Description

### Transfer Modes

**Full-duplex (Two data pins):** SPIDAT[0] and SPIDAT[1] used simultaneously for TX and RX. Each clock cycle: one bit out from master, one bit in from slave.

**Half-duplex (Single data pin):** One data line is used alternately for TX or RX under software control.

### Transfer Format Parameters

| Parameter       | Description                                                     |
| --------------- | --------------------------------------------------------------- |
| Word length     | 4 to 32 bits, programmable per channel                          |
| Chip select     | SPIEN can be auto or manually asserted; active high or low      |
| Clock frequency | Derived from 48 MHz CLKSPIREF; programmable divider per channel |
| Clock polarity  | CPOL: idle level of SPICLK (0=low, 1=high)                      |
| Clock phase     | CPHA: data capture edge (0=first edge, 1=second edge)           |

### Bit Rate

Master bit rate = CLKSPIREF / (CLKD+1), where CLKD is programmed in McSPI_CHxCONF.

Slave mode: SPICLK is an input from the master.

### SPI Modes (CPOL × CPHA)

| Mode | CPOL | CPHA | Clock idle | Data sampled on       |
| ---- | ---- | ---- | ---------- | --------------------- |
| 0    | 0    | 0    | Low        | Rising (first) edge   |
| 1    | 0    | 1    | Low        | Falling (second) edge |
| 2    | 1    | 0    | High       | Falling (first) edge  |
| 3    | 1    | 1    | High       | Rising (second) edge  |

### FIFO Usage

Multiple SPI words per channel can be handled using the FIFO. FIFO access uses buffer registers (McSPI_XFER_LEVEL determines threshold). The DMA or CPU is triggered based on the FIFO threshold level.

### Multi-channel Operation (Master mode)

Each channel (CS0, CS1) has an independent configuration register set:

- McSPI_CHxCONF — clock, polarity, phase, word width, data pin configuration, chip-select control
- McSPI_CHxCTRL — channel enable
- McSPI_CHxSTAT — status flags
- McSPI_TXx — transmit data register
- McSPI_RXx — receive data register

**Round-robin arbitration** determines the order of TX/RX between channels when multiple channels are active.

### Slave Mode

Single channel operation. SCLK is an input. CS0 pin is the chip select input. The module wakeup (SWAKEUP) is not supported on this device.

---

## Interrupts and DMA

### Interrupt Sources (per channel)

| Flag         | Register        | Condition                 |
| ------------ | --------------- | ------------------------- |
| RXS          | McSPI_IRQSTATUS | RX register full          |
| TXS          | McSPI_IRQSTATUS | TX register empty         |
| EOW          | McSPI_IRQSTATUS | End of word count reached |
| RX0_OVERFLOW | McSPI_IRQSTATUS | RX overflow               |

Enable flags in McSPI_IRQENABLE. One interrupt line shared by all interrupt sources.

### DMA Events

| Event    | Trigger                  |
| -------- | ------------------------ |
| SPIREVT0 | RX data ready, channel 0 |
| SPIXEVT0 | TX data empty, channel 0 |
| SPIREVT1 | RX data ready, channel 1 |
| SPIXEVT1 | TX data empty, channel 1 |

---

## Initialization Sequence

1. Set McSPI_SYSCONFIG.SOFTRESET=1; wait for McSPI_SYSSTATUS.RESETDONE=1.
2. Configure McSPI_MODULCTRL:
   - Set MS bit: 0=master, 1=slave.
   - Set SINGLE bit for single-channel mode.
3. For each active channel, configure McSPI_CHxCONF:
   - CLKD: clock divider ratio.
   - PHA: clock phase.
   - POL: clock polarity.
   - EPOL: chip-select polarity.
   - WL: word length (4–32 bits; write WL-1 to this field).
   - TRM: transmission/reception mode (0=TX+RX, 1=RX only, 2=TX only).
   - DPE0/DPE1: transmit enable on D0/D1.
   - IS: input select (MISO line).
   - CSEG/CS: chip-select assertion control.
4. Enable channel: set McSPI_CHxCTRL.EN=1.
5. (Optional) Set up DMA or interrupt.
6. Write TX data to McSPI_TXx; read RX data from McSPI_RXx.

---

## Register Map Summary

| Offset | Acronym            | Register Name                               |
| ------ | ------------------ | ------------------------------------------- |
| 0h     | McSPI_REVISION     | Revision Register                           |
| 10h    | McSPI_SYSCONFIG    | System Configuration [reset=0h]             |
| 14h    | McSPI_SYSSTATUS    | System Status (RESETDONE) [reset=0h]        |
| 18h    | McSPI_IRQSTATUS    | IRQ Status [reset=0h]                       |
| 1Ch    | McSPI_IRQENABLE    | IRQ Enable [reset=0h]                       |
| 20h    | McSPI_WAKEUPENABLE | Wakeup Enable [reset=0h]                    |
| 24h    | McSPI_SYST         | System Test [reset=0h]                      |
| 28h    | McSPI_MODULCTRL    | Module Control [reset=0h]                   |
| 2Ch    | McSPI_CH0CONF      | Channel 0 Configuration [reset=0h]          |
| 30h    | McSPI_CH0STAT      | Channel 0 Status [reset=0h]                 |
| 34h    | McSPI_CH0CTRL      | Channel 0 Control [reset=0h]                |
| 38h    | McSPI_TX0          | Channel 0 TX Data [reset=0h]                |
| 3Ch    | McSPI_RX0          | Channel 0 RX Data [reset=0h]                |
| 40h    | McSPI_CH1CONF      | Channel 1 Configuration [reset=0h]          |
| 44h    | McSPI_CH1STAT      | Channel 1 Status [reset=0h]                 |
| 48h    | McSPI_CH1CTRL      | Channel 1 Control [reset=0h]                |
| 4Ch    | McSPI_TX1          | Channel 1 TX Data [reset=0h]                |
| 50h    | McSPI_RX1          | Channel 1 RX Data [reset=0h]                |
| 54h    | McSPI_CH2CONF      | Channel 2 Configuration [reset=0h]          |
| 58h    | McSPI_CH2STAT      | Channel 2 Status [reset=0h]                 |
| 5Ch    | McSPI_CH2CTRL      | Channel 2 Control [reset=0h]                |
| 60h    | McSPI_TX2          | Channel 2 TX Data [reset=0h]                |
| 64h    | McSPI_RX2          | Channel 2 RX Data [reset=0h]                |
| 68h    | McSPI_CH3CONF      | Channel 3 Configuration [reset=0h]          |
| 6Ch    | McSPI_CH3STAT      | Channel 3 Status [reset=0h]                 |
| 70h    | McSPI_CH3CTRL      | Channel 3 Control [reset=0h]                |
| 74h    | McSPI_TX3          | Channel 3 TX Data [reset=0h]                |
| 78h    | McSPI_RX3          | Channel 3 RX Data [reset=0h]                |
| 7Ch    | McSPI_XFERLEVEL    | FIFO Transfer Level [reset=0h]              |
| 80h    | McSPI_DAFTX        | DMA Address Aligned FIFO TX Data [reset=0h] |
| A0h    | McSPI_DAFRX        | DMA Address Aligned FIFO RX Data [reset=0h] |

### Key Register Fields

**McSPI_MODULCTRL:**

| Bits | Field   | Function                                                        |
| ---- | ------- | --------------------------------------------------------------- |
| 3    | FDAA    | FIFO DMA address alignment enable                               |
| 2    | INITDLY | Initial delay for first transfer (0=none, 1=4 SPI clocks, etc.) |
| 1    | MS      | Master/Slave (0=master, 1=slave)                                |
| 0    | SINGLE  | Single-channel mode (1) vs. multi-channel (0)                   |

**McSPI_CHxCONF:**

| Bits  | Field    | Function                                                  |
| ----- | -------- | --------------------------------------------------------- |
| 29    | FFER     | FIFO enable for RX                                        |
| 28    | FFEW     | FIFO enable for TX                                        |
| 27–25 | TCS      | Chip-select timing: delay between CS assert and first bit |
| 24    | SBPOL    | Start bit polarity                                        |
| 23    | SBE      | Start bit enable                                          |
| 21    | SPIENSLV | Slave chip-select                                         |
| 20    | FORCE    | Manual CS assertion (when CSEG=0)                         |
| 19    | TURBO    | Turbo mode enable                                         |
| 18    | IS       | Input select (0=D1 is input, 1=D0 is input)               |
| 17    | DPE1     | Transmission enable on D1 (0=no TX on D1)                 |
| 16    | DPE0     | Transmission enable on D0 (0=no TX on D0)                 |
| 15    | DMAR     | DMA read enable                                           |
| 14    | DMAW     | DMA write enable                                          |
| 13–12 | TRM      | TX/RX mode (0=TX+RX, 1=RX only, 2=TX only)                |
| 11–7  | WL       | Word length minus 1 (3=4-bit, 7=8-bit, …, 31=32-bit)      |
| 6     | EPOL     | Chip-select polarity (0=active-high, 1=active-low)        |
| 5–2   | CLKD     | Clock divider (0=÷1, 1=÷2, …, 15=÷32768)                  |
| 1     | POL      | SPICLK polarity (0=idle-low, 1=idle-high)                 |
| 0     | PHA      | SPICLK phase (0=odd, 1=even)                              |

**McSPI_CHxSTAT:**

| Bit | Field | Function                           |
| --- | ----- | ---------------------------------- |
| 6   | RXFFF | RX FIFO full                       |
| 5   | RXFFE | RX FIFO empty                      |
| 4   | TXFFF | TX FIFO full                       |
| 3   | TXFFE | TX FIFO empty                      |
| 2   | EOT   | End of transfer                    |
| 1   | TXS   | TX register empty (ready to write) |
| 0   | RXS   | RX register full (ready to read)   |

**McSPI_XFERLEVEL:**

| Bits  | Field | Function                                             |
| ----- | ----- | ---------------------------------------------------- |
| 31–16 | WCNT  | Word count for EOW interrupt                         |
| 15–8  | AFL   | RX FIFO almost-full level (DMA/interrupt threshold)  |
| 7–0   | AEL   | TX FIFO almost-empty level (DMA/interrupt threshold) |
