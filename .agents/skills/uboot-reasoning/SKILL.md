---
name: uboot-reasoning
description: Use for U-Boot SPL, boot environment, bootcmd, zImage/DTB loading, TFTP boot, MMC boot, or U-Boot config changes.
---

Check these contracts:

- Target version is U-Boot 2022.07 unless current repo files say otherwise.
- Defconfig is `u-boot/configs/am335x_boneblack_custom_defconfig`.
- SPL size and boot media constraints matter.
- TFTP/dev boot must load the expected `zImage` and DTB names from `build/` or Yocto deploy artifacts.
- Bootargs must match kernel console and rootfs strategy.
- Environment changes must not silently break MMC or TFTP recovery.

Verify with `make uboot`, artifact existence (`MLO`, `u-boot.img`), U-Boot console commands, and `vault/wiki/uboot/`.
