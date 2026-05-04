---
title: U-Boot
last_updated: 2026-04-26
category: bootloader
---

# Bootloader (U-Boot v2022.07)

U-Boot boot chain: ROM → SPL (MLO) → U-Boot → Kernel.

## Workflow

| #   | Topic                 | File                                  |
| --- | --------------------- | ------------------------------------- |
| 00  | Boot Flow Overview    | [[00-boot-flow.md]]                   |
| 01  | Workflow Overview     | [[01-uboot-workflow.md]]              |
| 02  | Clone & Branch Setup  | [[02-uboot-clone.md]]                 |
| 03  | Custom Defconfig      | [[03-uboot-custom-defconfig.md]]      |
| 04  | Patch Queue           | [[04-uboot-patches.md]]               |
| 05  | Build & Verify        | [[05-uboot-build-verify.md]]          |
| 06  | TFTP/RNDIS Boot Notes | [[06-uboot-tftp-rndis-boot.md]]       |
| 07  | Apply Project Patches | [[07-uboot-apply-project-patches.md]] |

## Key Artifacts

| Path/File                                          | Purpose                                 |
| -------------------------------------------------- | --------------------------------------- |
| `u-boot/configs/am335x_boneblack_custom_defconfig` | Custom defconfig (BOOTDELAY=1, TFTP)    |
| `meta-bbb/recipes-bsp/u-boot/files/0001-*.patch`   | USB gadget Ethernet DM_ETH teardown fix |
| `meta-bbb/recipes-bsp/u-boot/files/0002-*.patch`   | USB RNDIS TFTP boot environment         |
| `meta-bbb/recipes-bsp/u-boot/files/0003-*.patch`   | USB gadget MAC from eFuse               |
| `scripts/build.sh`                                 | Build helper used by `make uboot`       |
| `scripts/deploy.sh`                                | Deploy via TFTP                         |
| `scripts/flash_sd.sh`                              | Flash SD card (MLO, u-boot.img)         |
