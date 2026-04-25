---
title: AM335x Chapter 26 — Initialization / ROM Code (Condensed Wiki)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 26 Initialization (ROM Code)

## Overview

The ROM Code handles early initialization and booting on cold or warm reset. It supports:

- **Memory Booting:** NOR (XIP), NAND, MMC/SD, SPI-EEPROM
- **Peripheral Booting:** UART, USB, Ethernet (EMAC)

The device always starts in secure mode (TrustZone). The Secure ROM Code runs first, then transfers to the Public ROM Code at address **0x20000**.

**Device types:**

- **HS (High-Secure):** Requires digitally signed, authenticated boot images.
- **GP (General-Purpose):** No authentication required; simpler image format.

---

## Architecture

Three layers (top-down):

1. **High-level layer:** Main boot routine, watchdog and clock configuration.
2. **Drivers layer:** Logical/communication protocols for each boot device.
3. **HAL (Hardware Abstraction Layer):** Lowest-level hardware IP interaction.

---

## Memory Map

| Region                | Address Range             | Notes                                    |
| --------------------- | ------------------------- | ---------------------------------------- |
| Public ROM            | 0x20000 – 0x2BFFF         | 48 KB (GP) / less on HS                  |
| Download area (GP)    | 0x402F0400 (up to 109 KB) | Image loaded here during peripheral boot |
| Download area (HS)    | 0x40300000 (up to 46 KB)  |                                          |
| Public Stack          | 8 KB                      |                                          |
| RAM Exception Vectors | 0x4030CE00 – 0x4030CE3F   |                                          |

---

## CPU State at Public Startup

- L1 instruction cache and branch prediction: **not activated**
- MMU: **off** (L1 data cache off)
- Data base address: reset vector of Public ROM Code (0x20000)
- Execution: public ARM supervisor mode

---

## Startup Sequence

1. System reset → Secure ROM Code (TrustZone)
2. Jump to Public ROM Code at 0x20000
3. `__main()` → stack setup → `main()`
4. Configure WDT1 (set to 3 minutes)
5. Configure DPLLs and clocks
6. Create booting device list (based on SYSBOOT pins)
7. Try each device in list → memory boot or peripheral boot
8. Execute valid image, or watchdog reset if all fail

---

## Clocking Configuration

Crystal frequency is selected by SYSBOOT[15:14]:

| SYSBOOT[15:14] | Crystal Frequency |
| -------------- | ----------------- |
| 00b            | 19.2 MHz          |
| 01b            | 24 MHz            |
| 10b            | 25 MHz            |
| 11b            | 26 MHz            |

Default clocks configured by ROM Code:

| Clock       | Frequency | Source        |
| ----------- | --------- | ------------- |
| L3F_CLK     | 200 MHz   | CORE_CLKOUTM4 |
| MPU_CLK     | 500 MHz   | MPU_PLL       |
| SPI_CLK     | 48 MHz    | PER_CLKOUTM2  |
| MMC_CLK     | 96 MHz    | PER_CLKOUTM2  |
| UART_CLK    | 48 MHz    | PER_CLKOUTM2  |
| I2C_CLK     | 48 MHz    | PER_CLKOUTM2  |
| USB_PHY_CLK | 960 MHz   | PER_CLKDCOLDO |

DPLLs configured: L3 ADPLLS → 200 MHz; MPU ADPLLS → 500 MHz; PER ADPLLL1 → 960 MHz and 192 MHz.

---

## Booting

### SYSBOOT Configuration Pins

SYSBOOT[15:0] terminals correspond to LCD_DATA[15:0] inputs, latched on the rising edge of PWRONRSTn.

| SYSBOOT Bits | Function                                        |
| ------------ | ----------------------------------------------- |
| [15:14]      | Crystal frequency (19.2/24/25/26 MHz)           |
| [13:12]      | Must be 00b for normal operation                |
| [11:10]      | XIP/NAND: 00b=non-muxed, 01b=addr/data muxed    |
| [9]          | ECC handling: 0=by ROM Code, 1=by NAND device   |
| [8]          | Bus width: 0=8-bit, 1=16-bit                    |
| [7:6]        | EMAC PHY mode (MII/RMII/RGMII)                  |
| [5]          | CLKOUT1: 0=disabled, 1=enabled                  |
| [4:0]        | Boot sequence selection (32 possible sequences) |

> **Note:** All SYSBOOT values are latched into CONTROL_STATUS register and remain readable after ROM Code execution.

### Common Boot Sequences (SYSBOOT[4:0])

| SYSBOOT[4:0] | Boot Sequence                                 |
| ------------ | --------------------------------------------- |
| 00001b       | UART0 → XIP(MUX1) → MMC0 → SPI0               |
| 00010b       | UART0 → XIP w/WAIT(MUX1) → MMC0 → SPI0        |
| 00100b       | UART0 → SPI0 → XIP(MUX2) → NAND I2C           |
| 00110b       | EMAC1 → SPI0 → NAND → NAND I2C                |
| 01000b       | EMAC1 → MMC0 → XIP(MUX2) → NAND               |
| 01010b       | EMAC1 → MMC0 → NAND I2C → USB0                |
| 10000b       | XIP(MUX1) → UART0 → EMAC1 → MMC0              |
| 10001b       | XIP w/WAIT(MUX1) → UART0 → EMAC1 → MMC0       |
| 10010b       | NAND → NAND I2C → USB0 → UART0                |
| 10011b       | NAND → NAND I2C → MMC0 → UART0                |
| 10100b       | NAND → NAND I2C → SPI0 → EMAC1                |
| 10101b       | NAND I2C → MMC0 → EMAC1 → UART0               |
| 11000b       | USB0 → NAND → SPI0 → MMC0                     |
| 11011b       | Fast External Boot → EMAC1 → UART0 → Reserved |
| x1111b       | Bypass mode (Fast External Boot)              |

> **Note:** MUX1 and MUX2 designate which group of XIP signals is used (defined in GPMC mux table in full reference). WAIT is monitored on GPMC_WAIT0.

### Boot Device Codes (reported in Booting Parameters at image execution)

| Code | Device        |
| ---- | ------------- |
| 00h  | No device     |
| 01h  | XIP MUX1      |
| 02h  | XIP/WAIT MUX1 |
| 03h  | XIP MUX2      |
| 04h  | XIP/WAIT MUX2 |
| 05h  | NAND          |
| 06h  | NAND with I2C |
| 08h  | MMC/SD port 0 |
| 09h  | MMC/SD port 1 |
| 09h  | SPI           |
| 41h  | UART0         |
| 44h  | USB           |
| 45h  | CPGMAC0       |

---

## Fast External Booting

Triggered by SYSBOOT x1111b. GP devices only. Minimal ROM execution:

1. Configure GPMC interface (no PLL configuration).
2. Jump to address **0x08000000** in ARM mode (XIP device connected to CS0).

Supports both addr/data muxed and non-muxed devices (SYSBOOT[11:10]). Bus width from SYSBOOT[8]. No wait monitoring. No RAM used.

---

## Memory Booting

ROM Code reads from the selected device, validates the image header, copies to destination address, then executes.

### Supported Memory Devices

| Device      | Interface | Notes                                      |
| ----------- | --------- | ------------------------------------------ |
| NOR/XIP     | GPMC      | Execute-in-place; no header needed         |
| NAND        | GPMC      | ECC handling by ROM or device (SYSBOOT[9]) |
| NAND w/ I2C | GPMC+I2C0 | Geometry from I2C EEPROM                   |
| MMC/SD      | MMC0/MMC1 | Searches FAT filesystem or RAW mode        |
| SPI-EEPROM  | SPI0 CS0  | Standard SPI protocol                      |

### MMC/SD Boot Details

ROM Code searches for the image in this order: FAT filesystem (looking for `MLO` file) → RAW mode (using TOC at sector 0).

**RAW mode TOC (GP Device only, sector 0, 512 bytes):**

- Contains TOC items (up to 2 × 32 bytes) identifying the boot image.
- Filename in TOC must be `CHSETTINGS` (null-terminated, 12 chars).
- Magic values at offsets 40h = `0xC0C0C0C1`, 44h = `0x00000100`.
- All other bytes in the 512-byte TOC must be zero.

**TOC Item Fields:**

| Offset | Field        | Size | Value/Description |
| ------ | ------------ | ---- | ----------------- |
| 0x00h  | Start        | 4    | 0x00000040        |
| 0x04h  | Size         | 4    | 0x0000000C        |
| 0x08h  | Flags        | 4    | 0 (not used)      |
| 0x0Ch  | Align        | 4    | 0 (not used)      |
| 0x10h  | Load Address | 4    | 0 (not used)      |
| 0x14h  | Filename     | 12   | "CHSETTINGS\0"    |

---

## Peripheral Booting

Downloads boot image from external host over UART, USB, or Ethernet.

Image downloaded to internal RAM at **0x402F0400** (GP, max 109 KB) or **0x40300000** (HS, max 46 KB).

### UART Boot

- UART0: 115200 baud, 8 data bits, no parity, 1 stop bit, no flow control.
- Uses XMODEM protocol for data transfer.

### USB Boot

- USB0: Full-speed (12 Mbps), client mode.
- Device appears as USB peripheral; host sends image binary.

### EMAC Boot

- CPGMAC port 1.
- Supports MII, RMII, RGMII via SYSBOOT[7:6]:

| SYSBOOT[7:6] | PHY Mode |
| ------------ | -------- |
| 00b          | MII      |
| 01b          | RMII     |
| 10b          | RGMII    |
| 11b          | Reserved |

**Protocol:**

1. Detect PHY on MDIO; read link speed (10/100/1000 Mbps) and duplex mode via Auto-Negotiation. 5-second timeout for auto-negotiation.
2. Broadcast **BOOTP** (RFC 951) to obtain: device IP (yiaddr), subnet mask (option 1), gateway (option 3 or giaddr), boot filename (file field), TFTP server IP (siaddr). Exponentially increasing timeouts from 4s; 5 retries.
3. Download image via **TFTP** (RFC 1350). 1s timeout for READ request; 5 retries. 60s total transfer timeout.

**BOOTP vendor-class-identifier:** `"AM335x ROM"`

**MAC address source:** EFUSE registers `mac_id0_lo` and `mac_id0_hi` in control module.

**Pins used for EMAC boot (MII mode, Pin Mux Mode 0):**
gmii1_col, gmii1_crs, gmii1_rxer, gmii1_txen, gmii1_rxdv, gmii1_txd[3:0], gmii1_txclk, gmii1_rxclk, gmii1_rxd[3:0], mdio_data, mdio_clk.

**Pins used for EMAC boot (RMII mode):**
rmii1_crs_dv (MII1_CRS, mode 1), rmii1_rxer (MII1_RX_ER, mode 1), rmii1_txen (MII1_TX_EN, mode 1), rmii1_txd[1:0] (MII1_TXD[1:0], mode 1), rmii1_rxd[1:0] (MII1_RXD[1:0], mode 1), rmii1_refclk (RMII1_REF_CLK, mode 0; external 50-MHz source required), mdio_data (MDIO, mode 0), mdio_clk (MDC, mode 0).

---

## Image Format

### GP Device — Non-XIP Memory Booting

| Field       | Offset | Size (bytes) | Description                  |
| ----------- | ------ | ------------ | ---------------------------- |
| Size        | 0000h  | 4            | Size of the image in bytes   |
| Destination | 0004h  | 4            | Load address and entry point |
| Image       | 0008h  | Variable     | Executable code              |

> The Destination address is both the target address for copy and the entry point.

### GP Device — XIP and Peripheral Booting

No header. Image begins directly with executable code. Loaded/executed at the Destination address specified in the peripheral boot protocol, or executed in-place for XIP.

### HS Device — Memory and Peripheral Booting

Image structure:

1. TOC (Table of Contents)
2. Public Keys Certificate
3. PPA (Primary Public Authentication)
4. R&D Certificate (optional)
5. Initial Software Certificate
6. Initial Software

Authentication failure → dead loop → WDT1 reset.

---

## Booting Parameters Structure (at image execution)

The A8 register points to the Booting Parameters structure:

| Offset | Field                            | Size | Description                                                                                     |
| ------ | -------------------------------- | ---- | ----------------------------------------------------------------------------------------------- |
| 00h    | Reserved                         | 4    | Reserved                                                                                        |
| 04h    | Memory booting device descriptor | 4    | Pointer to memory device descriptor                                                             |
| 08h    | Current Booting Device           | 1    | Device code (see table above)                                                                   |
| 09h    | Reset Reason                     | 1    | Bit mask: [0]=POR, [1]=warm SW reset, [3]=security violation, [4]=WDT1, [5]=external warm reset |
| 0Ah    | Reserved                         | 1    | Reserved                                                                                        |

---

## Reset Reasons (bit field in Booting Parameters offset 09h)

| Bit | Event                       |
| --- | --------------------------- |
| 0   | Power-on (cold) reset       |
| 1   | Global warm software reset  |
| 2   | Reserved                    |
| 3   | Reserved security violation |
| 4   | WDT1 timer reset            |
| 5   | Global external warm reset  |

ROM Code does not clear any reset reason bits.

---

## Exception Vectors

ROM Code provides exception vectors at 0x20000. RAM exception vectors at 0x4030CE00–0x4030CE3F allow custom exception handlers to be installed by software.

Dead loops are used for undefined exceptions (generate WDT1 reset on HS devices).
