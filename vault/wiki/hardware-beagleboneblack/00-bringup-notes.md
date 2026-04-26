---
title: Bringup Notes
last_updated: 2026-04-26
category: hardware
---

# Bringup Notes - BeagleBone Black Rev C (AM335x)

Reference: BBB SRM Rev C §7.5 (Serial Header), §6.1 (Boot Sources), AM335x TRM SPRUH73Q §26.1 (Boot ROM).

---

## Wiring

Connect an FT232-compatible **3.3 V** USB-to-serial adapter to the BBB J1 debug header
(6-pin 1.27 mm pitch, near the USB-A port):

| J1 Pin | Signal   | Adapter wire |
| ------ | -------- | ------------ |
| 1      | GND      | GND          |
| 4      | UART0_RX | TX           |
| 5      | UART0_TX | RX           |

> **Warning:** J1 pin 2 carries 5 V. Do not connect it to a 3.3 V adapter. Leave pins 3 and 6 unconnected.

Power the board via the 5 V DC barrel jack (5 V 1 A minimum). Do **not** use USB-only power when booting from SD — inrush current can cause brown-out.

---

## Serial Console

```bash
minicom -D /dev/ttyUSB0 -b 115200
```

Minicom settings (Ctrl-A Z → O → Serial port setup):

| Setting       | Value        |
| ------------- | ------------ |
| Device        | /dev/ttyUSB0 |
| Baud rate     | 115200       |
| Data bits     | 8            |
| Parity        | None         |
| Stop bits     | 1            |
| Hardware flow | Off          |
| Software flow | Off          |

Add user to `dialout` group to avoid `sudo`:

```bash
sudo usermod -aG dialout "${USER}" && newgrp dialout
```

Alternative (no minicom):

```bash
screen /dev/ttyUSB0 115200
```

---

## Boot Timeline

Target: first `U-Boot#` character within **8 seconds** of 5 V DC-jack insertion.

| Time (s) | Stage     | Observable output                           |
| -------- | --------- | ------------------------------------------- |
| 0.0      | Power-on  | 5 V applied                                 |
| 0.0–0.3  | ROM code  | Scans boot media per latched SYSBOOT pins   |
| 0.3–1.0  | SPL (MLO) | `U-Boot SPL 2022.07` line on serial         |
| 1.0–2.5  | U-Boot    | `U-Boot 2022.07` banner, `U-Boot#` prompt   |
| 2.5–8.0  | Kernel    | `Starting kernel ...` → init → login prompt |

SPL initializes DDR3 SDRAM before handing off to U-Boot. If serial is silent past 1 s,
suspect MLO not found or SDRAM init failure (check SD card partition table).

---

## SD Boot (BOOT Button)

Boot order is selected by SYSBOOT pins latched at power-on. On many BBB setups, eMMC
often wins unless SD boot is explicitly forced. To force SD boot:

1. Insert the flashed microSD card.
2. Hold the **S2 (BOOT)** button (nearest to the microSD slot).
3. Apply 5 V power (or press S3 RESET).
4. Release S2 after the first SPL line appears on serial (~0.5 s).

Boot order is controlled by the SYSBOOT pins latched at power-on. Holding S2 pulls
SYSBOOT[4:0] to select SD-first order per AM335x TRM §26.1.7.

---

## Troubleshooting

| Symptom                        | Likely cause                                        | Fix                                                                              |
| ------------------------------ | --------------------------------------------------- | -------------------------------------------------------------------------------- |
| No serial output               | Wrong adapter wiring (TX/RX swapped)                | Swap TX↔RX wires at adapter                                                      |
| `spl: error loading` or hang   | Bad SD card or wrong partition layout               | Re-run `flash_sd.sh`, verify p1=FAT32 with MLO                                   |
| U-Boot prompt but no kernel    | TFTP files missing or `uEnv.txt` boot path mismatch | For current scripts, run `make deploy TFTP_DIR=/srv/tftp` and verify `tftp_boot` |
| Board resets before U-Boot     | Under-voltage / bad PSU                             | Use 5 V 1 A DC barrel jack, not USB power                                        |
| eMMC boots instead of SD       | MLO on eMMC takes precedence                        | Hold S2 BOOT button at power-on                                                  |
| `VFS: Cannot open root device` | rootfs not on p2 or wrong `root=` arg               | Check `uEnv.txt` `bootargs` — must be `mmcblk0p2`                                |
