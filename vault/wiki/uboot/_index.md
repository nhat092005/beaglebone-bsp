---
title: U-Boot
last_updated: 2026-04-25
category: bootloader
---

# Bootloader (U-Boot v2022.07)

U-Boot boot chain: ROM → SPL (MLO) → U-Boot → Kernel.

## Workflow

| #   | Topic                 | File                             |
| --- | --------------------- | -------------------------------- |
| 00  | Boot Flow Overview    | [[00-boot-flow.md]]              |
| 01  | Full Tutorial         | [[01-uboot-workflow.md]]         |
| 02  | Clone & Branch Setup  | [[02-uboot-clone.md]]            |
| 03  | Custom Defconfig      | [[03-uboot-custom-defconfig.md]] |
| 04  | Patches (TFTP, delay) | [[04-uboot-patches.md]]          |
| 05  | Build & Verify        | [[05-uboot-build-verify.md]]     |
| 06  | TFTP/RNDIS Boot Notes | [[06-uboot-tftp-rndis-boot.md]]  |

## Key Artifacts

| Path/File                                          | Purpose                              |
| -------------------------------------------------- | ------------------------------------ |
| `u-boot/configs/am335x_boneblack_custom_defconfig` | Custom defconfig (BOOTDELAY=1, TFTP) |
| `u-boot/patches/0001-*.patch`                      | TFTP boot environment                |
| `u-boot/patches/0002-*.patch`                      | Reduce boot delay to 1s              |
| `scripts/build.sh`                                 | Build: `bash scripts/build.sh uboot` |
| `scripts/deploy.sh`                                | Deploy via TFTP                      |
| `scripts/flash_sd.sh`                              | Flash SD card (MLO, u-boot.img)      |
