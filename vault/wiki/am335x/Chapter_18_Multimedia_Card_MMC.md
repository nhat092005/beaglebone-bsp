---
title: AM335x Chapter 18 Multimedia Card (MMC)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 18 Multimedia Card (MMC)

## Overview

AM335x contains three MMCHS instances supporting MMC, SD, and SDIO cards.

**Base Addresses:** MMCHS0: `0x48060000` | MMCHS1: `0x481D8000` | MMCHS2: `0x47810000`

> MMCHS0 supports MMC_POW pin for power switch control.

## Key Features

- 1024-byte internal buffer; two DMA channels; one interrupt line per instance
- Functional clock: 96 MHz; Max MMC_CLK output: 48 MHz
- Transfer rates: up to 384 Mbit/s (48 MB/s, MMC 8-bit); 192 Mbit/s (SD HS 4-bit); 24 Mbit/s (SD 1-bit)
- Compliant: MMC v4.3, SD Physical Layer v2.00, SDIO Part E1 v2.00, SDA 3.0 Part A2

**Not supported on AM335x:** MMC Out-of-band interrupts (MMC_OBI tied low); Master DMA; Card Supply Control for MMCHS1-2 (not pinned out); DDR mode (timing not supported).

## System Integration

| Attribute     | Value                                                                      |
| ------------- | -------------------------------------------------------------------------- |
| Power Domain  | Peripheral Domain                                                          |
| Clock Domains | PD_PER_L4LS_GCLK (OCP), PD_PER_MMC_FCLK (Functional), CLK_32KHZ (Debounce) |
| Reset         | PER_DOM_RST_N                                                              |
| Idle/Wakeup   | Smart Idle                                                                 |
| Interrupts    | 1 per instance to MPU (MMCSDxINT)                                          |
| DMA Requests  | 2 per instance to EDMA (SDTXEVTx, SDRXEVTx)                                |

**Clock signals:**

| Clock                | Max Freq   | Source          | Domain           |
| -------------------- | ---------- | --------------- | ---------------- |
| Interface (CLK)      | 100 MHz    | CORE_CLKOUTM4/2 | pd_per_l4ls_gclk |
| Functional (CLKADPI) | 96 MHz     | PER_CLKOUTM2/2  | pd_per_mmc_fclk  |
| Debounce (CLK32)     | 32.768 kHz | CLK_24/732.4219 | clk_32KHz        |

## Pin Configuration

| Pin           | Type | Description                            |
| ------------- | ---- | -------------------------------------- |
| MMCx_CLK      | I/O  | Serial clock output (set RXACTIVE bit) |
| MMCx_CMD      | I/O  | Command signal                         |
| MMCx_DAT0     | I/O  | Data; CRC status during write          |
| MMCx_DAT1     | I/O  | Data; SDIO interrupt input             |
| MMCx_DAT2     | I/O  | Data; SDIO read wait output            |
| MMCx_DAT[7:3] | I/O  | Data signals                           |
| MMCx_POW      | O    | Power supply control (MMCHS0 only)     |
| MMCx_SDCD     | I    | SD card detect                         |
| MMCx_SDWP     | I    | SD write protect                       |
| MMCx_OBI      | I    | MMC out-of-band interrupt              |

**DAT line direction by mode:**

| Line     | MMC/SD 1-bit | MMC/SD 4-bit | MMC/SD 8-bit | SDIO 1-bit        | SDIO 4-bit    |
| -------- | ------------ | ------------ | ------------ | ----------------- | ------------- |
| DAT0     | I/O          | I/O          | I/O          | I/O               | I/O           |
| DAT1     | Hi-Z         | I/O          | I/O          | Input (interrupt) | I/O or Input  |
| DAT2     | Hi-Z         | I/O          | I/O          | I/O (read wait)   | I/O or Output |
| DAT3     | Hi-Z         | I/O          | I/O          | Hi-Z              | I/O           |
| DAT[7:4] | Hi-Z         | Hi-Z         | I/O          | Hi-Z              | Hi-Z          |

## Functional Description

### Bus Protocol

Message components: **Command** (host→card on mmc_cmd), **Response** (card→host on mmc_cmd), **Data** (via DAT lines), **Busy** (mmc_dat0 held low during programming), **CRC Status** (card→host via mmc_dat0 during write).

**Command Token (48 bits):** Start(0) | Transmitter(1) | Command index(6b) | Argument(32b) | CRC(7b) | End(1)

**Response types:**

| Response              | RSP_TYPE | CICE | CCCE |
| --------------------- | -------- | ---- | ---- |
| None                  | 00       | 0    | 0    |
| R2 (136-bit)          | 01       | 0    | 1    |
| R3/R4 (48-bit)        | 10       | 0    | 0    |
| R1/R5/R6/R7 (48-bit)  | 10       | 1    | 1    |
| R1b/R5b (48-bit+busy) | 11       | 1    | 1    |

**Transfer types:** Sequential (MMC only, stream on mmc_cmd, terminated by stop command); Block-oriented (all card types, data + CRC, terminated by stop or block count).

## Power Management

**Normal mode:** Auto-gating of clocks when AUTOIDLE=1 and no MMC activity.

**SIDLEMODE field (SD_SYSCONFIG[4:3]):** 0=Force-idle | 1=No-idle | 2=Smart-idle | 3=Reserved

**Wake-up sources:** IWE (SDIO card interrupt), INS (card insertion), REM (card removal), OBWE (OOB interrupt).

## Reset

- **Hardware reset:** Resets all config registers and state machines; RESETDONE=1 when complete.
- **Software reset (SOFTRESET):** Same as HW reset except debounce logic and SD_PSTATE/SD_CAPA/SD_CUR_CAPA preserved.
- **SRD bit:** Resets data transfer state machines only.
- **SRC bit:** Resets command transfer state machines only.
  > If clock inputs absent, software reset will not complete.

## Interrupt System

Each interrupt has three control bits: **SD_STAT** (status, auto-updated), **SD_IE** (enable status update), **SD_ISE** (enable signal generation).

**Normal interrupts:**

| Flag | Event                             |
| ---- | --------------------------------- |
| CC   | Command complete                  |
| TC   | Transfer complete                 |
| BGE  | Block gap event                   |
| DMA  | DMA transfer event                |
| BWR  | Buffer write ready                |
| BRR  | Buffer read ready                 |
| CIRQ | Card interrupt (special clearing) |
| CINS | Card inserted                     |
| CREM | Card removed                      |

**Error interrupts:**

| Flag  | Error                                      |
| ----- | ------------------------------------------ |
| CTO   | Command timeout (no response in 64 clocks) |
| CCRC  | CRC7 error in response                     |
| CEB   | End bit error in response                  |
| CIE   | Command index mismatch                     |
| DTO   | Data timeout                               |
| DCRC  | CRC16 data error                           |
| DEB   | Data end bit error                         |
| ACE   | Auto CMD12 error                           |
| ADMAE | ADMA error                                 |
| CERR  | Card status error                          |
| BADA  | Invalid buffer access                      |

**CIRQ special handling:** Cannot clear by writing 1. Must: (1) Disable CIRQ_ENABLE; (2) Clear source in SDIO CCCR; (3) Re-enable CIRQ_ENABLE.

**ERRI:** Auto-set when any SD_STAT[31:16] error bit is set; auto-cleared when all error bits clear. Cannot be cleared directly.

## DMA Operations

Controller is DMA slave only. Two requests: SDMAWREQN (write), SDMARREQN (read). One request per block.

- **Receive:** Request asserted when full block written to buffer; deasserted after first word read.
- **Transmit:** Request asserted when block space available; deasserted after first word written.
- **ADMA2:** 32-bit address ADMA2 mode available (DMA_MnS=0, DMAS=2).

## Buffer Management

- **1024-byte buffer** with 32-bit SD_DATA access; double buffering for blocks ≤ 512 bytes.
- **Read:** Only when BRR=1, else BADA error. **Write:** Only when BWE=1, else BADA error.
- **Access:** Little-endian, sequential and contiguous. DDIR must be configured before transfer.

**Buffering modes:**

| Memory Size | Double Buffer (BLEN ≤) | Single Buffer (BLEN range) |
| ----------- | ---------------------- | -------------------------- |
| 512 bytes   | N/A                    | ≤ 512                      |
| 1024 bytes  | ≤ 512                  | 513–1024                   |
| 2048 bytes  | ≤ 1024                 | 1025–2048                  |
| 4096 bytes  | ≤ 2048                 | N/A                        |

## Transfer Control

**Auto CMD12 (ACEN):** Automatically issues CMD12 after last block in multi-block transfers. Response stored in SD_RSP76.

**Stop at Block Gap (SBGR):** Holds transfer at block boundary; allows CMD12 during pause. Resume with CR bit.

**Transfer stop methods:**

| Transfer Type          | Before Boundary     | At Boundary End           |
| ---------------------- | ------------------- | ------------------------- |
| Single block           | Auto complete       | Auto complete             |
| Multi-block (finite)   | Send CMD12 or CMD52 | Auto CMD12 or stop at gap |
| Multi-block (infinite) | Send CMD12 or CMD52 | Set SBGR, send CMD52      |

## Signal Timing

- **HSPE=0** (default): CMD/DAT driven on falling edge (maximizes hold timing).
- **HSPE=1** (high speed): CMD/DAT driven on rising edge (increases setup timing; required for SDR; do NOT use in DDR mode).

## Boot Mode

### Boot via CMD0 (BOOT_CF0=0)

1. Set BOOT_CF0=0; optionally set BOOT_ACK.
2. Configure MMCHS_BLK (block length and count).
3. Set MMCHS_SYSCTL[DTO] timeout.
4. Write argument to MMCHS_ARG.
5. Issue CMD0 with DP=1, DDIR=1, MSBS=1, BCE=1.
6. Sequence: ≥74 clocks after power stable → CMD0 → optional boot status → data blocks → CMD0/reset to exit → ≥56 clocks before next command.

### Boot with CMD Line Held Low (BOOT_CF0=1)

1. Set BOOT_CF0=1; optionally BOOT_ACK.
2. Configure MMCHS_BLK, MMCHS_SYSCTL[DTO].
3. Write MMCHS_CMD with DP=1, DDIR=1, MSBS=1, BCE=1.
4. Exit: Clear BOOT_CF0 to release CMD line.

## Error Handling

**Command errors:**

| Error | Detection                | Recovery                              |
| ----- | ------------------------ | ------------------------------------- |
| CTO   | No response in 64 cycles | Retry or abort                        |
| CCRC  | CRC7 mismatch            | Can indicate bus conflict if with CTO |
| CEB   | End bit=0                | Check bus integrity                   |
| CIE   | Response index mismatch  | Command protocol error                |
| CERR  | Error in R1/R1b/R5/R6    | Check card status                     |

**Data errors:**

| Error | Conditions                                                                | Handling            |
| ----- | ------------------------------------------------------------------------- | ------------------- |
| DTO   | Busy timeout (R1b/R5b); write CRC timeout; read timeout; boot ack timeout | SRD software reset  |
| DCRC  | CRC16 error; invalid CRC status token                                     | Retransmit block    |
| DEB   | End bit=0 in data                                                         | Check bus integrity |

## Initialization Sequence

**Pre-requisites:** Enable PRCM clocks; configure pad muxing (Control Module); optionally configure MPU INTC and EDMA.

**Controller initialization:**

1. Enable OCP and CLKADPI clocks via PRCM.
2. Software reset: SD_SYSCONFIG[SOFTRESET]=1; poll SD_SYSSTATUS[RESETDONE]=1.
3. Set capabilities: Write SD_CAPA[26:24] and SD_CUR_CAPA[23:0].
4. Configure wakeup: SD_SYSCONFIG[ENAWAKEUP], SD_HCTL[IWE], SD_IE[CIRQENABLE].
5. Configure bus: Write SD_HCTL (SDVS, SDBP, DTW); verify SDBP=1; set SD_SYSCTL[ICE]=1; configure CLKD; poll SD_SYSCTL[ICS]=1; write SD_SYSCONFIG (CLOCKACTIVITY, SIDLEMODE, AUTOIDLE); configure SD_CON.

**Card identification:**

1. Set SD_CON[INIT]=1 → write 0x00000000 to SD_CMD → poll SD_STAT[CC]=1 → clear CC → set SD_CON[INIT]=0 → wait 1 ms → clear SD_STAT.
2. Detect: CMD0 → CMD8 (SD 2.0+) → CMD5 (SDIO) → CMD1 (MMC).
3. Select: ACMD41/CMD1 until not busy → CMD2 (CID) → CMD3 (RCA) → CMD7 (select).

## Register Map

**Register access rule:** Only 32-bit accesses allowed; 16-bit/8-bit accesses corrupt registers.

| Offset | Register     | Description                              |
| ------ | ------------ | ---------------------------------------- |
| 0x110  | SD_SYSCONFIG | System Configuration                     |
| 0x114  | SD_SYSSTATUS | System Status                            |
| 0x124  | SD_CSRE      | Card Status Response Error               |
| 0x128  | SD_SYSTEST   | System Test                              |
| 0x12C  | SD_CON       | Configuration                            |
| 0x130  | SD_PWCNT     | Power Counter                            |
| 0x200  | SD_SDMASA    | SDMA System Address                      |
| 0x204  | SD_BLK       | Block Length/Count                       |
| 0x208  | SD_ARG       | Command Argument                         |
| 0x20C  | SD_CMD       | Command and Transfer Mode                |
| 0x210  | SD_RSP10     | Response [31:0]                          |
| 0x214  | SD_RSP32     | Response [63:32]                         |
| 0x218  | SD_RSP54     | Response [95:64]                         |
| 0x21C  | SD_RSP76     | Response [127:96] / Auto CMD12 response  |
| 0x220  | SD_DATA      | Data Register (32-bit, 1024-byte buffer) |
| 0x224  | SD_PSTATE    | Present State (read-only)                |
| 0x228  | SD_HCTL      | Host Control                             |
| 0x22C  | SD_SYSCTL    | System Control                           |
| 0x230  | SD_STAT      | Interrupt Status (W1C)                   |
| 0x234  | SD_IE        | Interrupt Enable                         |
| 0x238  | SD_ISE       | Interrupt Signal Enable                  |
| 0x23C  | SD_AC12      | Auto CMD12 Error Status                  |
| 0x240  | SD_CAPA      | Capabilities                             |
| 0x248  | SD_CUR_CAPA  | Current Capabilities                     |
| 0x250  | SD_FE        | Force Event (not physically implemented) |
| 0x254  | SD_ADMAES    | ADMA Error Status                        |
| 0x258  | SD_ADMASAL   | ADMA System Address Low                  |
| 0x25C  | SD_ADMASAH   | ADMA System Address High                 |
| 0x2FC  | SD_REV       | Versions (reset=0x31010000)              |

## Key Register Descriptions

### SD_SYSCONFIG (0x110)

| Bits | Field         | Type | Reset | Description                                            |
| ---- | ------------- | ---- | ----- | ------------------------------------------------------ |
| 9-8  | CLOCKACTIVITY | R/W  | 0     | 0=Both off; 1=Interface on; 2=Functional on; 3=Both on |
| 4-3  | SIDLEMODE     | R/W  | 0     | 0=Force-idle; 1=No-idle; 2=Smart-idle; 3=Reserved      |
| 2    | ENAWAKEUP     | R/W  | 0     | 0=Disabled; 1=Enabled                                  |
| 1    | SOFTRESET     | R/W  | 0     | Write 1 to trigger reset                               |
| 0    | AUTOIDLE      | R/W  | 0     | 0=Free-running; 1=Auto gate                            |

### SD_SYSSTATUS (0x114)

| Bits | Field     | Type | Reset | Description                       |
| ---- | --------- | ---- | ----- | --------------------------------- |
| 0    | RESETDONE | R    | 0     | 0=Reset ongoing; 1=Reset complete |

### SD_CON (0x12C)

| Bits | Field      | Type | Reset | Description                                         |
| ---- | ---------- | ---- | ----- | --------------------------------------------------- |
| 21   | SDMA_LnE   | R/W  | 0     | DMA request: 0=Edge; 1=Level                        |
| 20   | DMA_MnS    | R/W  | 0     | 0=Slave (only supported); 1=Master (N/A)            |
| 19   | DDR        | R/W  | 0     | DDR mode (not supported on AM335x, always 0)        |
| 18   | BOOT_CF0   | R/W  | 0     | Boot CMD line: 0=Normal; 1=Force CMD to 0           |
| 17   | BOOT_ACK   | R/W  | 0     | 0=No ack; 1=Expect boot status                      |
| 16   | CLKEXTFREE | R/W  | 0     | External clock: 0=Cut off; 1=Maintain               |
| 15   | PADEN      | R/W  | 0     | PAD power: 0=Auto; 1=Force active                   |
| 12   | CEATA      | R/W  | 0     | 0=Standard; 1=CE-ATA mode                           |
| 11   | CTPL       | R/W  | 0     | 0=Disable all; 1=Keep DAT1 for SDIO interrupt       |
| 10-9 | DVAL       | R/W  | 0     | Debounce: 0=33µs; 1=231µs; 2=1ms; 3=8.4ms           |
| 8    | WPP        | R/W  | 0     | Write protect polarity: 0=Active high; 1=Active low |
| 7    | CDP        | R/W  | 0     | Card detect polarity: 0=Active high; 1=Active low   |
| 6    | MIT        | R/W  | 0     | MMC interrupt timeout: 0=Enabled; 1=Disabled        |
| 5    | DW8        | R/W  | 0     | 0=1/4-bit mode; 1=8-bit mode                        |
| 4    | MODE       | R/W  | 0     | 0=Functional; 1=SYSTEST                             |
| 3    | STR        | R/W  | 0     | 0=Block; 1=Stream command                           |
| 2    | HR         | R/W  | 0     | Host response: 0=Normal; 1=Generate response        |
| 1    | INIT       | R/W  | 0     | 0=Normal; 1=Send init sequence                      |
| 0    | OD         | R/W  | 0     | 0=Push-pull; 1=Open drain                           |

### SD_BLK (0x204)

| Bits  | Field | Type | Reset | Description                                   |
| ----- | ----- | ---- | ----- | --------------------------------------------- |
| 31-16 | NBLK  | R/W  | 0     | Number of blocks: 0=Stop; 1–65535=block count |
| 11-0  | BLEN  | R/W  | 0     | Block length: 0=No transfer; 1–2048=bytes     |

### SD_CMD (0x20C)

> Writing the upper byte (CMD index) starts transfer immediately.

| Bits  | Field    | Type | Reset | Description                                |
| ----- | -------- | ---- | ----- | ------------------------------------------ |
| 29-24 | INDX     | R/W  | 0     | Command index 0–63                         |
| 23-22 | CMD_TYPE | R/W  | 0     | 0=Normal; 1=Suspend; 2=Resume; 3=Abort     |
| 21    | DP       | R/W  | 0     | 0=No data; 1=Data transfer                 |
| 20    | CICE     | R/W  | 0     | Command index check: 0=Disabled; 1=Enabled |
| 19    | CCCE     | R/W  | 0     | Command CRC check: 0=Disabled; 1=Enabled   |
| 17-16 | RSP_TYPE | R/W  | 0     | 0=None; 1=136-bit; 2=48-bit; 3=48-bit+busy |
| 5     | MSBS     | R/W  | 0     | 0=Single block; 1=Multiple blocks          |
| 4     | DDIR     | R/W  | 0     | 0=Write; 1=Read                            |
| 2     | ACEN     | R/W  | 0     | Auto CMD12: 0=Disabled; 1=Enabled          |
| 1     | BCE      | R/W  | 0     | Block count: 0=Disabled; 1=Enabled         |
| 0     | DE       | R/W  | 0     | DMA: 0=Disabled; 1=Enabled                 |

### SD_PSTATE (0x224) — Read-Only

| Bits  | Field | Description                                  |
| ----- | ----- | -------------------------------------------- |
| 24    | CLEV  | CMD line level                               |
| 23-20 | DLEV  | DAT[3:0] line levels                         |
| 19    | WP    | Write protect (SDWP pin)                     |
| 18    | CDPL  | Card detect pin level (inverse of SDCD)      |
| 17    | CSS   | Card state stable: 0=Debouncing; 1=Stable    |
| 16    | CINS  | Card inserted (debounced SDCD)               |
| 11    | BRE   | Buffer read enable: 0=No data; 1=Ready       |
| 10    | BWE   | Buffer write enable: 0=No space; 1=Available |
| 9     | RTA   | Read transfer active                         |
| 8     | WTA   | Write transfer active                        |
| 2     | DLA   | DAT line active                              |
| 1     | DATI  | Command inhibit DAT                          |
| 0     | CMDI  | Command inhibit CMD                          |

### SD_HCTL (0x228)

| Bits | Field | Type | Reset | Description                                  |
| ---- | ----- | ---- | ----- | -------------------------------------------- |
| 27   | OBWE  | R/W  | 0     | Out-of-band wake enable                      |
| 26   | REM   | R/W  | 0     | Card removal wake enable                     |
| 25   | INS   | R/W  | 0     | Card insertion wake enable                   |
| 24   | IWE   | R/W  | 0     | Card interrupt wake enable                   |
| 19   | IBG   | R/W  | 0     | Interrupt at block gap                       |
| 18   | RWC   | R/W  | 0     | Read wait control                            |
| 17   | CR    | R/W  | 0     | Continue request (write 1 to restart)        |
| 16   | SBGR  | R/W  | 0     | Stop at block gap: 0=Transfer; 1=Stop        |
| 11-9 | SDVS  | R/W  | 0     | SD bus voltage: 5=1.8V; 6=3.0V; 7=3.3V       |
| 8    | SDBP  | R/W  | 0     | SD bus power: 0=Off; 1=On                    |
| 7    | CDSS  | R/W  | 0     | Card detect source: 0=SDCD pin; 1=Test level |
| 6    | CDTL  | R/W  | 0     | Card detect test level                       |
| 4-3  | DMAS  | R/W  | 0     | DMA select: 2=ADMA2; others reserved         |
| 2    | HSPE  | R/W  | 0     | 0=Normal; 1=High speed                       |
| 1    | DTW   | R/W  | 0     | Data width: 0=1-bit; 1=4-bit                 |

### SD_SYSCTL (0x22C)

| Bits  | Field | Type | Reset | Description                               |
| ----- | ----- | ---- | ----- | ----------------------------------------- |
| 26    | SRD   | R/W  | 0     | Software reset DAT (write 1, auto-clears) |
| 25    | SRC   | R/W  | 0     | Software reset CMD (write 1, auto-clears) |
| 24    | SRA   | R/W  | 0     | Software reset all (write 1, auto-clears) |
| 19-16 | DTO   | R/W  | 0     | Data timeout: 0=TCF×2¹³ … 14=TCF×2²⁷      |
| 15-6  | CLKD  | R/W  | 0     | Clock divider: 0–1=Bypass; 2–1023=÷N      |
| 2     | CEN   | R/W  | 0     | Clock enable: 0=Disabled; 1=Enabled       |
| 1     | ICS   | R    | 0     | Internal clock stable                     |
| 0     | ICE   | R/W  | 0     | Internal clock enable                     |

### SD_STAT (0x230) — Write 1 to Clear

| Bits | Field | Description                                |
| ---- | ----- | ------------------------------------------ |
| 29   | BADA  | Bad buffer access                          |
| 28   | CERR  | Card error                                 |
| 25   | ADMAE | ADMA error                                 |
| 24   | ACE   | Auto CMD12 error                           |
| 22   | DEB   | Data end bit error                         |
| 21   | DCRC  | Data CRC error                             |
| 20   | DTO   | Data timeout error                         |
| 19   | CIE   | Command index error                        |
| 18   | CEB   | Command end bit error                      |
| 17   | CCRC  | Command CRC error                          |
| 16   | CTO   | Command timeout error                      |
| 15   | ERRI  | Error interrupt (auto-set/cleared)         |
| 10   | BSR   | Boot status received                       |
| 9    | OBI   | Out-of-band interrupt (read-only)          |
| 8    | CIRQ  | Card interrupt (special clearing required) |
| 7    | CREM  | Card removal                               |
| 6    | CINS  | Card insertion                             |
| 5    | BRR   | Buffer read ready                          |
| 4    | BWR   | Buffer write ready                         |
| 3    | DMA   | DMA interrupt                              |
| 2    | BGE   | Block gap event                            |
| 1    | TC    | Transfer complete                          |
| 0    | CC    | Command complete                           |

### SD_IE (0x234) and SD_ISE (0x238)

SD_IE enables status bit updates; SD_ISE enables interrupt signal generation. Bit layout mirrors SD_STAT with `_ENABLE` suffix (SD_IE) and `_SIGEN` suffix (SD_ISE).

- SD_IE[15] = NULL (fixed 0); error interrupts controlled via SD_ISE.
- CIRQ_ENABLE (bit 8): Clearing also clears CIRQ status. Must be 1 in smart idle mode.
- CREM_ENABLE/CINS_ENABLE (bits 7/6): Must be 1 in smart idle mode for wake-up.

### SD_PWCNT (0x130)

| Bits | Field  | Type | Reset | Description                                                                                      |
| ---- | ------ | ---- | ----- | ------------------------------------------------------------------------------------------------ |
| 15-0 | PWRCNT | R/W  | 0     | Delay (in TCF periods) between PADACTIVE and first command. 0=No delay; 0xFFFF=65535 TCF periods |

### SD_AC12 (0x23C) — Auto CMD12 Error Status

| Bit | Field | Description                                |
| --- | ----- | ------------------------------------------ |
| 7   | CNI   | Command not issued: 0=Issued; 1=Not issued |
| 4   | ACIE  | Auto CMD12 index error                     |
| 3   | ACEB  | Auto CMD12 end bit error                   |
| 2   | ACCE  | Auto CMD12 CRC error                       |
| 1   | ACTO  | Auto CMD12 timeout                         |
| 0   | ACNE  | Auto CMD12 not executed                    |

### SD_CAPA (0x240)

| Bits  | Field     | Type | Reset | Description                                   |
| ----- | --------- | ---- | ----- | --------------------------------------------- |
| 28    | BUS_64BIT | R/W  | 0     | 0=32-bit; 1=64-bit system bus                 |
| 26    | VS18      | R/W  | 0     | 1.8V support                                  |
| 25    | VS30      | R/W  | 0     | 3.0V support                                  |
| 24    | VS33      | R/W  | 0     | 3.3V support                                  |
| 22    | DS        | R    | 0     | DMA support                                   |
| 21    | HSS       | R    | 0     | High speed support                            |
| 19    | AD2S      | R    | 0     | ADMA2 support                                 |
| 17-16 | MBL       | R    | 0     | Max block length: 0=512; 1=1024; 2=2048 bytes |
| 13-8  | BCF       | R    | —     | Base clock frequency (MHz)                    |
| 7     | TCU       | R    | 0     | Timeout clock unit: 0=kHz; 1=MHz              |
| 5-0   | TCF       | R    | 0     | Timeout clock frequency                       |

### SD_CUR_CAPA (0x248)

| Bits  | Field   | Type | Description          |
| ----- | ------- | ---- | -------------------- |
| 23-16 | CUR_1V8 | R/W  | Max current for 1.8V |
| 15-8  | CUR_3V0 | R/W  | Max current for 3.0V |
| 7-0   | CUR_3V3 | R/W  | Max current for 3.3V |

### SD_ADMAES (0x254) — ADMA Error Status

| Bits | Field | Type | Description                               |
| ---- | ----- | ---- | ----------------------------------------- |
| 2    | LME   | W    | Length Mismatch Error                     |
| 1-0  | AES   | R/W  | ADMA state: 0=ST_STOP; 1=ST_FDS; 3=ST_TFR |

### SD_REV (0x2FC) — Reset = 0x31010000

| Bits  | Field | Description                                             |
| ----- | ----- | ------------------------------------------------------- |
| 31-24 | VREV  | Vendor version: 0x31 = v3.1                             |
| 23-16 | SREV  | Spec version: 0x01 = SD Host Spec v1.0                  |
| 0     | SIS   | Slot interrupt status (inverted; cleared by POR or SRA) |

## CE-ATA Support

Enable: SD_CON[CEATA]=1, ACEN=1. Send Command Completion Disable Signal (CCSD): SD_CON[HR]=1, SD_ARG=0, SD_CMD=0x00000000.

**CCSD/CCS timing cases:** (1) CCS before CCSD → CIRQ then CC; (2) CCS during CCSD → only CC; (3) CCS without CCSD → only CIRQ.

## Programming Notes

- **Clock:** Stop before frequency change; wait ICS=1 before CEN; use AUTOIDLE.
- **Error recovery:** SRA after timeout; SRC for command line; SRD for data line.
- **CIRQ:** Disable enable bit → clear card source → re-enable.
- **DMA:** Set DE bit with command; use ADMA2 (DMAS=2) for descriptor-based transfer.
- **Multi-block:** Use Auto CMD12 (ACEN=1); double buffer for blocks ≤ 512 bytes.
- **Smart-idle:** Enable ENAWAKEUP; set wake-up sources (IWE, INS, REM); enable CIRQ_ENABLE, CINS_ENABLE, CREM_ENABLE.
