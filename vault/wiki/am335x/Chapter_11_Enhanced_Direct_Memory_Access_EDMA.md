---
title: AM335x Chapter 11 — Enhanced Direct Memory Access (EDMA)
tags:
  - am335x
  - edma
  - dma
  - reference
source: "AM335x TRM Chapter 11"
---

# 11 Enhanced Direct Memory Access (EDMA)

## 11.1 Introduction

The EDMA3 controller transfers data between memory-mapped slave endpoints without CPU involvement. It consists of two principal blocks:
- **EDMA3CC** — Channel Controller: manages parameter RAM (PaRAM), event/interrupt control, queue management
- **EDMA3TC0–TC2** — Transfer Controllers (3 instances): execute the actual data movement

### 11.1.1 EDMA3CC Features

| Feature | Value |
|---------|-------|
| DMA Channels | 64 |
| QDMA Channels | 8 |
| Event Inputs | 64 |
| PaRAM Entries | 256 (32 bytes each) |
| Event Queues | 3 (Q0→TC0, Q1→TC1, Q2→TC2) |
| Queue Depth | 16 entries per queue |
| Shadow Regions | 4 (regions 0–3) |
| Memory Protection Regions | 4 |
| Interrupt Outputs | 8 (regional); only 2 connected at system level |
| Priority Levels | 8 |

**Trigger types (DMA channels):**
- Event synchronization (peripheral event asserted)
- Manual (CPU write to ESR/ESRH)
- Chained (completion of another channel)

**QDMA channels**: Auto-triggered on write to trigger word in PaRAM (no event needed).

### 11.1.2 EDMA3TC (Transfer Controller) Features

| Feature | Value |
|---------|-------|
| Instances on AM335x | 3 (TC0, TC1, TC2; TC3 not supported) |
| FIFO Size | 512 bytes per TC |
| In-flight TRs | Up to 4 |
| Read/Write Master Ports | 128-bit |

### 11.1.3 Unsupported Features

- AET event generation output not connected
- Global completion interrupt not used; only regional completion interrupts
- TC3 not supported

---

## 11.2 Integration

### 11.2.1 Connectivity Attributes

| Attribute | TPCC | TPTC |
|-----------|------|------|
| Power Domain | Peripheral Domain | Peripheral Domain |
| Clock Domain | PD_PER_L3_GCLK | PD_PER_L3_GCLK |
| Max Clock | 200 MHz | 200 MHz |
| Reset | PER_DOM_RST_N | PER_DOM_RST_N |
| Idle/Wakeup | Smart Idle | Standby + Smart Idle |
| External Pins | None | None |

### 11.2.2 TPCC Interrupt Connections

| Signal | Destination | Description |
|--------|-------------|-------------|
| int_pend_po0 (EDMACOMPINT) | MPU Subsystem | Region 0 completion interrupt |
| int_pend_po1 (tpcc_int_pend_po1) | PRU-ICSS | Region 1 completion interrupt |
| int_pend_po[3:2] | — | Unused |
| errint_po (EDMAERRINT) | MPU Subsystem | Error interrupt |
| mpint_p0 (EDMAMPERR) | MPU Subsystem | Memory protection error |
| TCERRINTx | MPU + PRU-ICSS | TC error per instance |

---

## 11.3 Functional Description

### 11.3.1 Transfer Dimensions

| Dimension | Parameter | Description |
|-----------|-----------|-------------|
| 1st (Array) | ACNT | Number of contiguous bytes; valid 1–65535 |
| 2nd (Frame) | BCNT | Number of arrays per frame; valid 1–65535 |
| 3rd (Block) | CCNT | Number of frames per block; valid 1–65535 |

**Sync types** (OPT.SYNCDIM):
- **A-synchronized**: each event transfers 1 array (ACNT bytes); needs BCNT×CCNT events for full PaRAM set
- **AB-synchronized**: each event transfers 1 frame (BCNT×ACNT bytes); needs CCNT events for full PaRAM set

**Address indexing:**
- SRCBIDX / DSTBIDX: byte offset between arrays (signed, –32768 to 32767)
- SRCCIDX / DSTCIDX: byte offset between frames (signed, –32768 to 32767)
  - A-sync: offset from last array of frame N to first array of frame N+1
  - AB-sync: offset from first array of frame N to first array of frame N+1

### 11.3.2 Parameter RAM (PaRAM)

256 PaRAM sets; each 32 bytes (8 × 32-bit words):

| Offset | Field | Description |
|--------|-------|-------------|
| +00h | OPT | Channel Options (see below) |
| +04h | SRC | Source byte address |
| +08h | BCNT[31:16] / ACNT[15:0] | 2nd-dim count / 1st-dim count |
| +0Ch | DST | Destination byte address |
| +10h | DSTBIDX[31:16] / SRCBIDX[15:0] | Signed index between arrays |
| +14h | BCNTRLD[31:16] / LINK[15:0] | BCNT reload / Link PaRAM address (FFFFh = null link) |
| +18h | DSTCIDX[31:16] / SRCCIDX[15:0] | Signed index between frames |
| +1Ch | RSVD[31:16] / CCNT[15:0] | Reserved / 3rd-dim count |

**PaRAM address formula**: Base + 4000h + (set_no × 20h)

### 11.3.3 OPT Register (PaRAM offset 0h)

| Bit | Field | Description |
|-----|-------|-------------|
| 31 | PRIV | Privilege level of programmer (0=user, 1=supervisor) |
| 27–24 | PRIVID | Privilege ID of programmer (0–Fh) |
| 23 | ITCCHEN | Intermediate transfer completion chaining enable |
| 22 | TCCHEN | Final transfer completion chaining enable |
| 21 | ITCINTEN | Intermediate transfer completion interrupt enable |
| 20 | TCINTEN | Final transfer completion interrupt enable |
| 17–12 | TCC | Transfer Complete Code (0–3Fh); sets IPR[TCC] or CER[TCC] |
| 11 | TCCMODE | 0=Normal (after data transfer); 1=Early (after TR submitted to TC) |
| 10–8 | FWID | FIFO Width: 0=8b, 1=16b, 2=32b, 3=64b, 4=128b, 5=256b |
| 3 | STATIC | 0=PaRAM updated after TR; 1=PaRAM not updated (use for final QDMA) |
| 2 | SYNCDIM | 0=A-sync; 1=AB-sync |
| 1 | DAM | 0=Increment; 1=Constant (FIFO) addressing for destination |
| 0 | SAM | 0=Increment; 1=Constant (FIFO) addressing for source |

**FIFO mode constraint**: SAM/DAM=1 requires source/destination address 256-bit aligned (5 LSBs = 0).

### 11.3.4 Event Queues and Queue-to-TC Mapping

| Queue | Transfer Controller | Default Mapping |
|-------|---------------------|-----------------|
| Q0 | TC0 | Highest priority |
| Q1 | TC1 | Medium priority |
| Q2 | TC2 | Lowest priority |

Queue depth: 16 events. Overflow generates an error interrupt.

DMA channels map to queues via DMAQNUM registers; QDMA channels via QDMAQNUM.

### 11.3.5 Interrupt Generation

| Condition | Register Set |
|-----------|-------------|
| Intermediate completion | IPR/IPRH bit at TCC position (if ITCINTEN=1) |
| Final completion | IPR/IPRH bit at TCC position (if TCINTEN=1) |
| Enable completion IRQ to CPU | IER/IERH bit at TCC position must be 1 |
| Clear pending interrupt | Write 1 to ICR/ICRH |
| Chained event intermediate | CER/CERH bit (if ITCCHEN=1) |
| Chained event final | CER/CERH bit (if TCCHEN=1) |

---

## 11.4 EDMA3CC Register Summary

| Register | Offset | Description |
|----------|--------|-------------|
| REVID | 0x000 | Revision |
| CCCFG | 0x004 | Channel Controller Config (read-only capabilities) |
| DCHMAP0–63 | 0x100–0x1FC | DMA Channel to PaRAM mapping |
| QCHMAP0–7 | 0x200–0x21C | QDMA Channel to PaRAM + trigger word |
| DMAQNUM0–7 | 0x240–0x25C | DMA channel to queue assignment |
| QDMAQNUM | 0x260 | QDMA channel to queue assignment |
| QUETCMAP | 0x280 | Queue to TC mapping (fixed: Q0→TC0, Q1→TC1, Q2→TC2) |
| QUEPRI | 0x284 | Queue priority |
| EMR/EMRH | 0x300/0x304 | Missed Event Register (DMA) |
| EMCR/EMCRH | 0x308/0x30C | Missed Event Clear |
| QEMR | 0x310 | QDMA Missed Event |
| CCERR | 0x314 | Channel Controller Error (queue thresholds, etc.) |
| CCERRCLR | 0x318 | Clear CC error |
| EEVAL | 0x31C | Error Evaluate |
| ER/ERH | 0x1000/0x1004 | Event Register (pending events [63:0]) |
| ECR/ECRH | 0x1008/0x100C | Event Clear |
| ESR/ESRH | 0x1010/0x1014 | Event Set (manual trigger) |
| CER/CERH | 0x1018/0x101C | Chained Event Register |
| EER/EERH | 0x1020/0x1024 | Event Enable Register |
| EECR/EECRH | 0x1028/0x102C | Event Enable Clear |
| EESR/EESRH | 0x1030/0x1034 | Event Enable Set |
| SER/SERH | 0x1038/0x103C | Secondary Event Register |
| SECR/SECRH | 0x1040/0x1044 | Secondary Event Clear |
| IPR/IPRH | 0x1068/0x106C | Interrupt Pending (completion) |
| ICR/ICRH | 0x1070/0x1074 | Interrupt Clear |
| IEVAL | 0x1078 | Interrupt Evaluate |
| QER | 0x1080 | QDMA Event Register |
| QEER | 0x1084 | QDMA Event Enable |
| QCHR | 0x10A0 | QDMA Chained Event |
| Q0E0–Q0E15 | 0x1400–0x143C | Queue 0 entries (debug view) |

---

## 11.5 Programming Model

### Enable a DMA Transfer

1. Write transfer context to PaRAM set N: OPT, SRC, ACNT/BCNT, DST, SRCBIDX/DSTBIDX, LINK/BCNTRLD, SRCCIDX/DSTCIDX, CCNT
2. Map DMA channel CH to PaRAM set N via `DCHMAP[CH] = N << 5`
3. Assign channel to queue via `DMAQNUM[CH/8]`
4. Enable event via `EESR[CH]` (write 1)
5. For manual trigger: write 1 to `ESR[CH]`
6. For event-driven: enable peripheral DMA event; hardware asserts event pin
7. On completion: read IPR[TCC], write 1 to ICR[TCC] to clear

### Linking (Auto-Reload)

Set LINK field to PaRAM address of a "link" set. When current set is exhausted, PaRAM is reloaded from the link set. Set LINK=FFFFh for null link (no reload).

### QDMA Usage

1. Write PaRAM set with transfer parameters (OPT, SRC, counts, DST, indexes)
2. Write the trigger word field last (defined in `QCHMAP[n].TRWORD` — typically OPT or SRC or CCNT)
3. Writing the trigger word auto-submits the transfer request
