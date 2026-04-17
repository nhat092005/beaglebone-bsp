---
title: U-Boot Configuration
last_updated: 2026-04-16
---

# U-Boot Configuration

Base: U-Boot **v2021.10**, `am335x_evm_defconfig`.

## Custom Defconfig

`u-boot/configs/am335x_boneblack_custom_defconfig` — key differences from upstream:

| Config symbol          | Value   | Reason                                      |
| ---------------------- | ------- | ------------------------------------------- |
| `CONFIG_BOOTDELAY`     | `1`     | Faster dev boot cycle (upstream default: 2) |
| `CONFIG_CMD_DHCP`      | `y`     | Network boot support                        |
| `CONFIG_CMD_TFTP`      | `y`     | TFTP kernel fetch                           |
| `CONFIG_USE_SERVERIP`  | `y`     | Default TFTP server: `192.168.1.1`          |
| `CONFIG_USE_IPADDR`    | `y`     | Default board IP: `192.168.1.100`           |
| `CONFIG_ENV_IS_IN_FAT` | `y`     | U-Boot env on FAT p1 (mmc 0:1)              |
| `CONFIG_CMD_NAND`      | not set | Unused on BBB — reduces image size          |

## Patches

| Patch                                                   | What it does                                                                 |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `u-boot/patches/0001-boneblack-tftp-boot-env.patch`     | Adds `serverip`, `ipaddr`, `tftp_boot` env to `include/configs/am335x_evm.h` |
| `u-boot/patches/0002-boneblack-reduce-boot-delay.patch` | Sets `CONFIG_BOOTDELAY=1` in `am335x_evm_defconfig`                          |

Apply before building:

```bash
cd u-boot
git am ../u-boot/patches/0001-boneblack-tftp-boot-env.patch
git am ../u-boot/patches/0002-boneblack-reduce-boot-delay.patch
```

> **Note:** Patch context lines target U-Boot v2021.10. Regenerate with `git format-patch` if using a different version.

## Build

```bash
# Via build.sh (recommended)
bash scripts/build.sh uboot

# Manual
cd u-boot
make CROSS_COMPILE=arm-linux-gnueabihf- am335x_evm_defconfig
make CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)
```

Artifacts: `build/MLO`, `build/u-boot.img`.

## Build in Docker

```bash
docker build -f docker/Dockerfile -t bbb-builder .
docker run --rm -v $(pwd):/workspace bbb-builder bash scripts/build.sh uboot
```
