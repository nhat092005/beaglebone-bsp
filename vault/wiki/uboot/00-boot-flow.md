---
title: Boot Flow
last_updated: 2026-04-26
---

# Boot Flow - BeagleBone Black

Reference: AM335x TRM SPRUH73Q Section 26.1 "ROM Code", Section 7 "EMIF";
U-Boot v2022.07.

## Sequence

```
ROM (0x00020000)
  └─► SPL/MLO  — SRAM 0x402F0400, max 109 KB
        └─► u-boot.img — DDR3 0x80800000
              └─► zImage — 0x82000000
                    DTB  — 0x88000000
```

1. AM335x ROM reads MLO from the selected boot medium. On BBB development
   setups, SD boot is normally forced with the S2 BOOT button.
2. MLO (SPL) initialises DDR3, loads `u-boot.img` to `0x80800000`.
3. U-Boot relocates, imports `uEnv.txt` from FAT p1 when present, then runs
   `bootcmd` or `uenvcmd`.
4. `bootz 0x82000000 - 0x88000000` hands off to kernel.
5. Kernel decompresses, mounts rootfs, runs `/sbin/init`.

## Memory Map

| Stage      | Load address | Max size | Storage             |
| ---------- | ------------ | -------- | ------------------- |
| ROM code   | 0x00020000   | —        | SoC internal        |
| MLO (SPL)  | 0x402F0400   | 109 KB   | Boot medium         |
| u-boot.img | 0x80800000   | ~512 KB  | eMMC FAT p1 / SD p1 |
| zImage     | 0x82000000   | ~8 MB    | eMMC FAT p1 / SD p1 |
| DTB        | 0x88000000   | ~64 KB   | eMMC FAT p1 / SD p1 |

## Boot Medium Layout

```
Sector 0     MBR / partition table
Partition 1  FAT32, 100 MB in the current flash_sd.sh
             MLO, u-boot.img, zImage, am335x-boneblack-custom.dtb, uEnv.txt
Partition 2  ext4, remainder — optional rootfs
```

The current `scripts/flash_sd.sh` copies `MLO` onto the FAT partition. It does
not raw-write `MLO` to a fixed sector.

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

### TFTP boot (current dev workflow)

Requires the `tftp_boot` variable from the current U-Boot patch queue in
`patches/u-boot/v2022.07/`. The current defaults are host/server
`192.168.7.1` and board `192.168.7.2`.

```
serverip=192.168.7.1
ipaddr=192.168.7.2
uenvcmd=run tftp_boot
```

Current `scripts/flash_sd.sh` writes `uenvcmd=run tftp_boot`, so the generated
SD card still expects the TFTP development path for kernel handoff even though
`zImage` and the DTB are also copied to the FAT partition.

## Console

UART0 (ttyO0), 115200 8N1. Use the BBB J1 serial header:
pin 1 = GND, pin 4 = UART0_RX (adapter TX), pin 5 = UART0_TX (adapter RX).

```bash
minicom -D /dev/ttyUSB0 -b 115200
```
