---
title: AM335x Chapter 19 Universal Asynchronous Receiver/Transmitter (UART)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 19 Universal Asynchronous Receiver/Transmitter (UART)

## Overview

AM335x UART/IrDA module — full-duplex, 16C750 compatible. Six instances (UART0–UART5).

## Instances

| Instance | Base Address | Features |
|----------|-------------|----------|
| UART0 | 0x44E09000 | Wakeup capability; CTS/RTS only |
| UART1 | 0x48022000 | Full modem (CTS/RTS/DSR/DTR/RI/DCD) |
| UART2 | 0x48024000 | CTS/RTS only |
| UART3 | 0x481A6000 | CTS/RTS only |
| UART4 | 0x481A8000 | CTS/RTS only |
| UART5 | 0x481AA000 | CTS/RTS only |

> Full modem on UART0, UART2–5: DCD/DSR/DTR/RI not pinned out. Wakeup on UART1–5: not supported (no SWake). DMA mode 2 and 3: not supported (only mode 0 and 1 with EDMA).

## UART Mode Features

- 16C750 compatibility; 300 bps to 3.6864 Mbps; auto-baud 1200–115.2 Kbps
- Flow control: software (XON/XOFF) and hardware (Auto-RTS/Auto-CTS)
- Frame: 5/6/7/8-bit; parity (even/odd/mark/space/none); 1/1.5/2 stop bits
- 64-byte TX and RX FIFOs; fully prioritized interrupts; internal loopback
- Modem: CTS, RTS, DSR, DTR, RI, DCD; false start bit detection; line break

## IrDA Mode Features

- IrDA 1.4: SIR, MIR, FIR (VFIR not supported)
- Variable xBOF/EOF; CRC uplink/downlink; 8-entry status FIFO
- Errors: framing, CRC, illegal symbol (FIR), abort pattern (SIR/MIR)

## CIR Mode Features

- Consumer IR; selectable bit rate; configurable carrier frequency
- Carrier duty cycle: 1/2, 5/12, 1/3, or 1/4

## Functional Clock

Functional clock: 48 MHz (typical).

**Baud rate formula:**
```
Baud Rate = UART_CLK / (16 × Divisor)    [16x mode]
Baud Rate = UART_CLK / (13 × Divisor)    [13x mode]
Divisor = (DLH[5:0] << 8) | DLL[7:0]     range: 1–16383
```

**Common divisors at 48 MHz:**

| Baud Rate | Divisor | DLH | DLL |
|-----------|---------|-----|-----|
| 300 | 10000 | 0x27 | 0x10 |
| 9600 | 312 | 0x01 | 0x38 |
| 19200 | 156 | 0x00 | 0x9C |
| 38400 | 78 | 0x00 | 0x4E |
| 57600 | 52 | 0x00 | 0x34 |
| 115200 | 26 | 0x00 | 0x1A |
| 230400 | 13 | 0x00 | 0x0D |
| 460800 | 6 | 0x00 | 0x06 |
| 921600 | 3 | 0x00 | 0x03 |

## Mode Selection — UART_MDR1[2:0]

| Value | Mode |
|-------|------|
| 0x0 | UART 16x |
| 0x1 | SIR |
| 0x2 | UART 16x auto-baud |
| 0x3 | UART 13x |
| 0x4 | MIR |
| 0x5 | FIR |
| 0x6 | CIR |
| 0x7 | Disabled (default) |

> MDR1[2:0] must be set last after all configuration registers are programmed. Do not change during operation.

## Register Access Modes

| Mode | LCR Value | Access |
|------|-----------|--------|
| Operational | LCR[7]=0 | THR/RHR, IER, IIR/FCR, MCR, LSR |
| Configuration A | LCR=0x80 | DLL, DLH, MCR |
| Configuration B | LCR=0xBF | DLL, DLH, EFR, XON/XOFF registers |

**Sub-modes (within any mode):**
- **TCR_TLR**: EFR[4]=1 AND MCR[6]=1 → access UART_TCR, UART_TLR
- **MSR_SPR**: EFR[4]=0 OR MCR[6]=0 → access UART_MSR, UART_SPR
- **XOFF** (Config B only): EFR[4]=0 OR MCR[6]=0 → access UART_XOFF1, UART_XOFF2

**Register map by mode (offset → register):**

| Offset | Config A | Config B | Operational |
|--------|----------|----------|-------------|
| 0x00 | UART_DLL | UART_DLL | UART_RHR (R) / UART_THR (W) |
| 0x04 | UART_DLH | UART_DLH | UART_IER |
| 0x08 | UART_IIR (R) / UART_FCR (W) | UART_EFR | UART_IIR (R) / UART_FCR (W) |
| 0x0C | UART_LCR | UART_LCR | UART_LCR |
| 0x10 | UART_MCR | UART_XON1 | UART_MCR |
| 0x14 | UART_LSR | UART_XON2 | UART_LSR |
| 0x18 | UART_MSR / UART_TCR | UART_TCR / UART_XOFF1 | UART_MSR / UART_TCR |
| 0x1C | UART_SPR / UART_TLR | UART_TLR / UART_XOFF2 | UART_SPR / UART_TLR |

## FIFO Management

- **TX FIFO:** Interrupt/DMA when level ≤ trigger; **RX FIFO:** when level ≥ trigger.
- **Granularity:** SCR[7] RX_TRIG_GRANU1 and SCR[6] TX_TRIG_GRANU1: 0=4 chars; 1=1 char.
- **DMA modes:** 0=no DMA; 1=UART_NDMA_REQ[0]=TX, [1]=RX; 2=UART_NDMA_REQ[0]=RX; 3=UART_NDMA_REQ[0]=TX.
- DMA mode 2 and 3 not supported on AM335x.

## Interrupt Priority (highest → lowest)

1. LINE_STS_IT — errors (OE, PE, FE, BI)
2. RHR_IT — RX data available
3. RX character timeout
4. THR_IT — TX FIFO empty
5. MODEM_STS_IT — CTS/DSR/RI/DCD change
6. XOFF_IT — XON/XOFF detected
7. RTS_IT — RTS level change
8. CTS_IT — CTS level change

**UART_IIR IT_TYPE field values:**

| IT_TYPE | Interrupt | Priority |
|---------|-----------|----------|
| 0x00 | Modem | 4 |
| 0x01 | THR | 3 |
| 0x02 | RHR | 2 |
| 0x03 | Receiver line status error | 1 (highest) |
| 0x06 | RX timeout | 2 |
| 0x08 | Xoff/special character | 5 |
| 0x10 | CTS/RTS/DSR state change | 6 (lowest) |

IT_PENDING bit: 0=interrupt pending; 1=no interrupt (reset=1).

## Hardware Flow Control

**Auto-RTS:** RTS driven based on RX FIFO level. Enable: UART_EFR[6] AUTO_RTS_EN.
**Auto-CTS:** TX halted when CTS deasserted. Enable: UART_EFR[7] AUTO_CTS_EN.

**UART_TCR thresholds** (values ×4 = actual character count):

| TCR Bits | Threshold |
|----------|-----------|
| [7:4] | AUTO_RTS_START: assert RTS when RX FIFO ≤ threshold×4 |
| [3:0] | AUTO_RTS_HALT: deassert RTS when RX FIFO ≥ threshold×4 |

> Hardware and software flow control cannot be used simultaneously.

## Software Flow Control

Enable via UART_EFR[3:2]. Programmable characters: UART_XON1/XON2, UART_XOFF1/XOFF2.

## Error Detection (UART_LSR, reset=0x60)

| Bit | Field | Description |
|-----|-------|-------------|
| 7 | RXFIFOSTS | ≥1 error (parity/framing/break) in RX FIFO |
| 6 | TXSRE | TX FIFO and shift register both empty |
| 5 | TXFIFOE | TX FIFO empty (transmission not necessarily complete) |
| 4 | RXBI | Break: RX low for ≥1 char + 1 bit time |
| 3 | RXFE | Framing error: no valid stop bit |
| 2 | RXPE | Parity error |
| 1 | RXOE | Overrun: shift register full, RX FIFO full |
| 0 | RXFIFOE | RX FIFO data available |

> LSR[4:2] reflect errors of character at top of RX FIFO. LSR[7] set if any error anywhere in RX FIFO; cleared only when no more errors remain. Reading LSR clears OE; does NOT increment RX FIFO read pointer.

## Key Register Descriptions

### UART_IER (Offset 0x04, Operational Mode)

| Bit | Field | Description |
|-----|-------|-------------|
| 7 | CTS_IT | CTS interrupt enable |
| 6 | RTS_IT | RTS interrupt enable |
| 5 | XOFF_IT | XOFF interrupt enable |
| 4 | SLEEP_MODE | Sleep mode enable (clear before accessing DLL/DLH) |
| 3 | MODEM_STS_IT | Modem status interrupt enable |
| 2 | LINE_STS_IT | Line status interrupt enable |
| 1 | THR_IT | THR empty interrupt enable |
| 0 | RHR_IT | RHR data available interrupt enable |

### UART_FCR (Offset 0x08, Write-only)

| Bits | Field | Description |
|------|-------|-------------|
| 7-6 | RX_FIFO_TRIG | RX trigger: 0x0=8; 0x1=16; 0x2=56; 0x3=60 chars |
| 5-4 | TX_FIFO_TRIG | TX trigger: 0x0=8; 0x1=16; 0x2=32; 0x3=56 spaces |
| 3 | DMA_MODE | DMA mode enable (see SCR[0] for alternative) |
| 2 | TX_FIFO_CLEAR | Clear TX FIFO (self-clearing) |
| 1 | RX_FIFO_CLEAR | Clear RX FIFO (self-clearing) |
| 0 | FIFO_ENABLE | FIFO enable (once enabled, disable only via reset or FCR[0]=0) |

### UART_LCR (Offset 0x0C)

| Bits | Field | Description |
|------|-------|-------------|
| 7 | DIV_EN | Divisor latch enable (selects Config A/B when LCR=0x80/0xBF) |
| 6 | BREAK_EN | Break control |
| 5 | PARITY_TYPE_2 | Parity type MSB |
| 4 | PARITY_TYPE_1 | Parity type LSB (00=Odd; 01=Even; 10=Mark; 11=Space) |
| 3 | PARITY_EN | Parity enable |
| 2 | NB_STOP | 0=1 stop; 1=1.5 (5-bit) or 2 stop bits |
| 1-0 | CHAR_LENGTH | 0x0=5; 0x1=6; 0x2=7; 0x3=8 bits |

### UART_MCR (Offset 0x10)

| Bit | Field | Description |
|-----|-------|-------------|
| 6 | TCR_TLR | Enable TCR/TLR access |
| 5 | XON_EN | XON any enable |
| 4 | LOOPBACK_EN | Loopback mode |
| 3 | CD_STS_CH | CD status (loopback) |
| 2 | RI_STS_CH | RI status (loopback) |
| 1 | RTS | RTS output control |
| 0 | DTR | DTR output control |

### UART_EFR (Offset 0x08, Config Mode B)

| Bits | Field | Description |
|------|-------|-------------|
| 7 | AUTO_CTS_EN | Auto-CTS enable |
| 6 | AUTO_RTS_EN | Auto-RTS enable |
| 5 | SPECIAL_CHAR_DETECT | Special character detect |
| 4 | ENHANCED_EN | Enhanced features enable (required for IER[7:4], TCR, TLR access) |
| 3 | SW_FLOW_TX | TX XON/XOFF enable |
| 2 | SW_FLOW_RX | RX XON/XOFF enable |
| 1 | XON2_XOFF2_EN | XON2/XOFF2 enable |
| 0 | XON1_XOFF1_EN | XON1/XOFF1 enable |

### UART_MDR1 (Offset 0x20, reset=0x07)

| Bits | Field | Description |
|------|-------|-------------|
| 7 | FRAME_END_MODE | IrDA: 0=Frame-length method; 1=Set EOT bit |
| 6 | SIP_MODE | MIR/FIR: 0=Manual SIP; 1=Auto SIP after TX |
| 5 | SCT | Store & control TX: 0=Start on THR write; 1=Start via ACREG[2] |
| 4 | SET_TXIR | IR transceiver: 0=See MDR2[7]; 1=Force TXIR high |
| 3 | IRSLEEP | IrDA/CIR sleep mode |
| 2-0 | MODE_SELECT | Operating mode (see table above) |

### UART_MDR2 (Offset 0x24)

| Bits | Field | Description |
|------|-------|-------------|
| 7 | SET_TXIR_ALT | Alternate function for MDR1[4] |
| 6 | IRRXINVERT | 0=Invert RX (default); 1=No inversion |
| 5-4 | CIR_PULSE_MODE | CIR high pulse width: 0=3/12; 1=4/12; 2=5/12; 3=6/12 cycles |
| 3 | UART_PULSE | UART pulse shaping |
| 2-1 | STS_FIFO_TRIG | IrDA status FIFO threshold: 0=1; 1=4; 2=7; 3=8 entries |
| 0 | IRTX_UNDERRUN | IrDA TX status: 0=Last bit OK; 1=TX underrun |

### UART_SCR (Offset 0x40)

| Bits | Field | Description |
|------|-------|-------------|
| 7 | RX_TRIG_GRANU1 | RX granularity: 0=4 chars; 1=1 char |
| 6 | TX_TRIG_GRANU1 | TX granularity: 0=4 chars; 1=1 char |
| 5 | DSR_IT | DSR interrupt enable |
| 4 | RXCTSDSRWAKEUPENABLE | RX/CTS wake-up: wait for falling edge on RX/CTS/DSR. Clear to disable and clear SSR[1]. |
| 3 | TXEMPTYCTLIT | TX empty: 0=Normal THR interrupt; 1=THR interrupt when both FIFO and shift register empty |
| 2-1 | DMA_MODE_2 | DMA mode (if SCR[0]=1): 0=No DMA; 1=Mode 1; 2=Mode 2; 3=Mode 3 |
| 0 | DMA_MODE_CTL | 0=DMA mode from FCR[3]; 1=DMA mode from SCR[2:1] |

> Wake-up interrupt (SCR[4]) is NOT mapped to IIR. To clear: reset SCR[4]=0. Check SSR[1] for wake-up status.

### UART_SYSC (Offset 0x54)

| Bits | Field | Description |
|------|-------|-------------|
| 4-3 | IDLEMODE | 0=Force-idle; 1=No-idle; 2=Smart-idle; 3=Smart-idle wakeup |
| 2 | ENAWAKEUP | Wakeup enable |
| 1 | SOFTRESET | Software reset (self-clearing) |
| 0 | AUTOIDLE | Auto-idle enable |

### UART_WER (Offset 0x5C, reset=0xFF — UART0 only)

All bits default to 1 (all wake-up sources enabled). Controls which events can wake the system.

| Bit | Field | Description |
|-----|-------|-------------|
| 7 | TXWAKEUPEN | TX event wake-up |
| 6 | RLS_INTERRUPT | Receiver line status interrupt wake-up |
| 5 | RHR_INTERRUPT | RHR interrupt wake-up |
| 4 | RX_ACTIVITY | RX activity wake-up |
| 3 | DCD_ACTIVITY | DCD activity wake-up |
| 2 | RI_ACTIVITY | RI activity wake-up |
| 1 | DSR_ACTIVITY | DSR activity wake-up |
| 0 | CTS_ACTIVITY | CTS activity wake-up |

### UART_SSR (Offset 0x44, reset=0x04)

| Bit | Field | Description |
|-----|-------|-------------|
| 2 | DMACOUNTERRST | 1=DMA counter reset when FIFO reset via FCR |
| 1 | RXCTSDSRWAKEUPSTS | Falling edge detected on RX/CTS/DSR (clear by resetting SCR[4]=0) |
| 0 | TXFIFOFULL | TX FIFO full |

### UART_UASR (Offset 0x38, auto-baud mode, Read-only)

| Bits | Field | Description |
|------|-------|-------------|
| 7-6 | PARITYTYPE | 0=No parity; 1=Space; 2=Even; 3=Odd |
| 5 | BITBYCHAR | 0=7-bit; 1=8-bit |
| 4-0 | SPEED | 1=115200; 2=57600; 3=38400; 4=28800; 5=19200; 6=14400; 7=9600; 8=4800; 9=2400; 0xA=1200 |

> Input frequency must be 48 MHz. Supports 7 and 8-bit chars only; 5/6-bit not supported. 7-bit with space parity not supported.

### UART_BLR (Offset 0x38, IrDA mode, reset=0x40)

| Bits | Field | Description |
|------|-------|-------------|
| 7 | STSFIFORESET | Status FIFO reset (self-clearing) |
| 6 | XBOFTYPE | SIR xBOF: 0=FFh pattern; 1=C0h pattern (default) |

### UART_EBLR (Offset 0x48)

| Bits | Field | Description |
|------|-------|-------------|
| 7-0 | EBLR | IrDA SIR: number of xBOFs (0=1BOF+255xBOF; N=1BOF+(N-1)xBOF). CIR: zeros before RXSTOP interrupt (0=disabled). |

### UART_CFPS (Offset 0x60, CIR mode, reset=0x69)

| Bits | Field | Description |
|------|-------|-------------|
| 7-0 | CFPS | System clock prescaler. Carrier_freq = 48MHz / (CFPS × 12). Default 0x69 (105) = 38.1 kHz. CFPS=0 not supported. |

### UART_MDR3 (Offset 0x80)

| Bits | Field | Description |
|------|-------|-------------|
| 2 | SET_DMA_TX_THRESHOLD | 1=Use TX_DMA_THRESHOLD register; 0=Use 64-tx_trigger |
| 1 | NONDEFAULT_FREQ | 1=Non-default clock enabled (changing this bit auto-disables UART) |
| 0 | DISABLE_CIR_RX_DEMOD | 0=CIR RX demodulation enabled; 1=Bypass |

### UART_TX_DMA_THRESHOLD (Offset 0x84)

| Bits | Field | Description |
|------|-------|-------------|
| 5-0 | TX_DMA_THRESHOLD | TX DMA threshold. Constraint: value + tx_trigger_level = 64. MDR3[2] must be 1. |

### Additional Read-only Registers

| Offset | Register | Description |
|--------|----------|-------------|
| 0x50 | UART_MVR | Module version (MAJORREV[10:8], MINORREV[5:0]); unaffected by reset |
| 0x64 | UART_RXFIFO_LVL | RX FIFO current fill count |
| 0x68 | UART_TXFIFO_LVL | TX FIFO current fill count |
| 0x6C | UART_IER2 | EN_TXFIFO_EMPTY[1], EN_RXFIFO_EMPTY[0] |
| 0x70 | UART_ISR2 | TXFIFO_EMPTY_STS[1], RXFIFO_EMPTY_STS[0] |
| 0x74 | UART_FREQ_SEL | Sample per bit for non-default fclk (must be ≥6; set MDR3[1]=1 after) |

### IrDA Frame Length Registers

| Offset | Register | Description |
|--------|----------|-------------|
| 0x28 (W) | UART_TXFLL | TX frame length low (8-bit LSB) |
| 0x2C (W) | UART_TXFLH | TX frame length high (5-bit MSB, 13-bit total) |
| 0x30 (W) | UART_RXFLL | Max RX frame length low; program n+3 (SIR/MIR) or n+6 (FIR) |
| 0x34 (W) | UART_RXFLH | Max RX frame length high (4-bit MSB, 12-bit total) |
| 0x28 (R) | UART_SFLSR | Status FIFO line status (reads and increments FIFO pointer); read SFREGL/SFREGH first |
| 0x30 (R) | UART_SFREGL | Status FIFO frame length LSB (read without incrementing pointer) |
| 0x34 (R) | UART_SFREGH | Status FIFO frame length MSB |
| 0x2C (R) | UART_RESUME | Read to restart halted TX/RX after underrun/overrun (always reads 0x00) |

## Configuration Sequences

### 1. Software Reset
1. UART_SYSC[1] SOFTRESET = 1
2. Poll UART_SYSS[0] RESETDONE = 1

### 2. FIFO and DMA Configuration
1. Save LCR; set LCR=0xBF; save EFR[4]; set EFR[4]=1
2. Set LCR=0x80; save MCR[6]; set MCR[6]=1
3. Write UART_FCR (RX_FIFO_TRIG, TX_FIFO_TRIG, DMA_MODE, FIFO_ENABLE)
4. Set LCR=0xBF; write UART_TLR (RX_FIFO_TRIG_DMA, TX_FIFO_TRIG_DMA)
5. Write UART_SCR (RX_TRIG_GRANU1, TX_TRIG_GRANU1, DMA_MODE_2, DMA_MODE_CTL)
6. Restore EFR[4]; set LCR=0x80; restore MCR[6]; restore LCR

### 3. Protocol and Baud Rate Configuration
1. Disable UART: MDR1[2:0]=0x7
2. Set LCR=0xBF; save EFR[4]; set EFR[4]=1
3. Set LCR=0x00; clear IER=0x00 (disables all interrupts; clears SLEEP_MODE)
4. Set LCR=0xBF; write DLL, DLH; set LCR=0x00; configure IER
5. Set LCR=0xBF; restore EFR[4]
6. Configure LCR (DIV_EN=0, frame format bits)
7. Set MDR1[2:0] to desired mode

### 4. Hardware Flow Control Configuration
1. Save LCR; set LCR=0x80; save MCR[6]; set MCR[6]=1
2. Set LCR=0xBF; save EFR[4]; set EFR[4]=1
3. Write UART_TCR (AUTO_RTS_START[7:4], AUTO_RTS_HALT[3:0])
4. Write UART_EFR (AUTO_CTS_EN[7], AUTO_RTS_EN[6]); restore EFR[4]
5. Set LCR=0x80; restore MCR[6]; restore LCR

### 5. Software Flow Control Configuration
1. Save LCR; set LCR=0xBF; save EFR[4]; set EFR[4]=0 (XOFF submode)
2. Write XON1/XON2/XOFF1/XOFF2; set EFR[4]=1
3. Set LCR=0x80; save MCR[6]; set MCR[6]=1
4. Configure UART_TCR thresholds
5. Set LCR=0xBF; configure EFR[3:0] SW_FLOW_CONTROL; restore EFR[4]
6. Set LCR=0x80; restore MCR[6]; restore LCR

## Important Notes

- **Register access:** Use correct mode sequence (LCR value) before each register access.
- **Divisor change:** Always disable UART (MDR1=0x7) before changing DLL/DLH.
- **SLEEP_MODE:** Clear IER[4] before accessing DLL/DLH.
- **ENHANCED_EN:** Set EFR[4]=1 to access IER[7:4], TCR, TLR.
- **FCR:** Write-only; cannot be read back.
- **Wakeup:** Only UART0 supports wakeup from low-power modes.
- **Interrupt clear:** Read LSR to clear line status interrupt; read IIR to clear others.
