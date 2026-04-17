# Tech Defaults — Toolchain and Build Configuration

Default values for all build commands in this project. Always use these unless explicitly overridden.

## Cross-Compile Toolchain

| Variable | Value |
|---|---|
| `CROSS_COMPILE` | `arm-linux-gnueabihf-` |
| `ARCH` | `arm` |
| Toolchain prefix | `arm-linux-gnueabihf-` |
| C compiler | `arm-linux-gnueabihf-gcc` |
| Objcopy | `arm-linux-gnueabihf-objcopy` |

## Kernel Build Defaults

| Setting | Value |
|---|---|
| defconfig | `am335x_boneblack_defconfig` |
| Output image | `arch/arm/boot/zImage` |
| DTB | `arch/arm/boot/dts/am335x-boneblack.dtb` |
| Parallel jobs | `-j$(nproc)` |
| Build targets | `zImage dtbs modules` |

Default kernel build command:
```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules
```

## U-Boot Build Defaults

| Setting | Value |
|---|---|
| defconfig | `am335x_evm_defconfig` |
| Output | `u-boot.img` + `MLO` |

Default U-Boot build command:
```bash
make CROSS_COMPILE=arm-linux-gnueabihf- am335x_evm_defconfig
make CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)
```

## Yocto Build Defaults

| Setting | Value |
|---|---|
| Distro | `poky` |
| Machine | `beaglebone-yocto` |
| Default image | `core-image-minimal` |
| Build directory | `build/` |
| Init script | `poky/oe-init-build-env` |

Default Yocto commands:
```bash
source poky/oe-init-build-env build
bitbake core-image-minimal
```

## Out-of-Tree Driver Defaults

```bash
make ARCH=arm \
     CROSS_COMPILE=arm-linux-gnueabihf- \
     KERNEL_DIR=$(pwd)/linux \
     -C drivers/<name>
```

## Serial Console

| Setting | Value |
|---|---|
| Port (Linux) | `/dev/ttyUSB0` or `/dev/ttyACM0` |
| Baud rate | `115200` |
| Format | `8N1` |
| U-Boot console tty | `ttyO0` |
| Kernel console tty | `ttyO0` |

Connect: `minicom -D /dev/ttyUSB0 -b 115200` or `screen /dev/ttyUSB0 115200`

## SD Card / eMMC Boot Order

BeagleBone Black reads boot media in this order:
1. microSD card (if present and has valid MLO)
2. eMMC (on-board 4 GB)

Hold BOOT button on power-up to force SD boot.
