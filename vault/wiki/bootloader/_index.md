---
title: Bootloader
last_updated: 2026-04-16
status: Stable
---

# Bootloader

U-Boot v2021.10 on BeagleBone Black (AM335x). Boot chain: ROM → SPL/MLO → U-Boot → Linux kernel. Custom defconfig adds TFTP network boot and reduces boot delay for dev workflow.

## Contents

- [[boot-flow]] — Boot sequence, memory map, eMMC layout, uEnv.txt reference
- [[uboot-config]] — Custom defconfig, patches, build commands

## Key Source Files

| File | Purpose |
| ---- | ------- |
| `u-boot/configs/am335x_boneblack_custom_defconfig` | Custom defconfig (BOOTDELAY=1, DHCP/TFTP) |
| `u-boot/patches/0001-boneblack-tftp-boot-env.patch` | TFTP boot env vars |
| `u-boot/patches/0002-boneblack-reduce-boot-delay.patch` | Reduce boot delay to 1 s |
| `scripts/build.sh` | Unified build: `bash scripts/build.sh uboot` |
| `scripts/deploy.sh` | Deploy artifacts to board via SCP |
| `scripts/flash_sd.sh` | Flash SD card (partition + write boot files) |
| `docker/Dockerfile` | Reproducible cross-compile environment |
