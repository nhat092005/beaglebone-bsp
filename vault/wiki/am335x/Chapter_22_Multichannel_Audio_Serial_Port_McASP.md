---
title: AM335x Chapter 22 — McASP (Condensed Wiki)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 22 Multichannel Audio Serial Port (McASP)

## Overview

The McASP is a general-purpose audio serial port optimized for multichannel audio. It supports TDM (2–384 time slots), I2S, and S/PDIF (DIT) protocols. Transmit and receive sections operate independently with separate master clocks, bit clocks, and frame syncs.

Two instances are available on this device: **McASP0** and **McASP1**. Each has **4 serializers**.

**Unsupported features on this device:**

| Feature  | Reason                     |
| -------- | -------------------------- |
| AXR[9:4] | Signals are not pinned out |
| AMUTE    | Not connected              |
| AMUTEIN  | Not connected              |

---

## Integration

### Clock Signals

| Clock Signal        | Max Freq | Source            |
| ------------------- | -------- | ----------------- |
| ocp_clk (Interface) | 100 MHz  | CORE_CLKOUTM4 / 2 |
| auxclk (Functional) | 26 MHz   | CLK_M_OSC         |

### Pin List

| Pin             | Type | Description                |
| --------------- | ---- | -------------------------- |
| McASPx_AXR[3:0] | I/O  | Audio transmit/receive pin |
| McASPx_ACLKX    | I/O  | Transmit clock             |
| McASPx_FSX      | I/O  | Frame sync for transmit    |
| McASPx_AHCLKX   | I/O  | High-speed transmit clock  |
| McASPx_ACLKR    | I/O  | Receive clock              |
| McASPx_FSR      | I/O  | Frame sync for receive     |
| McASPx_AHCLKR   | I/O  | High-speed receive clock   |

> **Note:** Clock/sync pins used as inputs must have the CONF*\<module\>*\<pin\>\_RXACTIVE bit set to 1. Place a 33-ohm resistor in series (close to the processor) on each of these signals.

### Interrupts and DMA

- 1 TX interrupt per instance (`x_intr_pend`) → MPU Subsystem and PRU-ICSS
- 1 RX interrupt per instance (`r_intr_pend`) → MPU Subsystem and PRU-ICSS
- 2 DMA requests per instance → EDMA (Transmit: AXEVTx, Receive: AREVTx)

---

## Functional Description

### Transfer Modes

| Mode    | XMOD/RMOD value    | Description                                      |
| ------- | ------------------ | ------------------------------------------------ |
| Burst   | 0                  | Non-audio, data-driven frame sync                |
| TDM     | 2–32 (2h–20h)      | Standard TDM/I2S (2 to 32 time slots)            |
| TDM-384 | 384 (180h) RX only | External DIR connection (S/PDIF receiver IC)     |
| DIT     | 384 (180h) TX only | S/PDIF, IEC60958-1, AES-3 output (DITEN bit = 1) |

### Protocol Details

**TDM / I2S:** Serial bit stream divided into slots. Frame sync marks the start of slot 0. Slot size: 8, 12, 16, 20, 24, 28, or 32 bits. No gap between slots.

**I2S:** 2-slot TDM (XMOD=2h). Left channel = slot 0, right channel = slot 1. Frame sync = LRCLK. XDATDLY/RDATDLY = 1 for I2S format.

**DIT (S/PDIF):** Transmit only. 384 subframes/block (192 frames × 2 subframes). Clock rate = 128 × fs. Biphase Mark Code (BMC) encoding: logic 1 = 2 transitions/cell (10 or 01); logic 0 = 1 transition/cell (00 or 11). Preamble codes: B/Z (start of block+subframe1), M/X (subframe1), W/Y (subframe2).

**Subframe format (32 time intervals):**

- 0–3: Preamble (not BMC encoded)
- 4–27: Audio sample (24 bits, MSB in interval 27)
- 28: Validity bit (V)
- 29: User data (U)
- 30: Channel status (C)
- 31: Parity bit (P, even parity over intervals 4–31)

### Clock and Frame Sync Generator

- Transmit and receive clock zones are independent (ASYNC bit in ACLKXCTL).
- Bit clock (ACLKX/ACLKR) can be: external, internal (divided from AHCLKX/AHCLKR), or mixed.
- High-freq master clock (AHCLKX/AHCLKR) can be: external, internal (divided from AUXCLK by HCLKXDIV/HCLKRDIV, range divide-by-1 to 4096).
- Frame sync: internally or externally generated, polarity selectable (FSXP/FSRP), width = single bit or single word (FXWID/FRWID).

**DIT transmit clock must be configured as:**

- AFSXCTL: FSXM=1, FSXP=0, FXWID=0, XMOD=180h
- ACLKXCTL: ASYNC=1
- XFMT: XSSZ=Fh (32-bit slot)

### Serializers and Format Unit

Each serializer has: shift register (XRSR), data buffer (XRBUF), control register (SRCTL[n]), and dedicated AXRn pin. SRCTL.SRMOD: 0=inactive, 1=transmitter, 2=receiver.

All transmitters operate in lock-step; all receivers operate in lock-step.

**Format unit stages (transmit: mask → rotate → reverse; receive: reverse → rotate → mask):**

- Bit mask/pad (XMASK/RMASK, XPAD/RPAD, XPBIT/RPBIT)
- Rotate right by 0–28 bits in steps of 4 (XROT/RROT)
- Bit reversal (XRVRS/RRVRS): 0=LSB first, 1=MSB first

**Transmit data alignment (XFMT fields XROT, XRVRS; WORD/SLOT are multiples of 4):**

| Order     | Alignment | Representation | XROT                  | XRVRS |
| --------- | --------- | -------------- | --------------------- | ----- |
| MSB first | Left      | Q31            | 0                     | 1     |
| MSB first | Right     | Q31            | SLOT - WORD           | 1     |
| LSB first | Left      | Q31            | 32 - WORD             | 0     |
| LSB first | Right     | Q31            | 32 - SLOT             | 0     |
| MSB first | Left      | Integer        | WORD                  | 1     |
| MSB first | Right     | Integer        | SLOT                  | 1     |
| LSB first | Left      | Integer        | 0                     | 0     |
| LSB first | Right     | Integer        | (32-(SLOT-WORD)) % 32 | 0     |

> For I2S format: MSB first, left aligned, XDATDLY=01.

### Error Handling

| Error         | Flag     | Register | Condition                                           |
| ------------- | -------- | -------- | --------------------------------------------------- |
| TX underrun   | XUNDRN   | XSTAT    | XRBUF not written before transfer to XRSR           |
| RX overrun    | ROVRN    | RSTAT    | XRBUF not read before new data arrives from XRSR    |
| TX DMA err    | XDMAERR  | XSTAT    | CPU/DMA wrote more words than active TX serializers |
| RX DMA err    | RDMAERR  | RSTAT    | CPU/DMA read more words than active RX serializers  |
| TX frame sync | XSYNCERR | XSTAT    | Unexpected TX frame sync detected                   |
| RX frame sync | RSYNCERR | RSTAT    | Unexpected RX frame sync detected                   |
| TX clk fail   | XCKFAIL  | XSTAT    | AHCLKX count outside [XMIN, XMAX] after 32 cycles   |
| RX clk fail   | RCKFAIL  | RSTAT    | AHCLKR count outside [RMIN, RMAX] after 32 cycles   |

**Clock failure startup procedure** (transmit example):

1. Configure XMIN, XMAX, XPS in XCLKCHK.
2. Clear XCKFAIL in XSTAT.
3. Wait >32 AHCLKX cycles for first measurement.
4. Verify no error; repeat steps 2–3 until stable.
5. Then enable: XCKFAIL interrupt (XINTCTL), autoswitch (XCKFAILSW in XCLKCHK), mute (XCKFAIL in AMUTE).

**Clock failure autoswitch (DIT mode only):** Sets HCLKXM=1 (internal source), resets clock divider, resets TX section for one serial clock period, then releases TX section. To return to external clock: wait for AHCLKX to stabilize (poll XCNT in XCLKCHK), then follow startup procedure again.

**DIT underrun recovery:** Two BMC zeros (four bit times at 128 × fs) are shifted out. Reset McASP and reinitialize.

**TDM underrun recovery:** Long stream of zeros is shifted out (DACs mute). Reset McASP and reinitialize.

### Audio FIFO (AFIFO)

Contains Write FIFO (WFIFO) and Read FIFO (RFIFO). Both disabled by default. Must be enabled **before** McASP is taken out of reset.

- **WFIFO:** Upon TX DMA event from McASP, writes WNUMDMA words to McASP when FIFO has ≥ WNUMDMA words. TX DMA event to host generated when FIFO has space for ≥ WNUMEVT words.
- **RFIFO:** Upon RX DMA event from McASP, reads RNUMDMA words from McASP. RX DMA event to host generated when FIFO contains ≥ RNUMEVT words.
- WNUMEVT and RNUMEVT must be non-zero integer multiples of WNUMDMA/RNUMDMA respectively.
- When both FIFOs enabled and simultaneous TX/RX DMA request: TX has priority.

### DIT Channel Status and User Data Registers

Not double-buffered. Use last-slot interrupt to synchronize updates. Software must not write the word currently being encoded.

| Register group    | Content                                      |
| ----------------- | -------------------------------------------- |
| DITCSRA0–DITCSRA5 | 192 bits channel status, LEFT (even) channel |
| DITCSRB0–DITCSRB5 | 192 bits channel status, RIGHT (odd) channel |
| DITUDRA0–DITUDRA5 | 192 bits user data, LEFT (even) channel      |
| DITUDRB0–DITUDRB5 | 192 bits user data, RIGHT (odd) channel      |

Each register covers 32 frames (frames 0–31 in DITCSRA0, frames 32–63 in DITCSRA1, etc.).

### Processor Service Time

```
Processor Service Time = Time Slot − AXEVT/AREVT Latency − Setup Time
```

- AXEVT/AREVT Latency = 5 McASP system clocks
- Setup Time = 3 McASP system clocks + 4 ACLKX/ACLKR cycles

**Example (I2S at 192 kHz, 32-bit slot, system clock = 26 MHz):**

- ACLKX cycle = (1/192kHz)/64 = 81.4 ns
- Time Slot = (1/192kHz)/2 = 2604 ns
- Latency = 5 × 38.5 ns = 192.5 ns
- Setup Time = (3 × 38.5) + (4 × 81.4) = 441.1 ns
- **Service Time = 1970.4 ns**

### Loopback Mode (Digital Loopback, TDM only)

- Enabled by DLBEN=1, MODE=01b in DLBCTL.
- ORD=0: Odd serializers TX → Even serializers RX.
- ORD=1: Even serializers TX → Odd serializers RX.
- ASYNC must be 0; RMOD/XMOD must be 2h–20h (TDM mode).

### EDMA Events

| Event           | Description                                       |
| --------------- | ------------------------------------------------- |
| AXEVT / AREVT   | Single TX/RX DMA event per time slot (Scenario 1) |
| AXEVTE / AREVTE | Even-slot TX/RX DMA event (Scenario 2)            |
| AXEVTO / AREVTO | Odd-slot TX/RX DMA event (Scenario 2)             |

Do not use AXEVT together with AXEVTO/AXEVTE simultaneously.

---

## Initialization Sequence

1. Set GBLCTL = 0 (full reset).
2. Configure all registers (except GBLCTL) in this order:
   a. PWRIDLESYSCONFIG
   b. RX registers: RMASK, RFMT, AFSRCTL, ACLKRCTL, AHCLKRCTL, RTDM, RINTCTL, RCLKCHK
   c. TX registers: XMASK, XFMT, AFSXCTL, ACLKXCTL, AHCLKXCTL, XTDM, XINTCTL, XCLKCHK
   d. Serializer registers: SRCTL[n]
   e. Global registers: PFUNC, PDIR, DITCTL, DLBCTL, AMUTE
   > Set PDIR only after configuring clocks/frame sync — clock pins begin toggling immediately upon PDIR output enable.
   > f. DIT registers (if DIT mode): DITCSRA[n], DITCSRB[n], DITUDRA[n], DITUDRB[n]
3. Start AHCLKX/AHCLKR: Set XHCLKRST/RHCLKRST in GBLCTL; read back to verify latched.
4. Start ACLKX/ACLKR (if internal): Set XCLKRST/RCLKRST in GBLCTL; read back to verify.
5. Set up DMA/interrupts/polling.
6. Activate serializers: Clear XSTAT=FFFFh / RSTAT=FFFFh, set XSRCLR/RSRCLR in GBLCTL; read back.
7. Pre-load TX buffers (if transmitting): Wait until XDATA=0 in XSTAT.
8. Release state machines: Set XSMRST/RSMRST in GBLCTL; read back.
9. Release frame sync generators: Set XFRST/RFRST in GBLCTL; read back.
10. McASP begins on first frame sync edge.

> **Critical:** After each GBLCTL write, always read back until the written bits are verified latched. This takes approximately 2 bit clocks + 2 bus clocks. The McASP state machines run off bit clocks, which are much slower than the processor bus clock.

> **Separate TX/RX init:** Use XGBLCTL (TX bits 12–8, read-only for RX) and RGBLCTL (RX bits 4–0, read-only for TX) for independent control.

> **Synchronous mode (ASYNC=0):** Receiver uses TX clock and TX frame sync. AFSR must not be used as output. Common requirements: DITEN=0, RSSZ × RMOD = XSSZ × XMOD, FSXM must match FSRM, FXWID must match FRWID.

> **Emulation note:** Do not access RBUFn/XBUFn registers while McASP is running — this updates RRDY/XRDY in SRCTLn. McASP does not support emulation suspend.

---

## Register Map Summary

| Offset    | Acronym          | Register Name                                |
| --------- | ---------------- | -------------------------------------------- |
| 0h        | REV              | Revision Identification [reset=44307B02h]    |
| 4h        | PWRIDLESYSCONFIG | Power Idle SYSCONFIG [reset=2h]              |
| 10h       | PFUNC            | Pin Function (McASP=0h, GPIO=1h per bit)     |
| 14h       | PDIR             | Pin Direction (Input=0, Output=1)            |
| 18h       | PDOUT            | Pin Data Output                              |
| 1Ch       | PDIN             | Pin Data Input                               |
| 20h       | PDCLR            | Pin Data Clear (alias of PDOUT)              |
| 44h       | GBLCTL           | Global Control [reset=0h]                    |
| 48h       | AMUTE            | Audio Mute Control [reset=0h]                |
| 4Ch       | DLBCTL           | Digital Loopback Control [reset=0h]          |
| 50h       | DITCTL           | DIT Mode Control [reset=0h]                  |
| 60h       | RGBLCTL          | Receiver Global Control (alias of GBLCTL)    |
| 64h       | RMASK            | Receive Format Bit Mask [reset=0h]           |
| 68h       | RFMT             | Receive Bit Stream Format [reset=0h]         |
| 6Ch       | AFSRCTL          | Receive Frame Sync Control [reset=0h]        |
| 70h       | ACLKRCTL         | Receive Clock Control [reset=0h]             |
| 74h       | AHCLKRCTL        | Receive High-Freq Clock Control [reset=0h]   |
| 78h       | RTDM             | Receive TDM Time Slot 0–31 [reset=0h]        |
| 7Ch       | RINTCTL          | Receiver Interrupt Control [reset=0h]        |
| 80h       | RSTAT            | Receiver Status [reset=0h]                   |
| 84h       | RSLOT            | Current Receive TDM Time Slot [reset=0h]     |
| 88h       | RCLKCHK          | Receive Clock Check Control [reset=0h]       |
| 8Ch       | REVTCTL          | Receiver DMA Event Control [reset=0h]        |
| A0h       | XGBLCTL          | Transmitter Global Control (alias of GBLCTL) |
| A4h       | XMASK            | Transmit Format Bit Mask [reset=0h]          |
| A8h       | XFMT             | Transmit Bit Stream Format [reset=0h]        |
| ACh       | AFSXCTL          | Transmit Frame Sync Control [reset=0h]       |
| B0h       | ACLKXCTL         | Transmit Clock Control [reset=60h]           |
| B4h       | AHCLKXCTL        | Transmit High-Freq Clock Control [reset=0h]  |
| B8h       | XTDM             | Transmit TDM Time Slot 0–31 [reset=0h]       |
| BCh       | XINTCTL          | Transmitter Interrupt Control [reset=0h]     |
| C0h       | XSTAT            | Transmitter Status [reset=0h]                |
| C4h       | XSLOT            | Current Transmit TDM Time Slot [reset=0h]    |
| C8h       | XCLKCHK          | Transmit Clock Check Control [reset=0h]      |
| CCh       | XEVTCTL          | Transmitter DMA Event Control [reset=0h]     |
| 100h–114h | DITCSRA_0–5      | Left Channel Status (DIT) [reset=0h]         |
| 118h–12Ch | DITCSRB_0–5      | Right Channel Status (DIT) [reset=0h]        |
| 130h–144h | DITUDRA_0–5      | Left Channel User Data (DIT) [reset=0h]      |
| 148h–15Ch | DITUDRB_0–5      | Right Channel User Data (DIT) [reset=0h]     |
| 180h–194h | SRCTL_0–5        | Serializer Control [reset=0h]                |
| 200h–214h | XBUF_0–5         | Transmit Buffer for Serializers [reset=0h]   |
| 280h–294h | RBUF_0–5         | Receive Buffer for Serializers [reset=0h]    |
| 1000h     | WFIFOCTL         | Write FIFO Control [reset=0h]                |
| 1004h     | WFIFOSTS         | Write FIFO Status [reset=0h]                 |
| 1008h     | RFIFOCTL         | Read FIFO Control [reset=0h]                 |
| 100Ch     | RFIFOSTS         | Read FIFO Status [reset=0h]                  |

### Key Register Fields

**GBLCTL (offset=44h):** Bits synchronized to ACLKX (bits 12–8) and ACLKR (bits 4–0).

| Bits | Field    | Function                                           |
| ---- | -------- | -------------------------------------------------- |
| 12   | XFRST    | TX frame sync generator enable (0=reset, 1=active) |
| 11   | XSMRST   | TX state machine enable                            |
| 10   | XSRCLR   | TX serializers enable                              |
| 9    | XHCLKRST | TX high-freq clock divider enable                  |
| 8    | XCLKRST  | TX clock divider enable                            |
| 4    | RFRST    | RX frame sync generator enable                     |
| 3    | RSMRST   | RX state machine enable                            |
| 2    | RSRCLR   | RX serializers enable                              |
| 1    | RHCLKRST | RX high-freq clock divider enable                  |
| 0    | RCLKRST  | RX clock divider enable                            |

**ACLKXCTL (offset=B0h, reset=60h):**

| Bits | Field   | Function                                                  |
| ---- | ------- | --------------------------------------------------------- |
| 7    | CLKXP   | TX clock polarity (0=rising edge, 1=falling edge)         |
| 6    | ASYNC   | 0=sync TX/RX, 1=async TX/RX (default=1)                   |
| 5    | CLKXM   | TX clock source (0=external ACLKX, 1=internal; default=1) |
| 4–0  | CLKXDIV | Divide ratio AHCLKX→ACLKX (0=÷1, 1=÷2, …, 1Fh=÷32)        |

**SRCTL_n (offset=180h+4n):**

| Bits | Field  | Function                                              |
| ---- | ------ | ----------------------------------------------------- |
| 5    | RRDY   | RX buffer ready (read-only)                           |
| 4    | XRDY   | TX buffer ready (read-only)                           |
| 3–2  | DISMOD | Drive on pin when inactive (0=3-state, 2=low, 3=high) |
| 1–0  | SRMOD  | Serializer mode (0=inactive, 1=TX, 2=RX)              |

**WFIFOCTL (offset=1000h):**

| Bits | Field   | Function                                                   |
| ---- | ------- | ---------------------------------------------------------- |
| 16   | WENA    | Write FIFO enable (must be set before McASP reset release) |
| 15–8 | WNUMEVT | Words threshold to generate AXEVT to host (×WNUMDMA)       |
| 7–0  | WNUMDMA | Words per TX DMA transfer (= number of TX serializers)     |

**Suspend Control Registers (Chapter 27 DRM, offset 234h for eHRPWM-0):**

Normal mode: write 0x0. Suspend during debug halt: write 0x9.
