---
title: DTS Overview
tags:
  - device-tree
  - dts
  - dtb
last_updated: 2026-04-27
category: dts
---

# Device Tree Overview

## What is Device Tree?

Device Tree is a data structure for describing hardware. It tells the Linux kernel what hardware exists on the board without hardcoding it in kernel source.

**Key concepts:**
- **DTS** (Device Tree Source) - Human-readable text format
- **DTB** (Device Tree Blob) - Binary format loaded by bootloader
- **DTC** (Device Tree Compiler) - Converts DTS → DTB

## Why Device Tree?

**Before Device Tree:**
- Hardware info hardcoded in kernel C code
- New board = recompile kernel
- ARM had 1000+ board files in kernel tree

**With Device Tree:**
- Hardware described in separate DTS file
- Same kernel binary for multiple boards
- Bootloader passes DTB to kernel at boot

## DTS Hierarchy for BeagleBone Black

```
am33xx.dtsi                          (SoC: AM335x peripherals)
  ↓
am335x-bone-common.dtsi              (Common: BBB + BBG shared)
  ↓
am335x-boneblack.dts                 (Base: BBB Rev C)
  ↓
am335x-boneblack-custom.dts          (Custom: Project-specific)
```

**Inheritance:**
- Each level includes the previous
- Child can override parent properties
- Custom DTS extends base without modifying upstream files

## File Locations

| File | Path |
|------|------|
| Custom DTS | `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts` |
| Base DTS | `linux/arch/arm/boot/dts/am335x-boneblack.dts` |
| SoC DTSI | `linux/arch/arm/boot/dts/am33xx.dtsi` |
| Compiled DTB | `linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb` |
| Build output | `build/kernel/am335x-boneblack-custom.dtb` |

## DTS Syntax Basics

### Node Structure

```dts
node_name@address {
    compatible = "vendor,device";
    reg = <0x48000000 0x1000>;
    status = "okay";
    
    child_node {
        property = <value>;
    };
};
```

### Property Types

```dts
string-property = "text";
integer-property = <42>;
array-property = <1 2 3>;
boolean-property;
phandle-property = <&other_node>;
```

### Common Properties

| Property | Purpose | Example |
|----------|---------|---------|
| `compatible` | Driver matching | `"ti,omap3-uart"` |
| `reg` | Register address/size | `<0x48022000 0x1000>` |
| `status` | Enable/disable | `"okay"` or `"disabled"` |
| `pinctrl-0` | Pin configuration | `<&uart1_pins>` |

## Workflow

### 1. Write DTS

Edit `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts`

### 2. Compile DTB

```bash
make kernel
# or
cd linux && make ARCH=arm dtbs
```

### 3. Validate

```bash
make dtbs-check
make verify-dts
```

### 4. Deploy

```bash
# Copy to TFTP
make deploy

# Or flash to SD card
make flash DEV=/dev/sdX
```

### 5. Boot & Test

```bash
# On target
cat /proc/device-tree/model
ls /proc/device-tree/ocp/
dmesg | grep -i probe
```

## Key Concepts

### Phandles

Reference to another node:

```dts
uart1_pins: pinmux_uart1 {
    /* pin config */
};

&uart1 {
    pinctrl-0 = <&uart1_pins>;  /* phandle reference */
};
```

### Node References

Extend existing node from parent DTS:

```dts
&uart1 {
    status = "okay";  /* Override parent's "disabled" */
};
```

### Labels

Create reference point:

```dts
label: node@address {
    /* ... */
};

/* Later reference */
&label {
    /* extend */
};
```

## AM335x Specifics

### Control Module

Base: `0x44E10000`
Pad control: `0x44E10800 + offset`

Configures pin function (UART/I2C/SPI/GPIO) and electrical properties (pull-up/down, slew rate).

### Pinmux

Each pin can have 8 functions (MUX_MODE 0-7):

```dts
0x980 0x30  /* offset value */
```

- Offset: Which pin (from AM335x TRM)
- Value: MUX_MODE + pull + slew config

### Memory Map

| Peripheral | Base Address | DTS Node |
|------------|--------------|----------|
| UART0 | 0x44E09000 | `uart0` (console) |
| UART1 | 0x48022000 | `uart1` |
| I2C0 | 0x44E0B000 | `i2c0` (PMIC only) |
| I2C1 | 0x4802A000 | `i2c1` |
| I2C2 | 0x4819C000 | `i2c2` |
| SPI0 | 0x48030000 | `spi0` |
| SPI1 | 0x481A0000 | `spi1` |

## References

- Linux DT Specification: https://devicetree.org/specifications/
- Kernel DT docs: `linux/Documentation/devicetree/`
- AM335x TRM Chapter 9: Control Module (pinmux)
- AM335x TRM Chapter 2: Memory Map
- BBB SRM Rev C Section 8: Connectors
