---
title: Device Tree Source (DTS)
tags:
  - device-tree
  - dts
  - dtb
  - pinmux
last_updated: 2026-04-26
category: kernel
---

# Device Tree Source (DTS)

## Current Sources

The DTB built by the kernel comes from:

```text
linux/arch/arm/boot/dts/am335x-boneblack-custom.dts
```

It is registered in:

```text
linux/arch/arm/boot/dts/Makefile
```

The project also keeps a DTS copy under `linux/dts/` for packaging and BSP
reference flows. Keep both copies in sync when changing the custom board tree.

## DTS Hierarchy

```text
am33xx.dtsi
  -> am335x-bone-common.dtsi
     -> am335x-boneblack.dts
        -> am335x-boneblack-custom.dts
```

The custom DTS extends the upstream BeagleBone Black tree with these project
peripherals:

| Peripheral | Current status |
| --- | --- |
| UART1 | enabled on P9.24/P9.26 |
| UART2 | enabled on P9.21/P9.22 |
| I2C1 | enabled on P9.17/P9.18 with TMP102 at `0x48` |
| I2C2 | enabled on P9.19/P9.20 for expansion |
| EHRPWM1A | enabled on P9.14 |
| GPIO button | enabled on P9.12 as `gpio-keys` |
| SPI0 | not enabled because it conflicts with I2C1 and UART2 pins |

## Pinmux Basics

AM335x pad control registers live under the Control Module at `0x44E10000`.
The DTS uses `pinctrl-single,pins` entries in `<offset value>` form:

```dts
0x848 0x06   /* P9.14 gpmc_a2, MUX_MODE6 = ehrpwm1A */
```

Pad value bits:

| Bits | Field | Meaning |
| --- | --- | --- |
| `[2:0]` | `MUXMODE` | Function select, 0 through 7 |
| `[3]` | `PULLUDDIS` | `0` pull enabled, `1` pull disabled |
| `[4]` | `PULLUP_EN` | `0` pulldown, `1` pullup |
| `[5]` | `RXACTIVE` | `1` input buffer enabled |
| `[6]` | `SLEWCTRL` | `1` slow slew, required for I2C |

## Current Pin Map

| Peripheral | P8/P9 | Signal | Offset | Value | MUX |
| --- | --- | --- | --- | --- | --- |
| UART1 RX | P9.26 | uart1_rxd | `0x980` | `0x30` | 0 |
| UART1 TX | P9.24 | uart1_txd | `0x984` | `0x00` | 0 |
| UART2 RX | P9.22 | spi0_sclk | `0x950` | `0x31` | 1 |
| UART2 TX | P9.21 | spi0_d0 | `0x954` | `0x01` | 1 |
| I2C1 SDA | P9.18 | spi0_d1 | `0x958` | `0x72` | 2 |
| I2C1 SCL | P9.17 | spi0_cs0 | `0x95c` | `0x72` | 2 |
| I2C2 SDA | P9.20 | uart1_ctsn | `0x978` | `0x73` | 3 |
| I2C2 SCL | P9.19 | uart1_rtsn | `0x97c` | `0x73` | 3 |
| EHRPWM1A | P9.14 | gpmc_a2 | `0x848` | `0x06` | 6 |
| GPIO button | P9.12 | gpmc_be1n | `0x878` | `0x37` | 7 |

## Node Notes

### UART1 and UART2

`&uart1` and `&uart2` are defined in upstream `am33xx.dtsi` and disabled by
default. The custom DTS sets `status = "okay"` and attaches project pinmux
groups. Runtime devices should appear as `/dev/ttyO1` and `/dev/ttyO2`.

### I2C1 with TMP102

`&i2c1` is enabled at 100 kHz with:

```dts
tmp102: sensor@48 {
	compatible = "ti,tmp102";
	reg = <0x48>;
};
```

`I2C0` is reserved for the TPS65217 PMIC. Do not add project devices under
`&i2c0`; use I2C1 or I2C2.

### EHRPWM1A

`&ehrpwm1` is enabled with P9.14 pinmuxed to `ehrpwm1A`. The upstream node's
compatible string is `ti,am33xx-ehrpwm`, matched by
`drivers/pwm/pwm-tiehrpwm.c`.

### GPIO Button

The button is a root-level `gpio-keys` platform device:

```dts
/ {
	gpio_keys: gpio_keys {
		compatible = "gpio-keys";
		gpios = <&gpio1 28 GPIO_ACTIVE_LOW>;
	};
};
```

GPIO1_28 maps to legacy sysfs number `60` (`1 * 32 + 28`).

## Pin Conflict: SPI0 vs I2C1 vs UART2

| Pin | SPI0 MUX0 | I2C1 MUX2 | UART2 MUX1 |
| --- | --- | --- | --- |
| P9.17 | SPI0_CS0 | I2C1_SCL | - |
| P9.18 | SPI0_D1 | I2C1_SDA | - |
| P9.21 | SPI0_D0 | - | UART2_TX |
| P9.22 | SPI0_SCLK | - | UART2_RX |

The current custom DTS enables I2C1 and UART2, so SPI0 stays disabled.

## Compile DTB

Preferred project build:

```bash
cd "$BSP_ROOT"
make kernel
```

Kernel-only DTB build:

```bash
cd "$BSP_ROOT/linux"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
```

Standalone validation requires the C preprocessor because the DTS uses
`#include`:

```bash
cd "$BSP_ROOT"
cpp -nostdinc \
    -I linux/arch/arm/boot/dts \
    -I linux/include \
    -undef -D__DTS__ \
    linux/arch/arm/boot/dts/am335x-boneblack-custom.dts | \
  dtc -I dts -O dtb -o /tmp/am335x-boneblack-custom.dtb -
```

## On-Target Checks

```bash
# UARTs
ls -l /dev/ttyO*

# I2C1 TMP102 at 0x48
i2cdetect -y 1
modprobe tmp102
cat /sys/bus/i2c/devices/1-0048/hwmon/hwmon*/temp1_input

# I2C2 expansion bus
i2cdetect -y 2

# GPIO button
cat /proc/bus/input/devices | grep -A5 "user-button"

# EHRPWM1A
ls /sys/class/pwm/
```

Expected probe hints:

```bash
dmesg | grep "48022000.serial\|48024000.serial"
dmesg | grep "4802a000.i2c\|4819c000.i2c"
dmesg | grep "tmp102"
dmesg | grep "ehrpwm\|48302"
dmesg | grep "gpio-keys"
```

## Binding References

| Compatible string | Binding path under `linux/` |
| --- | --- |
| `ti,tmp102` | `Documentation/devicetree/bindings/trivial-devices.yaml` |
| `ti,am33xx-ehrpwm` | `Documentation/devicetree/bindings/pwm/pwm-tiehrpwm.txt` |
| `gpio-keys` | `Documentation/devicetree/bindings/input/gpio-keys.yaml` |
