---
title: U-Boot Custom Defconfig
last_updated: 2026-04-18
category: bootloader
---

# U-Boot Custom Defconfig

Step 3 of U-Boot workflow.

## Create custom defconfig

Copy the stock defconfig and apply BBB-specific changes:

```bash
cp configs/am335x_evm_defconfig configs/am335x_boneblack_custom_defconfig
```

## Required changes

Edit `am335x_boneblack_custom_defconfig`:

| Setting                      | Stock          | Custom               | Reason                 |
| ---------------------------- | -------------- | -------------------- | ---------------------- |
| `CONFIG_DEFAULT_DEVICE_TREE` | `"am335x-evm"` | `"am335x-boneblack"` | Correct board DT       |
| `CONFIG_SPL_OS_BOOT`         | `y`            | `# not set`          | Not used in TFTP path  |
| `CONFIG_OF_LIST`             | multiple       | `"am335x-boneblack"` | Trim image size        |
| `CONFIG_OF_LIBFDT`           | implicit       | `y`                  | Explicit for TFTP boot |
| `CONFIG_CMD_TFTPPUT`         | absent         | `y`                  | TFTP dev workflow      |
| `CONFIG_CMD_BOOTZ`           | absent         | `y`                  | Required for zImage    |
| `CONFIG_BOOTDELAY`           | default (2)    | `1`                  | Faster dev cycle       |

## Verify

```bash
grep -E '^(CONFIG_CMD_TFTPPUT|CONFIG_CMD_BOOTZ|CONFIG_OF_LIBFDT|CONFIG_BOOTDELAY)=' \
  configs/am335x_boneblack_custom_defconfig
# expect: 4 lines, CONFIG_BOOTDELAY=1

grep 'SPL_OS_BOOT' configs/am335x_boneblack_custom_defconfig
# expect: # CONFIG_SPL_OS_BOOT is not set
```

## Related

- 04-uboot-patches — Apply patches after defconfig
- 00-boot-flow — Boot sequence with TFTP
- AM335x TRM SPRUH73Q §7 — DDR3 memory map
