---
title: AM335x Chapter 16 — Universal Serial Bus (USB)
tags:
  - am335x
  - usb
  - otg
  - cppi
  - reference
source: "AM335x TRM Chapter 16"
---

# 16 Universal Serial Bus (USB)

## 16.1 Introduction

The AM335x USB subsystem (USBSS) contains **two independent USB 2.0 OTG modules** (USB0, USB1), each built around the Mentor USB OTG controller (musbmhdrc) with integrated TI PHY. Both modules have identical capabilities and operate independently.

### 16.1.1 Features

| Feature | Detail |
|---------|--------|
| USB speeds (peripheral) | HS (480 Mb/s), FS (12 Mb/s) |
| USB speeds (host/OTG) | HS (480 Mb/s), FS (12 Mb/s), LS (1.5 Mb/s) |
| Transfer types | Control, Bulk, Interrupt, Isochronous (including high-bandwidth ISO) |
| Endpoints | 16 TX + 16 RX per module (EP0 + EP1–15) |
| Endpoint FIFO | 32 KB configurable RAM per module |
| OTG support | HNP (Host Negotiation Protocol) + SRP (Session Resume Protocol) |
| DMA | CPPI 4.1 DMA shared by both modules; 15 TX + 15 RX channels per USB module |
| Queue Manager | 156 queues shared across both modules |
| DMA modes | Transparent, RNDIS, Generic RNDIS, Linux CDC |
| RNDIS / CDC | Short-packet termination acceleration |
| Max buffer size | Up to 4 MBytes per descriptor |
| OCP interfaces | 2 Master OCP HP (DMA + QM) + 1 Slave OCP MMR |

### 16.1.2 Unsupported Features

| Feature | Status |
|---------|--------|
| USBOTG charger-detect circuitry | Not supported |
| USB 2.0 ECN Link Power Management (LPM) | Not supported |

---

## 16.2 Integration

```
┌─────────────────────────────────────────────────┐
│                  USB Subsystem (USBSS)           │
│  ┌──────────────┐  ┌─────┐   USB0_DP / USB0_DM  │
│  │ USB0 (musbm) ├──┤ PHY ├── USB0_DRVVBUS       │
│  └──────┬───────┘  └─────┘   USB0_VBUS / ID / CE│
│         │ usb_fifo0 / usbslv0                   │
│  ┌──────────────┐  ┌─────┐   USB1_DP / USB1_DM  │
│  │ USB1 (musbm) ├──┤ PHY ├── USB1_DRVVBUS       │
│  └──────┬───────┘  └─────┘   USB1_VBUS / ID / CE│
│         │ usb_fifo1 / usbslv1                   │
│  ┌──────────────┐ ┌─────────┐ ┌──────────────┐  │
│  │ CPPI 4.1 DMA ├─┤ DMA Sch ├─┤ Queue Manager│  │
│  └──────────────┘ └─────────┘ └──────────────┘  │
│  SCR / OCP bridge: SLV + m_vbusp + mmr          │
└─────────────────────────────────────────────────┘
        │
  L3 Slow Interconnect
  Interrupts: usbss_intr, usb0_intr, usb1_intr, slv0p_Swakeup
  Wakeup to WakeM3: usb0_wuout, usb1_wuout
```

### 16.2.1 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | PD_PER_L3S_GCLK (OCP), CLKDCOLDO (PHY) |
| Reset | DEF_DOM_RST_N, USB_POR_N |
| Idle/Wakeup | Smart Idle, Wakeup, Standby |
| Interrupts | usbss (USBSSINT) → MPU; usb0 (USBINT0) → MPU; usb1 (USBINT1) → MPU; slv0p_Swakeup (USBWAKEUP) → MPU + WakeM3 |
| Wakeup events | usb0_wuout, usb1_wuout → WakeM3 |
| DMA | None (CPPI DMA is internal to USBSS) |
| Physical Address | L3 Slow slave port |

### 16.2.2 Clock Signals

| Clock | Max Freq | Source | Domain |
|-------|----------|--------|--------|
| ocp_clk (OCP/Functional) | 100 MHz | CORE_CLKOUTM4 / 2 | pd_per_l3s_gclk |
| phy0_other_refclk960m (PHY0 ref) | 960 MHz | CLKDCOLDO | clkdcoldo_po / Per PLL |
| phy1_other_refclk960m (PHY1 ref) | 960 MHz | CLKDCOLDO | clkdcoldo_po / Per PLL |

UTMI clock: fixed 60 MHz (8-bit interface, 480 Mb/s). PHY requires low-jitter 960 MHz source.

### 16.2.3 Pin List

| Pin | Type | Description |
|-----|------|-------------|
| USBx_DP | Analog I/O (GPIO Digital I/O) | USB data differential DP |
| USBx_DM | Analog I/O (GPIO Digital I/O) | USB data differential DM |
| USBx_DRVVBUS | Digital output | VBUS supply control (high=host mode, external charge pump enable) |
| USBx_VBUS | Analog input | VBUS voltage sensing (input only) |
| USBx_ID | Analog input | OTG ID pin (float=device, GND=host) |
| USBx_CE | Digital output | PHY charge enable |

> [!NOTE]
> USBx_DP / USBx_DM: analog in USB mode, CMOS in GPIO mode. GPIO mode supports UART-over-USB (UART2/USB0, UART3/USB1), controlled by USB_CTRL0/1[GPIOMODE, GPIO_SIG_CROSS, GPIO_SIG_INV] in the Control Module.

---

## 16.3 Functional Description

### 16.3.1 Endpoint FIFO

- **Total FIFO RAM**: 32 KB per module
- **EP0 FIFO**: Fixed 64 bytes at FIFO offset 0–63; not configurable by software
- **EP1–15 FIFO**: Software allocates start address + max packet size (min 8 bytes; 1 or 2 packet buffering)
- **Shared TX/RX**: A TX endpoint and same-numbered RX endpoint can share one FIFO (if never simultaneously active)
- FIFO configuration registers are **indexed-only** (via INDEX register); no direct non-indexed access

### 16.3.2 Indexed vs. Non-Indexed Register Access

| Space | USB0 Offset Range | USB1 Offset Range | Access Method |
|-------|------------------|------------------|---------------|
| Indexed EP 0–15 | 1410h–141Fh | 1C10h–1C1Fh | Set INDEX register (140Eh / 1C0Eh) first |
| Non-indexed EP 0 | 1500h–150Fh | 1D00h–1D0Fh | Direct |
| Non-indexed EP 1–15 | 1510h–16FFh | 1D10h–1DFFh | Direct (16 bytes per endpoint) |

### 16.3.3 Role Assumption (Host / Device)

**Hardware option:** Cable connector type — A-side = host, B-side = device

**Software option:** Set `USBnMODE[IDDIG_MUX=bit7]=1`; then:
- `MODE[IDDIG=bit8]=0` → Host
- `MODE[IDDIG=bit8]=1` → Device (peripheral)

USB0 MODE Register: offset **10E8h** | USB1 MODE Register: offset **18E8h**

**Session flow:**
1. DEVCTL[SESSION] set (VBUS ≥ 4.4V or firmware-set)
2. Controller reads iddig → low=host, high=device
3. Host: drives DRVVBUS high, waits for VBUS valid (≥4.4V); after 100 ms timeout → VBUS error interrupt
4. Device: POWER[SOFTCONN=bit6] must be set; pulls D+ high (FS), negotiates HS during reset

### 16.3.4 VBUS Control

- Host role: DRVVBUS high → enable external charge pump (VBUS should be 4.75V to account for cable drop; must be ≥4.4V)
- Device role: DRVVBUS low; VBUS from external host
- Both modules are self-powered; VBUS used only for role detection and D+ pullup power

### 16.3.5 Unbonded PHY Handling (13×13 Package)

If only one PHY is bonded out, the unbonded PHY must be:
1. USB Controller → Host mode: set USB Core DEVCTL[bit2]=1
2. PHY → SUSPEND: set USB Core POWER[bits 1:0]
3. Control Module USB_CTRLx: CHGDET_DIS=1, CM_PWRDN=1, GPIOMODE=0

### 16.3.6 Peripheral Mode Key Registers

| Register | Bit | Description |
|----------|-----|-------------|
| POWER | 6 (SOFTCONN) | 0=disconnected; 1=D+ pullup active (connect to host) |
| POWER | 5 (HSENA) | 1=negotiate HS operation during reset |
| POWER | 4 (HSMODE) | Read-only; 1=operating at HS |
| POWER | 0 (RESUME) | Set 1 for 2–15 ms to initiate remote wakeup |
| PERI_CSR0 | 6 (SERV_RXPKTRDY) | W1 to ACK setup packet read from EP0 FIFO |
| PERI_CSR0 | 5 (SENDSTALL) | W1 to STALL the current control request |
| PERI_CSR0 | 3 (DATAEND) | Set with SERV_RXPKTRDY to indicate no more data expected |
| PERI_CSR0 | 1 (TXPKTRDY) | W1 to indicate EP0 TX FIFO ready to send |
| FADDR | 6:0 | Device address (set after SET_ADDRESS status stage completes) |

> [!NOTE]
> DMA is **not** supported for EP0. EP0 is always serviced via CPU. CPPI DMA only handles EP1–EP15.

---

## 16.4 CPPI 4.1 DMA

### 16.4.1 Architecture Overview

```
Main Memory ◄──► CPPI DMA (CDMA) ◄──► CPPI FIFO (64-byte blocks) ◄──► XDMA ◄──► Endpoint FIFOs ◄──► USB Bus
                       ▲
               Queue Manager (QM)
                       ▲
              CPPI DMA Scheduler (CDMAS)
```

| Component | Description |
|-----------|-------------|
| CPPI DMA (CDMA) | 15 TX + 15 RX channels per USB module; ports 1–15 map to EP1–EP15 |
| XDMA (Transfer DMA) | Moves data between CPPI FIFO and Endpoint FIFOs; generates TxPktRdy |
| Queue Manager (QM) | 156 total queues; manages linked lists of descriptors |
| CPPI Scheduler | Controls TX/RX channel ordering and bandwidth; up to 256-entry table |

### 16.4.2 DMA Channel-to-Endpoint Mapping

| CPPI Port | USB Endpoint |
|-----------|-------------|
| Port 1 | EP1 |
| Port 2 | EP2 |
| … | … |
| Port 15 | EP15 |
| Port 0 (EP0) | **CPU only — no DMA** |

### 16.4.3 Queue Assignment (156 queues total)

| Queue Range | Count | Purpose |
|-------------|-------|---------|
| 0–31 | 32 | Free Descriptor/RX Submit Queues (shared by all USB0/1 RX endpoints) |
| 32–61 | 30 | USB0 TX Endpoint 1–15 Submit Queues (2 per endpoint) |
| 62–91 | 30 | USB1 TX Endpoint 1–15 Submit Queues (2 per endpoint) |
| 92 | 1 | Reserved |
| 93–107 | 15 | USB0 TX EP1–EP15 Completion Queues (1 per endpoint) |
| 108 | 1 | Reserved |
| 109–123 | 15 | USB0 RX EP1–EP15 Completion Queues (1 per endpoint) |
| 124 | 1 | Reserved |
| 125–139 | 15 | USB1 TX EP1–EP15 Completion Queues (1 per endpoint) |
| 140 | 1 | Reserved |
| 141–155 | 15 | USB1 RX EP1–EP15 Completion Queues (1 per endpoint) |

**Quick reference by endpoint N:**

| Queue type | USB0 formula | USB1 formula |
|------------|-------------|-------------|
| TX Submit (2 queues) | 32 + (N−1)×2, 33 + (N−1)×2 | 62 + (N−1)×2, 63 + (N−1)×2 |
| TX Completion | 93 + (N−1) | 125 + (N−1) |
| RX Submit (free desc) | 0–31 (any free) | 0–31 (any free) |
| RX Completion | 109 + (N−1) | 141 + (N−1) |

### 16.4.4 Descriptor Structures

All descriptors must be naturally aligned to the smallest power-of-2 ≥ descriptor size. Minimum descriptor size: **32 bytes** (5 LSBs of descriptor pointer encode length for CPPI 4.1).

#### Host Packet Descriptor (PD / SOP Descriptor) — 32 bytes required

| Word | Bits | Field | Description |
|------|------|-------|-------------|
| PD0 | 31–27 | Descriptor type | 10h = Host Packet Descriptor |
| PD0 | 26–22 | Protocol-specific word count | 0–16 (0=0 bytes, 1=4 bytes, 16=64 bytes; 17–31 reserved) |
| PD0 | 21–0 | Packet length | Total transfer length in bytes (0 to 4M−1); CPU sets for TX; DMA overwrites on RX |
| PD1 | 31–27 | Source Tag: Port # | RX EP number (0–31); DMA overwrites on RX |
| PD1 | 26–21 | Source Tag: Channel # | Always 0 for USB |
| PD1 | 20–16 | Source Tag: Sub-channel # | Always 0 |
| PD1 | 15–0 | Destination Tag | Application-specific; always 0 for USB |
| PD2 | 31 | Packet error | 0=no error, 1=error on reception |
| PD2 | 30–26 | Packet type | 5=USB |
| PD2 | 19 | Zero-length packet | 1=zero-length USB packet |
| PD2 | 15 | Return policy | 0=return whole packet; 1=return each buffer separately |
| PD2 | 14 | On-chip | 1=descriptor in on-chip memory; 0=external |
| PD2 | 13–12 | Return queue mgr # | Must be 0 (only 1 QM) |
| PD2 | 11–0 | Packet return queue # | Queue number for descriptor return after TX complete |
| PD3 | 21–0 | Buffer 0 length | Valid data bytes in buffer; CPU sets TX; DMA overwrites RX |
| PD4 | 31–0 | Buffer 0 pointer | Byte-aligned address of data buffer |
| PD5 | 31–0 | Next descriptor pointer | Next BD address; 0=last descriptor in packet |
| PD6 | 21–0 | Original buffer 0 length | Original allocated buffer size (not overwritten on RX) |
| PD7 | 31–0 | Original buffer 0 pointer | Original buffer address (not overwritten on RX) |

#### Host Buffer Descriptor (BD) — 32 bytes, same layout

Words 0–1 are Reserved. Word 2 contains only: On-chip[14], return queue mgr[13:12], return queue#[11:0]. Words 3–7 same as PD3–PD7. Used for middle/end-of-packet chaining.

#### Teardown Descriptor — 32 bytes

| Field | Bits | Value |
|-------|------|-------|
| Descriptor type | [31:27] | 13h (= 19 decimal) |
| TX_RX | [16] | 0=TX teardown, 1=RX teardown |
| DMA number | [15:10] | DMA controller number |
| Channel number | [5:0] | Channel being torn down |
| Words 1–7 | — | Reserved (pad to 32 bytes) |

### 16.4.5 TX Teardown Procedure

1. Set `TXGCRn[TX_TEARDOWN]` in CPPI DMA TX channel N global config register
2. Write TX EP number to `TEARDOWN[TX_TDOWN]` in USB OTG controller
3. Poll completion queue (`CTRLDn`) for teardown descriptor arrival; retry step 2 until received
4. Write TX EP number again to `TEARDOWN[TX_TDOWN]`
5. Set `PERI_TXCSR[FLUSHFIFO]` for the corresponding endpoint
6. Re-enable TX DMA: clear then set `TXGCRn[TX_ENABLE]`

> [!NOTE]
> RX channel teardown is **not required** for receive transactions; no RX teardown resource exists.

### 16.4.6 DMA Protocol Modes

| Mode | Code (TXn_MODE/RXn_MODE) | Description |
|------|--------------------------|-------------|
| Transparent | 00b | Interrupt per DMA packet; packet ≤ USB MaxPktSize; ideal for small transfers |
| RNDIS | 01b | Large transfers, multiple USB packets of MaxPktSize; EOP = short packet (< MaxPktSize); if exact multiple, awaits zero-byte terminator |
| Linux CDC | 10b | Same as RNDIS except null packet replaced by 1-byte 00h data packet |
| Generic RNDIS | 11b | Like RNDIS, but EOP size is programmed in `USB0/1 GENERIC_RNDIS_EPn_SIZE` register (up to 64 KB); no extra zero-byte needed if last packet = MaxPktSize |

> [!NOTE]
> RNDIS / Generic RNDIS: USB MaxPktSize **must** be an integer multiple of 64 bytes. Global RNDIS enable (`CTRL0/1[RNDIS]=1`) overrides per-endpoint config.

**Global mode selection:** `CTRL0[RNDIS]=1` enables RNDIS globally for all endpoints; `CTRL0[RNDIS]=0` enables per-endpoint mode via TX/RXMODE registers.

### 16.4.7 CPPI DMA Scheduler

Up to **256 table entries** (4 per WORD register, WORD0–WORD63). Each entry = {channel number, TX/RX direction}.

**Initialization:**
1. Write scheduler table (WORD0–WORDn): ENTRY_CHANNEL + ENTRY_RXTX bits
2. Set `DMA_SCHED_CTRL.LAST_ENTRY` = (number of active entries − 1)
3. Enable: set `DMA_SCHED_CTRL.ENABLE`

**Bandwidth allocation:** More entries per channel = proportionally more bandwidth. 256 entries → 1/256 precision.

**Example (equal priority, EP1-TX + EP2-TX + EP2-RX):**
- WORD0: ENTRY0={ch=1, TX}, ENTRY1={ch=2, TX}, ENTRY2={ch=2, RX}
- LAST_ENTRY = 2

### 16.4.8 Linking RAM (Queue Manager)

QM uses external Linking RAM to track descriptor ordering within queues:
- Minimum Linking RAM size: **4 bytes × total descriptor count**
- Up to **16 memory regions** of descriptors (homogeneous size per region)
- Up to **64K descriptors total** across all regions
- Configure via: Linking RAM0 base, Linking RAM0 size (descriptor count), Linking RAM1 base (optional)

### 16.4.9 Zero-Length Packets

- RX: XDMA sends CDMA a block with byte count = 0 and `PD2[19]=1` (zero-length indicator); CDMA performs normal EOP without data transfer
- TX: If CPPI packet has `PD2[19]=1`, XDMA ignores packet size and sends zero-length USB packet to controller

---

## 16.5 Software Operation

### 16.5.1 Initialization Sequence (Before USB Operation)

1. **PRCM**: Enable USBSS clocks; de-assert resets (see PRCM chapter)
2. **Control Module**: Configure USB PHY (CM_PWRDN, ISO_SCAN_BYPASS, CHGDET_DIS etc.)
3. **USB_CTRLx**: Configure GPIO/UART-over-USB mode if needed
4. **USBSS SYSCONFIG**: Set IDLEMODE / STANDBYMODE
5. **Linking RAM**: Initialize QM memory regions, linking RAM0 base + size, linking RAM1 base
6. **Queue Manager**: Configure queues (push free buffer descriptors to RX Submit Queues)
7. **CPPI DMA Scheduler**: Initialize table entries; set LAST_ENTRY; enable
8. **USB Mode Register** (`10E8h`/`18E8h`): Set IDDIG_MUX + IDDIG for SW role control
9. **POWER[SOFTCONN]**: Set when ready to connect as device; or DEVCTL[SESSION] if host

### 16.5.2 TX Data Flow (DMA, example 608-byte transfer on USB0 EP1)

1. CPU allocates: 1 PD (256-byte buffer) + 2 BDs (256+96 bytes) in main memory; set PD packet length = 608
2. CPU pushes PD address to **TXSQ** (Queue 32 or 33 for USB0 EP1) via QM CTRL D register
3. CDMAS sees TXSQ non-empty → issues TX credit to CDMA
4. CDMA transfers 64-byte bursts from main memory → CPPI FIFO; XDMA drains CPPI FIFO → Endpoint FIFO
5. Once Endpoint FIFO accumulates 512 bytes → XDMA sets `TXPKTRDY`
6. Mentor USB core sends USB packet on IN token from host
7. Repeats until all 608 bytes transmitted (2 full 512-byte USB packets would not fit; actual USB MaxPktSize determines packet count)
8. CDMA posts PD pointer to **TXCQ** (Queue 93 for USB0 EP1); QM interrupts CPU

### 16.5.3 RX Data Flow (DMA, example 608-byte receive on USB0 EP1)

1. CPU allocates BDs + data buffers (256+256+96 bytes); pre-links BD chain
2. CPU pushes BD addresses to **RXSQ** (Queue 0 for USB0 EP1) via QM CTRL D register
3. USB host sends USB OUT packets; Mentor USB core stores in Endpoint FIFO; asserts DMA_req to XDMA
4. XDMA transfers 64-byte blocks from Endpoint FIFO → CPPI FIFO
5. CDMA fetches BD from RXSQ; transfers data from CPPI FIFO → data buffer in main memory
6. After EOP: CDMA posts PD to **RXCQ** (Queue 109 for USB0 EP1); QM interrupts CPU

---

## 16.6 Register Address Map

Base address: **USBSS_BASE = 0x47400000**

### 16.6.1 Address Space Overview

| Offset Range | Space | Description |
|-------------|-------|-------------|
| 0h–3FFh | USBSS | Subsystem registers (IRQ aggregator, DMA IPC) |
| 1000h–1FFFh | USB0_CTRL | USB0 wrapper: IRQ, TXMODE, RXMODE, TEARDOWN |
| 1400h–17FFh | USB0 Core (indexed) | Mentor USB core registers (USB0) |
| 1500h–16FFh | USB0 Core (non-indexed EP0–15) | Direct endpoint registers |
| 1800h–1FFFh | USB0 PHY | USB0 PHY/UTMI registers |
| 5000h–5FFFh | CPPI DMA | DMA channel config, scheduler |
| 6000h–7FFFh | Queue Manager | QM control, region config, linking RAM config |
| 8000h–9FFFh | Queue Manager Data | CTRL D / status registers per queue |
| 9000h–BFFFh | USB1 (same layout as USB0, offset +8000h) | USB1 mirror |

**USB1 offset shift:** All USB0 registers at offset X have USB1 equivalents at X + 0x800 within the USBSS address space.
- USB0 Mode: offset **10E8h**
- USB1 Mode: offset **18E8h**

### 16.6.2 Key USBSS Registers (Base = 0x47400000)

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | REVREG | 4EA20800h | IP revision |
| 10h | SYSCONFIG | 28h | IDLEMODE[4:3], STANDBYMODE[6:5], AUTOIDLE[0] |
| 24h | IRQSTATRAW | 0h | Raw IRQ status (USB0/1 aggregated; W1 sets) |
| 28h | IRQSTAT | 0h | Masked IRQ status; W1 clears |
| 2Ch | IRQENABLER | 0h | W1 enables interrupt |
| 30h | IRQCLEARR | 0h | W1 disables interrupt |
| 100h–13Ch | IRQDMAHOLDTXnn/RXnn | 0h | DMA interrupt pacing threshold registers (TX/RX per USB module) |
| 140h | IRQDMAENABLE0 | 0h | DMA interrupt enable (USB0 TX EP1–15, RX EP1–15) |
| 144h | IRQDMAENABLE1 | 0h | DMA interrupt enable (USB1 TX EP1–15, RX EP1–15) |
| 200h–23Ch | IRQFRAMEHOLDTXnn/RXnn | 0h | Frame interrupt pacing threshold registers |
| 240h | IRQFRAMEENABLE0 | 0h | Frame interrupt enable (USB0) |
| 244h | IRQFRAMEENABLE1 | 0h | Frame interrupt enable (USB1) |

### 16.6.3 Key USB0_CTRL Registers (Base = 0x47400000)

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 1000h | USB0REV | 4EA20800h | USB0 wrapper revision |
| 1014h | USB0CTRL | 0h | USB0 control: RNDIS[16], PHYREF[1] |
| 1018h | USB0STAT | 0h | USB0 status: RXFIFO_EMPTY, TXFIFO_FULL (read-only) |
| 1020h | USB0IRQMSTAT | 0h | USB0 merged masking status |
| 1028h | USB0IRQSTATRAW0 | 0h | Raw IRQ0 status (EP RX interrupt bits; W1 sets) |
| 102Ch | USB0IRQSTATRAW1 | 0h | Raw IRQ1 status (EP TX, SOF, VBUS error; W1 sets) |
| 1030h | USB0IRQSTAT0 | 0h | Masked IRQ0; W1 clears |
| 1034h | USB0IRQSTAT1 | 0h | Masked IRQ1; W1 clears |
| 1038h | USB0IRQENABLESET0 | 0h | Enable IRQ0 (W1 to set) |
| 103Ch | USB0IRQENABLESET1 | 0h | Enable IRQ1 (W1 to set) |
| 1040h | USB0IRQENABLECLR0 | 0h | Disable IRQ0 (W1 to clear) |
| 1044h | USB0IRQENABLECLR1 | 0h | Disable IRQ1 (W1 to clear) |
| 1070h | USB0TXMODE | 0h | TX DMA mode per endpoint: TXn_MODE[1:0] for EP1–15 (00=Transparent, 01=RNDIS, 10=CDC, 11=GenRNDIS) |
| 1074h | USB0RXMODE | 0h | RX DMA mode per endpoint: same encoding as TXMODE |
| 1080h–10BCh | USB0GENRNDISEP1–15 | 0h | Generic RNDIS EP transfer size registers (16-bit, EP1 at 1080h; +4 per EP) |
| 10E8h | USB0MODE | 0h | IDDIG_MUX[7], IDDIG[8]: role control |
| 10ECh | USB0TEARDOWN | 0h | TX_TDOWN[15:1] / RX_TDOWN[31:17]: initiate channel teardown |

> [!NOTE]
> For USB1, all USB0_CTRL register offsets above have USB1 equivalents at +0x800 (e.g., USB1CTRL at 1814h, USB1MODE at 18E8h, USB1TEARDOWN at 18ECh).

---

## 16.7 Supported Use Cases

| Use Case | Description |
|----------|-------------|
| Single peripheral | USB0 or USB1 as FS/HS device attached to a conventional PC host |
| Single host | USB0 or USB1 as HS/FS/LS host to one peripheral (point-to-point) |
| Hub host | USB0 or USB1 as host driving multiple peripherals through a hub |
| Dual independent | USB0 as host, USB1 as device (or vice versa) simultaneously |
| UART over USB | GPIO mode on DP/DM provides UART2/UART3 over USB0/USB1 respectively |

---

## 16.8 Initialization Checklist

> [!IMPORTANT]
> PHY initialization and clock configuration must be done before writing any USB module registers. Refer to PRCM chapter for clock enable sequence and Control Module chapter for PHY configuration registers.

| Step | Action |
|------|--------|
| 1 | PRCM: enable USBSS clocks; de-assert USB_POR_N + DEF_DOM_RST_N |
| 2 | Control Module: configure PHY (CM_PWRDN=0, CHGDET_DIS, ISO_SCAN_BYPASS) |
| 3 | Wait PHY PLL lock |
| 4 | USBSS SYSCONFIG: set IDLEMODE=Smart-Idle, STANDBYMODE=Smart-Standby |
| 5 | Allocate Linking RAM and descriptor memory regions; write to QM region configuration registers |
| 6 | Initialize free buffer descriptors; push to RX Submit Queues (0–31) |
| 7 | Configure CPPI DMA channels (TXGCRn / RXGCRn): enable channels |
| 8 | Configure DMA scheduler table (WORDn entries + LAST_ENTRY); enable scheduler |
| 9 | Set USB0/1TXMODE / RXMODE per endpoint DMA protocol |
| 10 | For device: set POWER[HSENA] if HS desired; set POWER[SOFTCONN] to connect |
| 11 | For host: set DEVCTL[SESSION]; set MODE[IDDIG_MUX=1, IDDIG=0] for SW host override |
| 12 | Enable interrupts: IRQENABLESET0/1 for desired endpoints; enable USBSS IRQ in INTC |
