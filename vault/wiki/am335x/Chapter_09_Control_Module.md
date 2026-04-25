---
title: AM335x Chapter 9 Control Module
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 9 Control Module

**Base address:** `0x44E10000`  
**Access:** Reads allowed in user or privileged mode; **writes require MPU privileged mode**.

The Control Module provides centralized device configuration covering: functional I/O multiplexing (pin muxing), emulation controls, device control/status, DDR PHY control, I/O control, and EDMA event multiplexing.

---

## 9.1 Pad Control Registers

Each configurable pin has a 32-bit register `conf_<module>_<pin>`:

| Bits  | Field       | Description                                           |
| ----- | ----------- | ----------------------------------------------------- |
| [6]   | SLEWCTRL    | 0=Fast, 1=Slow slew rate                              |
| [5]   | RXACTIVE    | 0=Receiver disabled (output only), 1=Receiver enabled |
| [4]   | PULLTYPESEL | 0=Pulldown selected, 1=Pullup selected                |
| [3]   | PULLUDEN    | 0=Pull enabled, 1=Pull disabled                       |
| [2:0] | MUXMODE     | Function select 0–7                                   |

**MUXMODE:** Mode 0 = primary function (matches pin name); Modes 1–6 = alternate functions; Mode 7 = GPIO.  
**Reset default:** Most pads default to MUXMODE=7 (GPIO), except boot-time pads.  
**Caution:** Multiplexer is not glitch-free — signal may glitch a few nanoseconds during MUXMODE change.

**Pull resistor power note:** No automatic gating when pad configured as output. Disable internal pull resistors on output-only pads (`PULLUDEN=1`) to avoid unnecessary power consumption.

### 9.1.1 Typical Pin Configurations

| Use case         | MUXMODE | RXACTIVE | PULLTYPESEL | PULLUDEN      |
| ---------------- | ------- | -------- | ----------- | ------------- |
| GPIO             | 7       | 1        | —           | 1 (ext. pull) |
| UART RX          | mode    | 1        | 1 (pullup)  | 0             |
| UART TX          | mode    | 0        | —           | 1             |
| I2C (open-drain) | mode    | 1        | 1 (pullup)  | 0             |
| SPI MOSI/MISO    | mode    | 1        | —           | 1             |

---

## 9.2 EDMA Event Multiplexing

The device has more DMA events than the TPCC's maximum of 64 events. An event crossbar in the Control Module multiplexes additional events with direct-mapped events.

**Registers:** `tpcc_evt_mux_0_3` through `tpcc_evt_mux_60_63`; each register mux-selects 4 consecutive channels.  
**Default:** Direct-mapped event (mux selection = 0).

---

## 9.3 Device Control and Status

### 9.3.1 CONTROL_STATUS (Offset 0x40)

| Bits    | Field      | Description                      |
| ------- | ---------- | -------------------------------- |
| [22:16] | SYSBOOT1   | System boot configuration [15:9] |
| [15:8]  | SYSBOOT0   | System boot configuration [8:1]  |
| [7:0]   | DEVICETYPE | Device type                      |

`SYS_BOOT[15:0]` — configuration input pins captured and latched at POR. Final value before PORz rising edge determines boot device and configuration.

---

## 9.4 Interconnect / EMIF Priority Control

### 9.4.1 Interconnect Priority — INIT_PRIORITY_0, INIT_PRIORITY_1

Controls bus initiator priority. Default: all equal priority, round-robin.

| Value | Priority |
| ----- | -------- |
| 00    | Low      |
| 01    | Medium   |
| 11    | High     |
| 10    | Reserved |

### 9.4.2 EMIF Priority — MREQPRIO (Offset 0x4A4)

Sets access priorities for masters accessing EMIF (DDR). Priority range: `000b` (highest) to `111b` (lowest). Each master has a dedicated 3-bit priority field.

---

## 9.5 USB Control

### 9.5.1 USB_CTRL0 (Offset 0x620) / USB_CTRL1 (Offset 0x628)

| Bits  | Field        | Description                             |
| ----- | ------------ | --------------------------------------- |
| [17]  | CM_PWRDN     | 0=PHY powered up, 1=PHY powered down    |
| [16]  | OTG_PWRDN    | OTG comparators power down              |
| [8]   | CHGDET_DIS   | 0=Charger detection enabled, 1=Disabled |
| [7]   | CHGDET_RSTRT | Charger detection restart               |
| [4]   | CDET_EXTCTL  | 0=Automatic detection, 1=Manual mode    |
| [3:2] | GPIOMODE     | Configure USB data lines as GPIO/UART   |

### 9.5.2 USB Charger Detection Sequence

1. `CM_PWRDN = 0` (power up PHY)
2. `CHGDET_DIS = 0` (enable detection)
3. `CDET_EXTCTL = 0` (automatic mode)
4. `CHGDET_RSTRT = 1` then `= 0` (initiate detection)
5. Monitor `USBx_CE` — goes high if charger detected

Detection steps: VBUS Detect → Data Contact Detect → Primary Detection.  
**Note:** Secondary Detection (CDP vs DCP distinction) not implemented. `USBx_CE` only operates when `USBx_ID` is grounded (host mode).

---

## 9.6 Ethernet Control

### 9.6.1 GMII_SEL (Offset 0x650)

| Bits  | Field           | Description                 |
| ----- | --------------- | --------------------------- |
| [2:1] | GMII1_SEL       | 00=MII, 01=RMII, 10=RGMII   |
| [0]   | RMII1_IO_CLK_EN | RMII reference clock enable |

### 9.6.2 RESET_ISO (Offset 0x65C)

| Bits | Field       | Description                                                                           |
| ---- | ----------- | ------------------------------------------------------------------------------------- |
| [0]  | ISO_CONTROL | 0=Disabled (warm reset propagates), 1=Enabled (warm reset blocked to Ethernet switch) |

Cold/POR resets always propagate. When enabled, also protects: GMII_SEL, CONF_GPMC_A[11:0], Ethernet MII/MDIO configuration registers.

---

## 9.7 DDR PHY Control

### 9.7.1 VTP_CTRL (Offset 0x60C)

DDR I/O impedance calibration.

| Bits | Field  | Description                      |
| ---- | ------ | -------------------------------- |
| [6]  | ENABLE | VTP enable                       |
| [5]  | READY  | Calibration complete (read-only) |
| [4]  | FILTER | Filter enable                    |
| [0]  | CLRZ   | Clear calibration logic          |

**VTP calibration sequence:**

1. `CLRZ = 0`
2. `ENABLE = 1`
3. `CLRZ = 1`
4. Poll `READY = 1`
5. `FILTER = 1`
6. Proceed with DDR initialization

**Related registers:** DDR_IO_CTRL (0xE04), DDR_CKE_CTRL, DDR_CMD_x_IOCTRL, DDR_DATA_x_IOCTRL — configure DDR PHY drive strength, pull settings, slew rate.

---

## 9.8 Interprocessor Communication (IPC)

Message passing between Cortex-A8 and Cortex-M3. For power management usage, see Chapter 8.

| Register       | Offset      | Purpose                         |
| -------------- | ----------- | ------------------------------- |
| IPC_MSG_REG0   | 0x400       | [31:16] CMD_ID, [15:0] CMD_STAT |
| IPC_MSG_REG1   | 0x404       | Command parameter 1             |
| IPC_MSG_REG2   | 0x408       | Command parameter 2             |
| IPC_MSG_REG3   | 0x40C       | CM3 response/status             |
| IPC_MSG_REG4–6 | 0x410–0x418 | Reserved                        |
| IPC_MSG_REG7   | 0x41C       | Customer use                    |

### M3_TXEV_EOI (Offset 0x424)

| Bits | Field           | Description                         |
| ---- | --------------- | ----------------------------------- |
| [0]  | M3_TXEOI_ENABLE | Write 1 to clear Cortex-M3 TX event |

---

## 9.9 Timer / eCAP Event Capture

**TIMER_EVT_CAPTURE** — select event capture sources for Timer 5, 6, 7.  
**ECAP_EVT_CAPTURE** — select event capture sources for eCAP 0, 1, 2.  
Sources: IO pins, internal events, cross-connected timer/eCAP events.

---

## 9.10 SRAM LDO Control

**SMA2 register** — controls internal LDO for SRAM retention during low-power modes (DeepSleep0).  
`vsldo_core_auto_ramp_en` — enables auto-ramp for retention mode (PG 2.x only).

---

## 9.11 Key Notes

1. All Control Module register **writes require privileged mode** — user mode writes silently fail.
2. **Pin mux glitches:** Not glitch-free; ensure no contention during MUXMODE change.
3. **SYS_BOOT:** Sampled continuously during PORz active; final value before PORz rising edge latched.
4. **VTP calibration:** Must complete (`READY=1`) before DDR operation.
5. **USB Charger Detection:** Only operates when `USBx_ID` grounded (host mode).
6. **Reset Isolation (`RESET_ISO`):** Protects Ethernet during warm reset but not cold/POR resets.
7. **Default MUXMODE:** Most pads default to Mode 7 (GPIO) at reset.
8. **EDMA crossbar:** Default = direct-mapped events; configure `tpcc_evt_mux_*` registers as needed.
