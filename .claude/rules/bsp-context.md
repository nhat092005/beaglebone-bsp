# BSP Hardware Context — AM335x / BeagleBone Black

## Target Hardware

- SoC: Texas Instruments AM335x (Cortex-A8, ARMv7-A)
- Board: BeagleBone Black (BBB)
- Architecture: `arm` (32-bit, hard-float ABI: `arm-linux-gnueabihf`)
- RAM: 512 MB DDR3
- eMMC: 4 GB on-board, microSD (bootable)

## Source of Truth for Hardware Details

All peripheral base addresses, interrupt numbers, clock domains, and pinmux details
are in the vault wiki -- not in this file.

Read vault/wiki/kernel/\_index.md for kernel and DTS reference.
Read vault/wiki/bootloader/\_index.md for U-Boot and boot sequence details.
Read vault/wiki/debugging/\_index.md for hardware debug techniques.

If a specific address or register is needed and not in the wiki, consult the
AM335x Technical Reference Manual (TRM): https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf

Read `docs/09-debug-agent.md` for the automated UART debug pipeline and `/dev/ttyUSB0` access requirements.

## Linux Kernel Device Tree Files

Upstream files (read-only — do NOT modify directly):

- SoC base: `linux/arch/arm/boot/dts/am33xx.dtsi`
- SoC clocks: `linux/arch/arm/boot/dts/am33xx-clocks.dtsi`
- Board upstream: `linux/arch/arm/boot/dts/am335x-boneblack.dts`
- Board common: `linux/arch/arm/boot/dts/am335x-bone-common.dtsi`

Project custom DTS (this is the file to create/edit):

- `linux/dts/am335x-boneblack-custom.dts` — includes `am335x-boneblack.dts`, adds project nodes
- Builds to: `linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb`

## Boot Sequence

```
ROM -> SPL (MLO) -> U-Boot -> Linux kernel -> rootfs
```

- MLO and u-boot.img loaded from eMMC FAT partition or SD card
- Kernel loaded via `bootz` command in U-Boot
- Default console: `ttyO0` at `115200 8N1`
- Hold BOOT button on power-up to force SD card boot instead of eMMC
