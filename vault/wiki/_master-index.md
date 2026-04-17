---
title: Master Index
last_updated: 2026-04-16
---

# BeagleBone BSP — Knowledge Base

**Last Updated:** 2026-04-16

AM335x (Cortex-A8) / BeagleBone Black BSP. Cross-compile toolchain: `arm-linux-gnueabihf-`. Kernel: ARMv7-A.

## Wiki Sections

| Section    | Status | File                                | What it covers                                                                                |
| ---------- | ------ | ----------------------------------- | --------------------------------------------------------------------------------------------- |
| Bootloader | Stable | [[vault/wiki/bootloader/_index.md]] | U-Boot v2021.10, boot sequence, memory map, uEnv.txt, TFTP dev workflow, flash/deploy scripts |
| Kernel     | Empty  | [[vault/wiki/kernel/_index.md]]     | Linux kernel config, DTS files, patches                                                       |
| Drivers    | Empty  | [[vault/wiki/drivers/_index.md]]    | Out-of-tree kernel modules, driver patterns                                                   |
| Yocto      | Empty  | [[vault/wiki/yocto/_index.md]]      | meta-bbb BSP layer, recipes, image build                                                      |
| RTOS       | Empty  | [[vault/wiki/rtos/_index.md]]       | FreeRTOS + OpenAMP firmware for AM335x PRU/M3                                                 |
| Debugging  | Empty  | [[vault/wiki/debugging/_index.md]]  | On-target debug techniques, kernel oops, JTAG                                                 |

## Project Layout

```
beaglebone-bsp/
├── apps/           # Userspace applications
├── docker/         # Build container (Ubuntu 22.04, arm-linux-gnueabihf-)
├── docs/           # Boot flow diagrams, bringup notes
├── drivers/        # Out-of-tree kernel modules
├── freertos/       # FreeRTOS + OpenAMP firmware
├── linux/          # Linux kernel source
├── meta-bbb/       # Yocto BSP layer
├── scripts/        # build.sh, deploy.sh, flash_sd.sh
├── tests/          # On-target integration tests
├── u-boot/         # U-Boot source, custom defconfig, patches
└── vault/wiki/     # This knowledge base
```

## Quick Start

```bash
# Build everything in Docker
docker build -f docker/Dockerfile -t bbb-builder .
docker run --rm -v $(pwd):/workspace bbb-builder bash scripts/build.sh all

# Flash SD card (run as root, artifacts must be in build/)
sudo bash scripts/flash_sd.sh /dev/sdb

# Deploy to running board over USB RNDIS (192.168.7.2)
bash scripts/deploy.sh --kernel --dtb
```

## Reference Links

- AM335x TRM: https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
- U-Boot am335x_evm target: `u-boot/configs/am335x_boneblack_custom_defconfig`
- Build commands: `CLAUDE.md` Quick Build Reference section
