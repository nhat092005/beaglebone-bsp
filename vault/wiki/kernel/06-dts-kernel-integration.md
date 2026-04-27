---
title: DTS-Kernel Integration
tags:
  - device-tree
  - kernel
  - dtb
last_updated: 2026-04-27
category: kernel
---

# DTS-Kernel Integration

How the Linux kernel uses Device Tree Blob (DTB) files.

## Overview

Device Tree describes hardware to the kernel. The kernel reads DTB at boot and creates platform devices accordingly.

**Flow:**

```
Bootloader (U-Boot)
  ↓ loads DTB to RAM
Kernel boot
  ↓ parses DTB
Device probing
  ↓ matches compatible strings
Driver initialization
```

## DTB Location in Build

### Source

```
linux/arch/arm/boot/dts/am335x-boneblack-custom.dts
```

### Compiled Output

```
linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb
```

### Build Artifact

```
build/kernel/am335x-boneblack-custom.dtb
```

## Makefile Registration

DTB must be registered in kernel Makefile:

**File:** `linux/arch/arm/boot/dts/Makefile`

```makefile
dtb-$(CONFIG_SOC_AM33XX) += \
    am335x-boneblack.dtb \
    am335x-boneblack-custom.dtb \
    ...
```

**Check registration:**

```bash
cd linux
grep am335x-boneblack-custom arch/arm/boot/dts/Makefile
```

## Kernel Build Integration

### Build DTB with Kernel

```bash
make kernel
```

This runs:

```bash
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage dtbs modules
```

### Build DTB Only

```bash
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
```

### Build Specific DTB

```bash
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x-boneblack-custom.dtb
```

## Boot Process

### 1. U-Boot Loads DTB

U-Boot loads DTB to RAM address (typically `0x88000000`):

```
setenv fdtaddr 0x88000000
tftp ${fdtaddr} am335x-boneblack-custom.dtb
```

### 2. U-Boot Passes DTB to Kernel

```
bootz ${loadaddr} - ${fdtaddr}
```

Arguments:
- `${loadaddr}`: zImage address
- `-`: No initramfs
- `${fdtaddr}`: DTB address

### 3. Kernel Parses DTB

Early boot code parses DTB to internal tree structure.

### 4. Platform Device Creation

Kernel creates platform devices from DT nodes with `status = "okay"`.

### 5. Driver Matching

Kernel matches drivers to devices via `compatible` string.

## Runtime Device Tree Access

### Procfs Interface

```bash
# View DTB in memory
ls /proc/device-tree/

# Check model
cat /proc/device-tree/model

# View specific node
ls /proc/device-tree/ocp/uart@48022000/
```

### Sysfs Interface

```bash
# View device tree structure
ls /sys/firmware/devicetree/base/

# Check compatible string
cat /sys/firmware/devicetree/base/compatible
```

## Kernel Configuration

### Enable Device Tree Support

```
CONFIG_USE_OF=y
CONFIG_OF=y
CONFIG_OF_FLATTREE=y
```

These are enabled by default in `omap2plus_defconfig`.

### Enable Specific Drivers

Drivers must be enabled in kernel config:

```
CONFIG_SERIAL_OMAP=y          # UART
CONFIG_I2C_OMAP=y             # I2C
CONFIG_SPI_OMAP24XX=y         # SPI
CONFIG_PWM_TIEHRPWM=y         # PWM
CONFIG_KEYBOARD_GPIO=y        # GPIO keys
```

## Debugging

### Check DTB Loaded

```bash
# On target
dmesg | grep -i "device tree"
dmesg | grep -i "machine model"
```

Expected:

```
[    0.000000] Machine model: TI AM335x BeagleBone Black
```

### Check Device Probing

```bash
# UART1
dmesg | grep 48022000.serial

# I2C2
dmesg | grep 4819c000.i2c

# SPI1
dmesg | grep 481a0000.spi

# EHRPWM1
dmesg | grep ehrpwm

# GPIO keys
dmesg | grep gpio-keys
```

### Check Driver Binding

```bash
# List platform devices
ls /sys/bus/platform/devices/

# Check driver binding
ls /sys/bus/platform/drivers/
```

## DTB Deployment

### Via TFTP (Development)

```bash
# On host
make deploy

# U-Boot loads from TFTP
tftp ${fdtaddr} am335x-boneblack-custom.dtb
```

### Via SD Card (Production)

```bash
# Flash to SD card
make flash DEV=/dev/sdX

# U-Boot loads from FAT partition
fatload mmc 0:1 ${fdtaddr} am335x-boneblack-custom.dtb
```

## Custom DTS Details

For detailed information about the custom DTS:

- **DTS structure:** See `vault/wiki/dts/01-custom-dts.md`
- **Pinmux:** See `vault/wiki/dts/02-pinmux-reference.md`
- **Pin mapping:** See `vault/wiki/dts/03-pin-mapping.md`
- **Validation:** See `vault/wiki/dts/04-validation.md`

## References

- Kernel DT docs: `linux/Documentation/devicetree/`
- DT specification: https://devicetree.org/specifications/
- Custom DTS: `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts`
- DTS wiki: `vault/wiki/dts/`
