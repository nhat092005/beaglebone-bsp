---
title: AM335x Chapter 21 — I2C
tags:
  - am335x
  - i2c
  - reference
source: "AM335x TRM Chapter 21"
---

# 21 I2C

## 21.1 Introduction

The AM335x contains **3 I2C instances**: I2C0 (Wakeup domain), I2C1, I2C2 (Peripheral domain). Each is a multi-master I2C compatible with Philips I2C spec v2.1.

### 21.1.1 Features

| Feature | Detail |
|---------|--------|
| Compliance | Philips I2C spec v2.1 |
| Speed modes | Standard (≤100 kbps), Fast (≤400 kbps) |
| Roles | Multimaster transmitter/slave receiver, Multimaster receiver/slave transmitter |
| Combined modes | Master TX/RX + RX/TX modes |
| Addressing | 7-bit and 10-bit |
| FIFO | 32 bytes each for TX and RX per module |
| Clock gen | Programmable prescaler |
| DMA | 2 DMA channels (TX + RX) per instance |
| Interrupts | 1 shared interrupt line; 12 interrupt event types |

### 21.1.2 Unsupported Features

| Feature | Reason |
|---------|--------|
| SCCB Protocol | Signal not pinned out |
| High Speed (3.4 Mbps) | Not supported |

---

## 21.2 Integration

### 21.2.1 I2C0 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Wakeup Domain |
| Clock Domain | PD_WKUP_L4_WKUP_GCLK (interface), PD_WKUP_I2C0_GFCLK (functional) |
| Reset | WKUP_DOM_RST_N |
| Idle/Wakeup | Smart Idle / Wakeup |
| Interrupts | 1 → MPU (I2C0INT), PRU-ICSS, WakeM3 |
| DMA | I2CTXEVT0, I2CRXEVT0 → EDMA |
| Physical Address | L4 Wakeup slave port |

### 21.2.2 I2C1 / I2C2 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | PD_PER_L4LS_GCLK (interface), PD_PER_I2C_FCLK (functional) |
| Reset | PER_DOM_RST_N |
| Idle/Wakeup | Smart Idle |
| Interrupts | 1 per instance → MPU (I2C1INT, I2C2INT) |
| DMA | I2CTXEVTx, I2CRXEVTx → EDMA |
| Physical Address | L4 Peripheral slave port |

### 21.2.3 Clock Signals

| Instance | Clock Type | Max Freq | Source | Domain |
|----------|-----------|----------|--------|--------|
| I2C0 | Interface (PIOCPCLK) | — | — | pd_wkup_l4_wkup_gclk |
| I2C0 | Functional (PISYSCLK) | 48 MHz | PER_CLKOUTM2 / 4 | pd_wkup_i2c0_gfclk |
| I2C1/2 | Interface (PIOCPCLK) | 100 MHz | CORE_CLKOUTM4 / 2 | pd_per_l4ls_gclk |
| I2C1/2 | Functional (PISYSCLK) | 48 MHz | PER_CLKOUTM2 / 4 | pd_per_ic2_fclk |

### 21.2.4 Pin List

| Pin | Type | Description |
|-----|------|-------------|
| I2Cx_SCL | I/OD | I2C serial clock (open drain). Set CONF_<pin>_RXACTIVE=1. 33Ω series resistor recommended. |
| I2Cx_SDA | I/OD | I2C serial data (open drain). Same requirement. |

---

## 21.3 Functional Description

### 21.3.1 Protocol Summary

| Condition | Signal behavior |
|-----------|----------------|
| START | SDA high→low while SCL high |
| STOP | SDA low→high while SCL high |
| Data valid | SDA stable during SCL high |
| Bus busy (BB=1) | After START, cleared on STOP |

**Address formats:**
- 7-bit: first byte = [ADDR[6:0] | R/nW]
- 10-bit: first byte = [11110 | ADDR[9:8] | R/nW=0], second byte = ADDR[7:0]
- Repeated START: restart without STOP; sets STP=0 in CON

### 21.3.2 Reset Methods

| Method | Trigger | Effect |
|--------|---------|--------|
| System reset | PIRSTNA=0 | All registers reset to power-up values |
| Software reset | I2C_SYSC.SRST=1 | All registers reset; auto-clears |
| Module reset | I2C_CON.I2C_EN=0 | Holds functional part in reset; registers accessible but not reset to POR values |

Reset state of pins: SDA, SCL → High impedance (system reset or I2C_EN=0)

### 21.3.3 Prescaler and Clock Generation

```
ICLK = SCLK / (I2C_PSC + 1)           ← internal clock; target ~12 MHz for F/S mode
                                           (recommended: PSC = SCLK/24MHz - 1 for ~24MHz ICLK)

SCL_frequency = ICLK / (SCLL + 7 + SCLH + 5)    ← approximation

Standard mode (100 kbps): SCLL = SCLH = (ICLK / 200kHz) - 7/5 adjusted
Fast mode (400 kbps): adjust SCLL, SCLH accordingly per I2C spec timing
```

> [!NOTE]
> Functional clock (SCLK/PISYSCLK) must be 12–100 MHz. For F/S mode, ~24 MHz ICLK is recommended (SCLK=48 MHz → PSC=1).

### 21.3.4 Noise Filter

Filter suppresses noise ≤ 1 ICLK cycle. For F/S mode (PSC=4, ICLK=24 MHz): max suppressed spike width = 41.6 ns. Must set prescaler before enabling filter.

### 21.3.5 Interrupts (12 Event Types)

| Bit | Flag | Description |
|-----|------|-------------|
| 14 | XDR | Transmit draining — TX FIFO below threshold, less data than TXTRSH remains |
| 13 | RDR | Receive draining — stop received, RX FIFO below threshold |
| 12 | BB | Bus busy (read-only) |
| 11 | ROVR | Receive overrun — shift register + RX FIFO full; bus held low |
| 10 | XUDF | Transmit underflow — shift register + TX FIFO empty, still bytes to send |
| 9 | AAS | Addressed as slave |
| 8 | BF | Bus free (stop condition detected) |
| 7 | AERR | Access error — write to full TX FIFO or read from empty RX FIFO |
| 6 | STC | Start condition detected (from idle, asynchronous wakeup) |
| 5 | GC | General call (address all-zeros detected) |
| 4 | XRDY | Transmit data ready — TX FIFO needs data |
| 3 | RRDY | Receive data ready — RX FIFO above threshold |
| 2 | ARDY | Register access ready — previous command complete, registers available |
| 1 | NACK | No-acknowledge received; auto-ends transfer, clears MST/STP |
| 0 | AL | Arbitration lost; auto-clears MST/STP, module becomes slave |

All 12 events share one hardware interrupt line. Write 1 to `I2C_IRQSTATUS_RAW` to set (debug); write 1 to `I2C_IRQSTATUS` to clear.

### 21.3.6 FIFO Management (32-byte TX and RX)

| Mode | Description |
|------|-------------|
| Interrupt mode | CPU serviced by XRDY/RRDY interrupts; threshold configured in I2C_BUF.TXTRSH/RXTRSH |
| Polling mode | Poll `I2C_IRQSTATUS_RAW.XRDY`/`.RRDY`; FIFO threshold still applies |
| DMA mode | RX DMA request when RX FIFO > RXTRSH; TX DMA when TX FIFO empty; de-assert DMA via DMARXENABLE_CLR/DMATXENABLE_CLR |

**Draining feature** (for transfers whose length is not a multiple of threshold):
- **XDR** asserted when TX FIFO below TXTRSH and remaining data < TXTRSH → read `I2C_BUFSTAT.TXSTAT` for byte count → write that many bytes or reconfigure DMA
- **RDR** asserted when STOP received and RX FIFO below RXTRSH → read `I2C_BUFSTAT.RXSTAT` for byte count → drain accordingly
- Enable draining: `I2C_IRQENABLE_SET.XDR_IE` / `.RDR_IE` (disabled by default)

> [!CAUTION]
> In Slave TX mode: set `I2C_BUF.TXTRSH=0` (threshold=1). Transfer length unknown; master can NACK at any time. If threshold > 1, TX FIFO may need manual clear on NACK.

---

## 21.4 I2C Programming Sequence

### 21.4.1 Module Configuration (before I2C_EN=1)

1. Set `I2C_PSC` = `(SCLK_MHz / target_ICLK_MHz) - 1` (target ICLK ~12–24 MHz for F/S)
2. Set `I2C_SCLL`, `I2C_SCLH` for target SCL frequency (100 k or 400 kbps)
3. Set `I2C_OA` = own slave address (if used as slave)
4. Set `I2C_CON.I2C_EN = 1` to exit reset

### 21.4.2 Initialization

1. Configure `I2C_CON`: MST, TRX, XA (10-bit), STP, STT as needed per transaction
2. Enable interrupt masks via `I2C_IRQENABLE_SET` (or configure DMA)
3. If DMA: set `I2C_BUF.XDMA_EN`/`RDMA_EN` and program `I2CDMATXENABLE_SET`/`I2CDMARXENABLE_SET`

### 21.4.3 Master Transmit

1. Poll `I2C_IRQSTATUS_RAW.BB` until 0 (bus free)
2. Set `I2C_CNT` = number of bytes to send
3. Set `I2C_SA` = slave address
4. Set `I2C_CON`: MST=1, TRX=1, STT=1 (+ STP=1 if final)
5. On XRDY interrupt / DMA: write data to `I2C_DATA`
6. On ARDY: transaction complete

### 21.4.4 Master Receive

1. Poll `BB` = 0
2. Set `I2C_CNT` = number of bytes to receive
3. Set `I2C_SA` = slave address
4. Set `I2C_CON`: MST=1, TRX=0, STT=1, STP=1
5. On RRDY interrupt / DMA: read data from `I2C_DATA`
6. On ARDY: transaction complete

### 21.4.5 Receive/Transmit Data

- Poll RRDY/XRDY in `I2C_IRQSTATUS_RAW`, or use interrupts (`I2C_IRQENABLE_SET.RRDY_IE/XRDY_IE`), or DMA
- For incomplete transfers (length not multiple of threshold): use draining feature enabled via `RDR_IE`/`XDR_IE`

---

## 21.5 I2C Register Map

Base addresses: I2C0=0x44E0B000, I2C1=0x4802A000, I2C2=0x4819C000

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | I2C_REVNB_LO | 0h | Revision low: RTL[15:11], MAJOR[10:8], CUSTOM[7:6], MINOR[5:0] |
| 4h | I2C_REVNB_HI | 0h | Revision high: SCHEME[15:14], FUNC[11:0] |
| 10h | I2C_SYSC | 0h | CLKACTIVITY[9:8], IDLEMODE[4:3], ENAWAKEUP[2], SRST[1], AUTOIDLE[0] |
| 24h | I2C_IRQSTATUS_RAW | 0h | All active events (enabled+disabled). W1 sets (debug), read for status |
| 28h | I2C_IRQSTATUS | 0h | Active AND enabled events. W1 clears (ACK). Same bit layout as RAW |
| 2Ch | I2C_IRQENABLE_SET | 0h | W1 enables event interrupt: XDR[14], RDR[13], ROVR[11], XUDF[10], AAS[9], BF[8], AERR[7], STC[6], GC[5], XRDY[4], RRDY[3], ARDY[2], NACK[1], AL[0] |
| 30h | I2C_IRQENABLE_CLR | 0h | W1 disables event interrupt (same bit layout as SET) |
| 34h | I2C_WE | 0h | Wakeup enable per event (same bit layout as irqenable, minus AERR) |
| 38h | I2C_DMARXENABLE_SET | 0h | W1 enables DMA RX |
| 3Ch | I2C_DMATXENABLE_SET | 0h | W1 enables DMA TX |
| 40h | I2C_DMARXENABLE_CLR | 0h | W1 de-asserts DMA RX request |
| 44h | I2C_DMATXENABLE_CLR | 0h | W1 de-asserts DMA TX request |
| 48h | I2C_DMARXWAKE_EN | 0h | DMA RX wakeup enable |
| 4Ch | I2C_DMATXWAKE_EN | 0h | DMA TX wakeup enable |
| 90h | I2C_SYSS | — | RDONE[0]: reset done (read-only) |
| 94h | I2C_BUF | — | XDMA_EN[15], TXFIFO_CLR[14], TXTRSH[13:8], RDMA_EN[7], RXFIFO_CLR[6], RXTRSH[5:0] |
| 98h | I2C_CNT | — | DCOUNT[15:0]: data byte count for transfer |
| 9Ch | I2C_DATA | — | TX/RX FIFO data register (8-bit access; write=TX, read=RX) |
| A4h | I2C_CON | 0h | I2C_EN[15], STB[11], MST[10], TRX[9], XA[8], RM[5], STP[1], STT[0] |
| A8h | I2C_OA | — | OA[9:0]: own address (7 or 10-bit) |
| ACh | I2C_SA | — | SA[9:0]: slave address for master transactions |
| B0h | I2C_PSC | — | PSC[7:0]: clock prescaler (ICLK = SCLK / (PSC+1)) |
| B4h | I2C_SCLL | — | SCLL[7:0]: SCL low time in ICLK periods (+ internal +7) |
| B8h | I2C_SCLH | — | SCLH[7:0]: SCL high time in ICLK periods (+ internal +5) |
| BCh | I2C_SYSTEST | — | FREE[14]: 1=ignore debug suspend. ST_EN[0]: test mode |
| C0h | I2C_BUFSTAT | — | FIFODEPTH[15:14], TXSTAT[13:8], RXSTAT[5:0] (bytes in TX/RX FIFO) |
| C4h | I2C_OA1 | — | OA1[9:0]: alternate own address 1 |
| C8h | I2C_OA2 | — | OA2[9:0]: alternate own address 2 |
| CCh | I2C_OA3 | — | OA3[9:0]: alternate own address 3 |
| D0h | I2C_ACTOA | — | Indicates which own address (OA/OA1/OA2/OA3) was used by external master |
| D4h | I2C_SBLOCK | — | Clock blocking enable |

### 21.5.1 I2C_CON Bit Detail

| Bit | Field | Description |
|-----|-------|-------------|
| 15 | I2C_EN | 0=module in reset (hold); 1=module active |
| 11 | STB | Start byte mode (master only) |
| 10 | MST | 0=slave, 1=master |
| 9 | TRX | 0=receiver, 1=transmitter |
| 8 | XA | 0=7-bit addressing, 1=10-bit addressing |
| 5 | RM | Repeat mode (no auto-STOP on DCOUNT=0) |
| 1 | STP | Generate STOP after transfer |
| 0 | STT | Generate START / repeated START condition |

### 21.5.2 I2C_SYSC Bit Detail

| Bit | Field | Description |
|-----|-------|-------------|
| 9-8 | CLKACTIVITY | 0=both can be cut; 1=only interface active; 2=only system clock active; 3=both active |
| 4-3 | IDLEMODE | 1=No-idle; 2=Smart-idle; 3=Smart-idle-wakeup (I2C0 only) |
| 2 | ENAWAKEUP | 0=wakeup disabled; 1=wakeup enabled |
| 1 | SRST | Software reset (auto-clears) |
| 0 | AUTOIDLE | 0=disabled; 1=auto-idle enabled |

---

## 21.6 Emulation Behavior

To halt I2C during debugger breakpoints:
1. Set `I2C_SYSTEST.FREE=0` (module respects debug suspend signal)
2. Set `xxx_Suspend_Control=0x9` in Debug Subsystem register (see Chapter 27)

If `FREE=1`, I2C ignores debug suspend and runs free.
