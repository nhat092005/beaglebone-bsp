---
title: Boot Flow
last_updated: 2026-04-16
---

# Boot Flow — BeagleBone Black

## Sequence

```
ROM (0x00020000)
  └─► SPL/MLO  — SRAM 0x402F0400, max 109 KB
        └─► u-boot.img — DDR3 0x80800000
              └─► zImage — 0x82000000
                    DTB  — 0x88000000
```

1. AM335x ROM reads MLO from eMMC raw sector 256 (or SD p1 if BOOT button held).
2. MLO (SPL) initialises DDR3, loads `u-boot.img` to `0x80800000`.
3. U-Boot relocates, reads `uEnv.txt` from FAT p1, runs `bootcmd`.
4. `bootz 0x82000000 - 0x88000000` hands off to kernel.
5. Kernel decompresses, mounts rootfs, runs `/sbin/init`.

## Memory Map

| Stage      | Load address | Max size | Storage             |
| ---------- | ------------ | -------- | ------------------- |
| ROM code   | 0x00020000   | —        | SoC internal        |
| MLO (SPL)  | 0x402F0400   | 109 KB   | eMMC raw / SD p1    |
| u-boot.img | 0x80800000   | ~512 KB  | eMMC FAT p1 / SD p1 |
| zImage     | 0x82000000   | ~8 MB    | eMMC FAT p1 / SD p1 |
| DTB        | 0x88000000   | ~64 KB   | eMMC FAT p1 / SD p1 |

## eMMC Layout

```
Sector 0     MBR / partition table
Sector 256   MLO (raw — ROM reads here directly, no filesystem)
Partition 1  FAT32, 64 MB — MLO, u-boot.img, zImage, am335x-boneblack-custom.dtb, uEnv.txt
Partition 2  ext4, remainder — rootfs
```

## SD Card Override

Hold **S2 (BOOT button)** on power-on. ROM checks SD before eMMC. SD layout mirrors eMMC.

## uEnv.txt Reference

`uEnv.txt` lives on FAT p1. U-Boot reads it before running `bootcmd`.

| Variable   | Purpose                     |
| ---------- | --------------------------- |
| `bootargs` | Kernel cmdline              |
| `loadaddr` | zImage load address         |
| `fdtaddr`  | DTB load address            |
| `uenvcmd`  | Overrides default `bootcmd` |

### MMC boot

```
bootargs=console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
uenvcmd=load mmc 0:1 ${loadaddr} zImage; load mmc 0:1 ${fdtaddr} am335x-boneblack-custom.dtb; bootz ${loadaddr} - ${fdtaddr}
```

### TFTP boot (dev workflow)

Requires patches applied (see [[03-uboot-custom-defconfig]]). Server default `192.168.1.1`, board default `192.168.1.100`.

```
uenvcmd=run tftp_boot
```

## Console

UART0 (ttyO0), 115200 8N1. P9.11 (RX) / P9.13 (TX) / GND.

```bash
minicom -D /dev/ttyUSB0 -b 115200
```
