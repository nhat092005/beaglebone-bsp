---
title: AM335x Chapter 14 — Ethernet Subsystem (CPSW_3GSS)
tags:
  - am335x
  - ethernet
  - cpsw
  - mdio
  - reference
source: "AM335x TRM Chapter 14"
---

# 14 Ethernet Subsystem (CPSW_3GSS)

## 14.1 Introduction

The Communication Port Switch and Gigabit Subsystem (CPSW_3GSS) is a 3-port Ethernet switch: one host port (Port 0, CPPI) + two slave MAC ports (Port 1, Port 2) with GMII/MII/RGMII/RMII interfaces.

### 14.1.1 Features

| Feature | Value |
|---------|-------|
| Ports | 3 (Port 0 = host CPPI, Port 1/2 = external MACs) |
| Wire-rate switching | 802.1d compliant |
| Non-blocking fabric | Yes |
| QOS | 4 priority levels (802.1p) |
| DMA | CPPI 3.1 (internal CPPI descriptor memory 8K bytes = 2048×32) |
| ALE | 1024 addresses + VLANs, wire-rate lookup |
| ALE capabilities | VLAN, spanning tree, MAC auth (802.1x), Multicast/Broadcast limits, MAC block, source port lock, OUI accept/deny, L2 filter |
| CPTS | IEEE 1588v2 (Annex D and Annex F), DLR support |
| Statistics | EtherStats + 802.3Stats RMON (shared) |
| Flow Control | IEEE 802.3x pause frames |
| Max Frame Size | 2016 bytes standard; 2020 bytes with VLAN |
| MDIO | 32 PHY addresses, Clause 22 and 45 |
| Loopback | CPGMAC_SL TX→RX (digital) and RX→TX (FIFO) loopback |
| Emulation | Emulation support |
| IPG | Programmable transmit inter-packet gap |
| Interrupt pacing | Per interrupt pacing for RX/TX pulse interrupts |

### 14.1.2 Unsupported Features

> [!CAUTION]
> The following features are **not available** on this device. Failure to account for these leads to hardware bringup failures.

| Feature | Reason / Impact |
|---------|----------------|
| Multi-core split processing | Core 1 and Core 2 interrupts not connected; only C0 (Cortex-A8 / PRU-ICSS) |
| GMII (full 8-bit) | Only 4 Rx/Tx data pins bonded out per port. **Only MII (on GMII interface), RGMII, and RMII are usable** |
| PHY link status (MLINK) | MLINK inputs not pinned out. Use GPIO-connected PHY link status outputs instead |
| RGMII Internal Delay mode | Not supported. PHY or external delay line required |
| RMII reference clock output | RMII refclk output does not satisfy input requirements of RMII PHYs. Must use PHY-supplied 50 MHz clock |
| Reset isolation | Silicon bug — see AM335x Silicon Errata SPRZ360 |

**Interrupt architecture**: 18 CPGMAC + 2 MDIO level interrupts are combined to 4 interrupt outputs per core (C0/C1/C2). Only **C0** outputs are connected on this device.

---

## 14.2 Integration

The device contains a single CPSW_3GSS_RG instance. Subsystem components:

| Component | Description |
|-----------|-------------|
| CPSW_3G | 3-port switch core (2× CPGMAC_SL GMII MAC + host CPPI port) |
| RGMII interface | ×2 (one per external port) |
| RMII interface | ×2 (one per external port) |
| MDIO | PHY management bus |
| Interrupt Controller (WR) | Aggregator/pacer; produces 4 interrupt outputs |
| Local CPPI memory | 8K bytes (2048×32) for DMA descriptors |

### 14.2.1 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | PD_PER_CPSW_125MHZ_GCLK (main), PD_PER_CPSW_250MHZ_GCLK, PD_PER_CPSW_50MHZ_GCLK, PD_PER_CPSW_5MHZ_GCLK, PD_PER_CPSW_CPTS_RFT_CLK |
| Reset Signals | CPSW_MAIN_ARST_N, CPSW_ISO_MAIN_ARST_N |
| Idle/Wakeup | Idle + Standby |
| Interrupt Requests | 4 total to MPU + PRU-ICSS: RX_THRESH (3PGSWRXTHR0), RX (3PGSWRXINT0), TX (3PGSWTXINT0), Misc (3PGSWMISC0) |
| DMA Requests | None (internal CPPI DMA) |
| Physical Address | L4 Fast slave (MMR), L3 Fast initiator (DMA) |

### 14.2.2 Clock Signals

| Clock Signal | Max Freq | Source | Domain |
|-------------|----------|--------|--------|
| main_clk (logic/interface) | 125 MHz | CORE_CLKOUTM5 / 2 | pd_per_cpsw_125mhz_gclk |
| mhz250_clk (RGMII DDR) | 250 MHz | CORE_CLKOUTM5 | pd_per_cpsw_250mhz_gclk |
| mhz50_clk (RMII / 100M RGMII) | 50 MHz | CORE_CLKOUTM5 / 5 | pd_per_cpsw_50mhz_gclk |
| mhz5_clk (10M RGMII) | 5 MHz | CORE_CLKOUTM5 / 50 | pd_per_cpsw_5mhz_gclk |
| cpts_rft_clk (IEEE 1588) | 250 MHz | CORE_CLKOUTM4 or CORE_CLKOUTM5 | pd_per_cpsw_cpts_rft_clk |
| gmii1/2_mr_clk (GMII RX) | 25 MHz | External (GMII1/2_RCLK pad) | — |
| gmii1/2_mt_clk (GMII TX) | 25 MHz | External (GMII1/2_TCLK pad) | — |
| rgmii1/2_rxc_clk (RGMII RX) | 250 MHz | External (RGMII1/2_RCLK pad) | — |
| rmii1/2_mhz_50_clk (RMII ref) | 50 MHz | External (RMII1/2_REFCLK pad) | — |
| rft_clk (GMII Gigabit Tx ref) | 125 MHz | Not supported on AM335x | — |

> [!NOTE]
> RMII reference clock pin operates as **input only** on AM335x. Control via `GMII_SEL[RMIIx_IO_CLK_EN]` in Control Module.

### 14.2.3 Pin List

**MII/GMII (4-bit, MII mode only — GMII 8-bit not bonded):**

| Signal | Dir | Description |
|--------|-----|-------------|
| GMIIx_RXCLK | I | RX clock (2.5 MHz @10M, 25 MHz @100M), from PHY |
| GMIIx_RXD[3:0] | I | Receive data nibble, valid when RXDV high |
| GMIIx_RXDV | I | Receive data valid |
| GMIIx_RXER | I | Receive error |
| GMIIx_COL | I | Collision (half-duplex); hardware TX flow control (full-duplex) |
| GMIIx_CRS | I | Carrier sense (half-duplex); hold low in full-duplex |
| GMIIx_TXCLK | I | TX clock from PHY (2.5 MHz @10M, 25 MHz @100M) |
| GMIIx_TXD[3:0] | O | Transmit data nibble, valid when TXEN high |
| GMIIx_TXEN | O | Transmit enable, synchronous to TXCLK |

**RGMII (4-bit DDR, internal delay NOT supported):**

| Signal | Dir | Description |
|--------|-----|-------------|
| RGMIIx_TCLK | O | TX clock (125/25/2.5 MHz per speed) |
| RGMIIx_TD[3:0] | O | Transmit data, valid when TCTL asserted |
| RGMIIx_TCTL | O | Transmit control/enable |
| RGMIIx_RCLK | I | RX clock from PHY |
| RGMIIx_RD[3:0] | I | Receive data nibble |
| RGMIIx_RCTL | I | Receive data valid/control |

**RMII (2-bit, 50 MHz ref clock input from PHY):**

| Signal | Dir | Description |
|--------|-----|-------------|
| RMIIx_TXD[1:0] | O | Transmit data (LSB = TXD0), synchronous to REFCLK |
| RMIIx_TXEN | O | Transmit enable, synchronous to REFCLK |
| RMIIx_REFCLK | I | 50 MHz reference clock (must be continuous, from PHY/crystal) |
| RMIIx_RXD[1:0] | I | Receive data (LSB = RXD0), valid when CRS_DV high and RXER low |
| RMIIx_CRS_DV | I | Carrier sense / receive data valid (multiplexed) |
| RMIIx_RXER | I | Receive error |

**MDIO:**

| Signal | Dir | Description |
|--------|-----|-------------|
| MDIO_CLK | O | Management data clock; sourced by MDIO module |
| MDIO_DATA | I/O | Management data; output for address/cmd, input for read data |

---

## 14.3 Functional Description

### 14.3.1 CPDMA (CPPI 3.1)

Internal CPPI descriptor memory: **8K bytes (2048×32-bit words)**. 8 TX channels, 8 RX channels. CPU submits/receives linked-list buffer descriptor (BD) chains.

#### 14.3.1.1 TX Buffer Descriptor (4 words × 32-bit)

| Word | Field(s) | Description |
|------|----------|-------------|
| 0 | Next_Descriptor_Pointer | Linked-list next BD; 0 = end of chain |
| 1 | Buffer_Pointer | Physical address of data buffer |
| 2 | Buffer_Offset[31:16] / Buffer_Length[15:0] | Byte offset into buffer; buffer length in bytes |
| 3 | SOP[31] / EOP[30] / OWNER[29] / EOQ[28] / TDOWNCMPLT[27] / PASSCRC[26] / Reserved[25:21] / TO_PORT_EN[20] / TO_PORT[17:16] / PKT_LEN[15:0] | Control flags + packet length |

Key TX word-3 flags:

| Bit | Name | Description |
|-----|------|-------------|
| 31 | SOP | 1 = Start of Packet descriptor |
| 30 | EOP | 1 = End of Packet descriptor |
| 29 | OWNER | 1 = owned by CPDMA; set by SW before write to TXHDP; cleared by CPDMA on completion |
| 28 | EOQ | End of Queue — CPDMA stopped because next_ptr = 0; SW must re-prime TXHDP |
| 27 | TDOWNCMPLT | Teardown complete acknowledgment |
| 26 | PASSCRC | Pass CRC bytes appended to data |
| 20 | TO_PORT_EN | 1 = force out port specified by TO_PORT |
| 17:16 | TO_PORT | Destination port (0=ALE decide, 1=Port1, 2=Port2) |
| 15:0 | PKT_LEN | Total packet length in bytes |

#### 14.3.1.2 RX Buffer Descriptor (4 words × 32-bit)

| Word | Field(s) | Description |
|------|----------|-------------|
| 0 | Next_Descriptor_Pointer | 0 = end of chain |
| 1 | Buffer_Pointer | Physical address of data buffer |
| 2 | Buffer_Offset[31:16] / Buffer_Length[15:0] | Offset added before first byte; buffer length |
| 3 | SOP[31] / EOP[30] / OWNER[29] / EOQ[28] / TDOWNCMPLT[27] / PASSCRC[26] / LONG[25] / SHORT[24] / CONTROL[23] / OVERRUN[22] / PKT_ERR[21:20] / RX_VLAN_ENCAP[19] / FROM_PORT[17:16] / PKT_LEN[15:0] | Status flags + packet length |

Key RX word-3 flags (set by CPDMA on completion):

| Bit | Name | Description |
|-----|------|-------------|
| 31 | SOP | Start of packet |
| 30 | EOP | End of packet |
| 29 | OWNER | 0 = CPU owns (CPDMA cleared on completion) |
| 28 | EOQ | End of queue; SW must recycle |
| 25 | LONG (Jabber) | Frame too long |
| 24 | SHORT (Fragment) | Frame too short |
| 23 | CONTROL | Control frame |
| 22 | OVERRUN | Buffer overrun |
| 21:20 | PKT_ERR | Packet error code |
| 19 | RX_VLAN_ENCAP | VLAN tag present |
| 17:16 | FROM_PORT | Source port (1=Port1, 2=Port2) |
| 15:0 | PKT_LEN | Received packet length |

#### 14.3.1.3 Interrupt Pacing Algorithm

RX/TX pulse interrupts can be paced. Pacing timer algorithm (runs every 1ms, pacing step = 4µs):

```
if (intr_count > 2 * intr_max)   pace_timer = 255;
elif (intr_count > 1.5 * intr_max) pace_timer = last_pace_timer*2 + 1;
elif (intr_count > 1.0 * intr_max) pace_timer = last_pace_timer + 1;
elif (intr_count > 0.5 * intr_max) pace_timer = last_pace_timer - 1;
elif (intr_count != 0)              pace_timer = last_pace_timer / 2;
else                                pace_timer = 0;
```

`INT_CONTROL.int_prescale` = number of VBUSP_CLK periods in 4µs. `Cn_RX_IMAX`/`Cn_TX_IMAX` = target interrupts per ms (valid range: 2–63).

#### 14.3.1.4 Reset Isolation (Silicon-specific)

Controlled by `ISO_CONTROL` bit in Control Module `RESET_ISO` register:

| Mode | ISO_CONTROL | Behavior |
|------|------------|----------|
| 0 (default) | 0 | Any device reset fully resets CPSW_3GSS (including pin mux and clocks) |
| 1 | 1 | Only POR or ICEPICK COLD reset fully resets switch; other resets (SW warm, watchdog, RESETN) leave switch operational; 50/125 MHz clocks and pin mux maintained |

> [!CAUTION]
> Reset isolation has a **silicon bug**. Refer to AM335x Silicon Errata **SPRZ360** before enabling ISO_CONTROL=1.

### 14.3.2 ALE (Address Lookup Engine)

1024 entries × 64-bit, content-addressable. Entry types:

| Type | Key | Action |
|------|-----|--------|
| Unicast | {VLAN[11:0], MAC[47:0]} | Forward / Block / Touched / Secure |
| Multicast | {VLAN[11:0], MAC[47:0]} | Port forward mask, supervision bit |
| VLAN | {VLAN ID} | Member port mask, untagged egress mask |
| OUI | OUI[23:0] | OUI-based host accept/deny |

ALE port states (`ALE_PORTCTLn.P_STATE[3:2]`): 0=Disabled, 1=Blocked, 2=Learn, 3=Forward

### 14.3.3 MDIO

| Operation | Sequence |
|-----------|----------|
| Read PHY register | Write GO=1, WRITE=0, PHYADR, REGADR to USERACCESS; poll GO=0; read DATA[15:0]; check ACK=1 |
| Write PHY register | Write GO=1, WRITE=1, PHYADR, REGADR, DATA[15:0] to USERACCESS; poll GO=0 |

MDIO clock: `MDIO_CLK = OCP_CLK / (CLKDIV + 1)`. IEEE 802.3 max = 2.5 MHz; AM335x supports up to 22.4 MHz.

### 14.3.4 CPTS (Clock/Time Stamp)

- 32-bit counter driven by `cpts_rft_clk` (selectable: CORE_CLKOUTM4 or M5)
- Hardware timestamps IEEE 1588v2 frames at SL MAC (Annex D: UDP/IPv4; Annex F: EtherType 88F7h)
- Event FIFO: 16 entries; fields: timestamp[31:0], event type, port number
- Enable: `CPTS_CONTROL[0]` = 1; interrupt: `CPTS_INT_ENABLE[0]`

---

## 14.4 Statistics Registers (Per Port)

Each port (Port 0/1/2) has 36 statistics counters. All are 32-bit, read-clear on wrap. Enable per port via `STAT_PORT_EN`.

| Offset (within port stats block) | Counter Name | Description |
|----------------------------------|-------------|-------------|
| 0h | RxGoodFrames | Good received frames |
| 4h | RxBroadcastFrames | Broadcast frames received |
| 8h | RxMulticastFrames | Multicast frames received |
| Ch | RxPauseFrames | Pause frames received |
| 10h | RxCRCErrors | CRC error frames |
| 14h | RxAlignCodeErrors | Align/code errors |
| 18h | RxOversizedFrames | Frames exceeding max length |
| 1Ch | RxJabberFrames | Jabber (oversized with CRC error) |
| 20h | RxUndersizedFrames | Undersized frames |
| 24h | RxFragments | Fragments (undersized with CRC error) |
| 28h | RxFilteredFrames | Frames filtered by ALE |
| 2Ch | RxQosFilteredFrames | Frames filtered by QoS |
| 30h | RxOctets | Total receive octets |
| 34h | TxGoodFrames | Good transmitted frames |
| 38h | TxBroadcastFrames | Broadcast frames transmitted |
| 3Ch | TxMulticastFrames | Multicast frames transmitted |
| 40h | TxPauseFrames | Pause frames transmitted |
| 44h | TxDeferredFrames | Deferred transmit frames |
| 48h | TxCollisionFrames | Collision frames |
| 4Ch | TxSingleCollFrames | Single collision frames |
| 50h | TxMultCollFrames | Multiple collision frames |
| 54h | TxExcessiveCollisions | Excessive collision frames |
| 58h | TxLateCollisions | Late collision frames |
| 5Ch | TxUnderrun | Transmit underrun events |
| 60h | TxCarrierSenseErrors | Carrier sense errors |
| 64h | TxOctets | Total transmit octets |
| 68h | OctetsFrames64 | Frames with 64-byte size |
| 6Ch | OctetsFrames65t127 | Frames 65–127 bytes |
| 70h | OctetsFrames128t255 | Frames 128–255 bytes |
| 74h | OctetsFrames256t511 | Frames 256–511 bytes |
| 78h | OctetsFrames512t1023 | Frames 512–1023 bytes |
| 7Ch | OctetsFrames1024tUp | Frames 1024+ bytes |
| 80h | NetOctets | Net total octets (TX+RX) |
| 84h | RxSOFOverruns | Start-of-frame overruns |
| 88h | RxMOFOverruns | Middle-of-frame overruns |
| 8Ch | RxDMAOverruns | DMA overrun events |

---

## 14.5 Key Register Summary

### 14.5.1 WR (Wrapper) Registers — Base offset 0h

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | IDVER | 4EDB0100h | Revision |
| 4h | SOFT_RESET | 0h | W1 to reset; poll until 0 |
| 8h | CONTROL | 0h | VLAN_AWARE[2], NO_IDLE[0] |
| Ch | INT_CONTROL | 0h | int_prescale[15:8] (= VBUSP_CLK periods in 4µs) |
| 10h | C0_RX_THRESH_EN | 0h | RX threshold int enable (host core 0), per channel |
| 14h | C0_RX_EN | 0h | RX completion int enable, per channel |
| 18h | C0_TX_EN | 0h | TX completion int enable, per channel |
| 1Ch | C0_MISC_EN | 0h | Misc int enable (EVNT_PEND, STAT_PEND, HOST_ERR, MDIO_LINKINT, MDIO_USERINT) |
| 40h | C0_RX_THRESH_STAT | 0h | RX threshold interrupt status (masked) |
| 44h | C0_RX_STAT | 0h | RX interrupt status (masked) |
| 48h | C0_TX_STAT | 0h | TX interrupt status (masked) |
| 4Ch | C0_MISC_STAT | 0h | Misc interrupt status (masked) |
| 70h | C0_RX_IMAX | 0h | Max RX interrupts per ms (2–63; 0=no pacing) |
| 74h | C0_TX_IMAX | 0h | Max TX interrupts per ms (2–63; 0=no pacing) |
| 88h | RGMII_CTL | 0h | RGMII1/2 link speed/duplex/link status readback |

### 14.5.2 CPSW_SS Registers — Base + 900h

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | IDVER | — | Revision |
| 4h | CONTROL | 0h | VLAN_AWARE[2], P0_PASS_PRI_TAGGED[1], P0_ENABLE[0] |
| Ch | STAT_PORT_EN | 0h | Enable statistics per port [2:0] |
| 10h | PTYPE | 0h | Priority escalation type |
| 20h | SOFT_RESET | 0h | Soft reset (self-clearing) |

### 14.5.3 Slave Port Registers (SL1: +0D80h, SL2: +0DC0h)

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | IDVER | — | Revision |
| 4h | MACCONTROL | 0h | GMII_EN[5], TX_FLOW_EN[4], RX_FLOW_EN[3], LOOPBACK[1], FULLDUPLEX[0] |
| 8h | MACSTATUS | — | IDLE[31], TX_FLOW_ACTIVE[0] |
| Ch | SOFT_RESET | 0h | W1 to reset |
| 10h | RX_MAXLEN | 1518h | Maximum RX frame length |
| 24h | RX_PRI_MAP | — | RX VLAN PCP → priority queue map |

### 14.5.4 CPDMA Registers — Base + 800h

| Offset | Register | Description |
|--------|----------|-------------|
| 0h–1Ch | TXHDP[0–7] | TX channel head descriptor pointer (W to start DMA) |
| 20h–3Ch | RXHDP[0–7] | RX channel head descriptor pointer |
| 40h–5Ch | TXCP[0–7] | TX completion pointer (W with last processed BD address to ACK) |
| 60h–7Ch | RXCP[0–7] | RX completion pointer |
| 100h | CPDMA_SOFT_RESET | Soft reset |
| 104h | DMACONTROL | TX_EN[0], RX_EN[1] |
| 108h | DMASTATUS | IDLE[31], TX_ERR_CODE[19:16], RX_ERR_CODE[11:8], TX_ERR_CH[3:0], RX_ERR_CH[7:4] |
| 10Ch | RX_BUFFER_OFFSET | Byte offset before first received byte |
| 118h | EMCONTROL | FREERUN[1], SOFT[0] |
| 180h | TX_INTSTAT_RAW | TX raw interrupt status (per channel) |
| 184h | TX_INTSTAT_MASKED | TX masked interrupt status |
| 188h | TX_INTMASK_SET | W1 to enable TX completion interrupt per channel |
| 18Ch | TX_INTMASK_CLEAR | W1 to disable |
| 190h | CPDMA_IN_VECTOR | Interrupt vector (which channel triggered) |
| 194h | CPDMA_EOI_VECTOR | W to ACK: 0=TX, 1=RX, 2=RX_THRESH, 3=MISC |
| 1A0h | RX_INTSTAT_RAW | RX raw interrupt status |
| 1A4h | RX_INTSTAT_MASKED | RX masked status |
| 1A8h | RX_INTMASK_SET | W1 to enable RX per channel |
| 1ACh | RX_INTMASK_CLEAR | W1 to disable |
| 1B0h | DMA_INTSTAT_RAW | Global DMA interrupt status |
| 1B8h | DMA_INTMASK_SET | W1 to enable global DMA interrupt |
| 1BCh | DMA_INTMASK_CLEAR | W1 to disable |

### 14.5.5 ALE Registers — Base + D00h

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | IDVER | — | Revision |
| 8h | ALE_CONTROL | 0h | ENABLE[31], CLEAR_TABLE[30], BYPASS[4], NO_LEARN[1], AGE_OUT_NOW[29] |
| 10h | ALE_PRESCALE | — | Aging clock prescaler (aging = prescale × BYPASS_CNT) |
| 14h | ALE_AGEOUT | — | Age-out configuration |
| 24h | ALE_TBLCTL | — | TABLE_INDEX[9:0], WRITE_RDZ[31]; used to read/write ALE table |
| 34h–3Ch | ALE_PORTCTL0–2 | 0h | Per port: P_STATE[3:2], NO_LEARN[5], MCAST_LIMIT[13:8], BCAST_LIMIT[21:16] |

### 14.5.6 MDIO Registers — Base + 1000h

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | MDIOVER | — | Revision |
| 4h | MDIOCONTROL | 0h | ENABLE[30], PREAMBLE[20], FAULTENB[18], CLKDIV[15:0] |
| 8h | MDIOALIVE | — | Bit mask: PHY addresses that ACKed last poll |
| Ch | MDIOLINK | — | Bit mask: PHY link status |
| 10h | MDIOLINKINTRAW | — | Unmasked link change per PHY |
| 14h | MDIOLINKINTMASKED | — | Masked link change |
| 28h | MDIOUSERINTRAW | — | User access done (raw) |
| 2Ch | MDIOUSERINTMASKED | — | User access done (masked) |
| 30h | MDIOUSERINTMASKSET | — | W1 to enable user access interrupt |
| 34h | MDIOUSERINTMASKCLR | — | W1 to disable |
| 80h | MDIOUSERACCESS0 | — | GO[31], WRITE[30], ACK[29], PHYADR[28:21], REGADR[20:16], DATA[15:0] |
| 84h | MDIOUSERPHYSEL0 | — | PHYADR_MON[4:0], LINKSEL[6], LINKINTENB[7] |
| 88h | MDIOUSERACCESS1 | — | Same layout as MDIOUSERACCESS0 |
| 8Ch | MDIOUSERPHYSEL1 | — | Same layout as MDIOUSERPHYSEL0 |

---

## 14.6 Software Operation

### 14.6.1 Initialization Sequence

1. **PRCM**: Enable CPSW clocks (all 5 domains), de-assert reset
2. **Soft reset**: Write 1 to WR SOFT_RESET, SS SOFT_RESET, CPDMA CPDMA_SOFT_RESET; poll until 0
3. **Interface select**: Write Control Module `GMII_SEL` register (gmii1_sel / gmii2_sel: 0=GMII, 1=RMII, 2=RGMII)
4. **SL MAC control**: Set MACCONTROL: GMII_EN=1, FULLDUPLEX per PHY, TX_FLOW_EN/RX_FLOW_EN as needed
5. **RX maxlen**: Write RX_MAXLEN = 1518 (or 2016 for jumbo)
6. **MDIO init**: Write CLKDIV=(OCP_CLK / target_MDIO_CLK)-1; set ENABLE[30]=1
7. **PHY config**: Poll MDIOALIVE for PHY address bit; use USERACCESS to read/write PHY registers; verify link
8. **ALE init**: Write ALE_CONTROL: ENABLE=1, CLEAR_TABLE=1; set ALE_PORTCTL ports to FORWARD (P_STATE=3); enable learning
9. **Enable stats**: Write STAT_PORT_EN to enable all 3 ports
10. **Enable CPDMA**: Write DMACONTROL: TX_EN=1, RX_EN=1
11. **Enable interrupts**: TX_INTMASK_SET[channel], RX_INTMASK_SET[channel]; WR C0_TX_EN, C0_RX_EN bits
12. **Submit RX BDs**: Allocate buffer descriptors; set OWNER=1; write head pointer to RXHDP[channel]
13. **TX send**: Build TX BD chain (SOP/EOP/OWNER=1); write head to TXHDP[channel]

### 14.6.2 RX Interrupt Handler

1. Read `C0_RX_STAT` → determine which channels fired
2. For each channel: walk BD chain from RXCP[n]; process frames; recycle BDs with OWNER=1 back to RXHDP[n]
3. Write last processed BD address to RXCP[n]; if new data arrived (RXCP[n] ≠ CPDMA wrote), repeat
4. Write `CPDMA_EOI_VECTOR` = 1h (RX EOI)

### 14.6.3 TX Interrupt Handler

1. Read `C0_TX_STAT` → determine which channels fired
2. For each channel: walk BD chain from TXCP[n]; free buffers; check EOQ flag — if set, re-prime TXHDP if queue not empty
3. Write last processed BD address to TXCP[n]
4. Write `CPDMA_EOI_VECTOR` = 0h (TX EOI)
