---
title: Custom DTS Details
tags:
  - device-tree
  - am335x-boneblack-custom
  - peripherals
last_updated: 2026-04-27
category: dts
---

# Custom DTS - am335x-boneblack-custom.dts

## Overview

File: `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts`

Extends `am335x-boneblack.dts` with project-specific peripherals using non-conflict pin allocation strategy.

## Peripherals Enabled

| Peripheral | Pins | Function |
|------------|------|----------|
| UART1 | P9.24 (TX), P9.26 (RX) | Serial console / debug |
| I2C2 | P9.19 (SCL), P9.20 (SDA) | Sensor bus |
| SPI1 | P9.28/29/30/31 | SPI peripherals |
| EHRPWM1A | P9.14 | PWM output (fan control) |
| GPIO button | P9.12 | User input |

## Pin Allocation Strategy

**Goal:** Avoid conflicts with base DTS peripherals

**Choices:**
- **I2C2** instead of I2C1 → frees SPI0 pins (P9.17/18)
- **SPI1** instead of SPI0 → no conflict with UART2/I2C
- **UART1** on dedicated pins → no conflict
- **SPI0 pins** (P9.17/18/21/22) remain free for future use

**Why this matters:**
- Base DTS may enable HDMI (uses some pins)
- Avoid pin conflicts = stable hardware
- Future expansion possible

## UART1

### Configuration

```dts
&uart1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&uart1_pins>;
};
```

### Pinmux

```dts
uart1_pins: pinmux_uart1_pins {
    pinctrl-single,pins = <
        0x980 0x30  /* P9.26 uart1_rxd  - INPUT + PULLUP, MUX_MODE0 */
        0x984 0x00  /* P9.24 uart1_txd  - OUTPUT, MUX_MODE0 */
    >;
};
```

### Hardware

| Signal | Ball | Pad Offset | Pin | Config |
|--------|------|------------|-----|--------|
| RXD | uart1_rxd | 0x980 | P9.26 | INPUT + PULLUP |
| TXD | uart1_txd | 0x984 | P9.24 | OUTPUT |

### Runtime

```bash
# Device node
ls -l /dev/ttyO1

# Test
echo "test" > /dev/ttyO1
cat /dev/ttyO1

# Probe log
dmesg | grep 48022000.serial
```

## I2C2

### Configuration

```dts
&i2c2 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&i2c2_pins>;
    clock-frequency = <100000>;
};
```

### Pinmux

```dts
i2c2_pins: pinmux_i2c2_pins {
    pinctrl-single,pins = <
        /* SLEWCTRL(slow) + RXACTIVE + PULLUP, MUX_MODE3 = i2c2 */
        0x978 0x73  /* P9.20 uart1_ctsn - I2C2_SDA, MUX_MODE3 */
        0x97c 0x73  /* P9.19 uart1_rtsn - I2C2_SCL, MUX_MODE3 */
    >;
};
```

### Hardware

| Signal | Ball | Pad Offset | Pin | Config |
|--------|------|------------|-----|--------|
| SCL | uart1_rtsn | 0x97c | P9.19 | SLEWCTRL + RXACTIVE + PULLUP |
| SDA | uart1_ctsn | 0x978 | P9.20 | SLEWCTRL + RXACTIVE + PULLUP |

**Note:** I2C requires slow slew rate (bit 6 = 1)

### Runtime

```bash
# Scan bus
i2cdetect -y 2

# Probe log
dmesg | grep 4819c000.i2c
```

### I2C0 Warning

**NEVER use I2C0 (0x44E0B000) for sensors/peripherals**

I2C0 is hardwired to TPS65217 PMIC. Wrong transactions can brick the board.

## SPI1

### Configuration

```dts
&spi1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&spi1_pins>;
};
```

### Pinmux

```dts
spi1_pins: pinmux_spi1_pins {
    pinctrl-single,pins = <
        /* SPI1: MUX_MODE3 on mcasp0 pads */
        0x990 0x33  /* P9.31 mcasp0_aclkx  - SPI1_SCLK, INPUT + PULLUP, MUX_MODE3 */
        0x994 0x33  /* P9.29 mcasp0_fsx    - SPI1_D0 (MOSI), INPUT + PULLUP, MUX_MODE3 */
        0x998 0x13  /* P9.30 mcasp0_axr0   - SPI1_D1 (MISO), INPUT + PULLDOWN, MUX_MODE3 */
        0x99c 0x13  /* P9.28 mcasp0_ahclkr - SPI1_CS0, INPUT + PULLDOWN, MUX_MODE3 */
    >;
};
```

### Hardware

| Signal | Ball | Pad Offset | Pin | Config |
|--------|------|------------|-----|--------|
| SCLK | mcasp0_aclkx | 0x990 | P9.31 | INPUT + PULLUP |
| MOSI (D0) | mcasp0_fsx | 0x994 | P9.29 | INPUT + PULLUP |
| MISO (D1) | mcasp0_axr0 | 0x998 | P9.30 | INPUT + PULLDOWN |
| CS0 | mcasp0_ahclkr | 0x99c | P9.28 | INPUT + PULLDOWN |

### Runtime

```bash
# Device node
ls -l /dev/spidev1.0

# Probe log
dmesg | grep 481a0000.spi
```

## EHRPWM1A

### Configuration

```dts
&ehrpwm1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&ehrpwm1_pins>;
};
```

### Pinmux

```dts
ehrpwm1_pins: pinmux_ehrpwm1_pins {
    pinctrl-single,pins = <
        /* AM335x TRM: gpmc_a2 pad, MUX_MODE6 = ehrpwm1A */
        0x848 0x06  /* P9.14 gpmc_a2 - EHRPWM1A, MUX_MODE6 */
    >;
};
```

### Hardware

| Signal | Ball | Pad Offset | Pin | MUX_MODE |
|--------|------|------------|-----|----------|
| EHRPWM1A | gpmc_a2 | 0x848 | P9.14 | 6 |

### Runtime

```bash
# PWM sysfs
ls /sys/class/pwm/pwmchip*/

# Enable PWM
echo 0 > /sys/class/pwm/pwmchip0/export
echo 40000 > /sys/class/pwm/pwmchip0/pwm0/period
echo 20000 > /sys/class/pwm/pwmchip0/pwm0/duty_cycle
echo 1 > /sys/class/pwm/pwmchip0/pwm0/enable

# Probe log
dmesg | grep ehrpwm
```

## GPIO Button

### Configuration

```dts
/ {
    gpio_keys: gpio_keys {
        compatible = "gpio-keys";
        pinctrl-names = "default";
        pinctrl-0 = <&gpio_btn_pins>;

        button {
            label = "user-button";
            linux,code = <KEY_PROG1>;
            gpios = <&gpio1 28 GPIO_ACTIVE_LOW>;
            wakeup-source;
        };
    };
};
```

### Pinmux

```dts
gpio_btn_pins: pinmux_gpio_btn_pins {
    pinctrl-single,pins = <
        /* INPUT + PULLUP + RXACTIVE, MUX_MODE7 = gpio mode */
        0x878 0x37  /* P9.12 gpmc_ben1 - GPIO1_28, MUX_MODE7 */
    >;
};
```

### Hardware

| Signal | Ball | Pad Offset | Pin | GPIO |
|--------|------|------------|-----|------|
| Button | gpmc_ben1 | 0x878 | P9.12 | GPIO1_28 |

**GPIO calculation:** GPIO1_28 = bank 1 × 32 + line 28 = sysfs number 60

### Runtime

```bash
# Input device
cat /proc/bus/input/devices | grep -A5 "user-button"

# Test with evtest
evtest /dev/input/event0

# Probe log
dmesg | grep gpio-keys
```

## Compatible Strings

| String | Binding | Usage |
|--------|---------|-------|
| `gpio-keys` | `Documentation/devicetree/bindings/input/gpio-keys.yaml` | GPIO button |
| `ti,omap3-uart` | `Documentation/devicetree/bindings/serial/8250_omap.yaml` | UART1 (inherited) |
| `ti,omap4-i2c` | `Documentation/devicetree/bindings/i2c/i2c-omap.yaml` | I2C2 (inherited) |
| `ti,omap4-mcspi` | `Documentation/devicetree/bindings/spi/spi-omap2-mcspi.yaml` | SPI1 (inherited) |
| `ti,am33xx-ehrpwm` | `Documentation/devicetree/bindings/pwm/pwm-tiehrpwm.yaml` | EHRPWM1 (inherited) |

## Validation

```bash
# Compile
make kernel

# Validate schema
make dtbs-check

# Check warnings
cd linux && make ARCH=arm W=1 dtbs 2>&1 | grep am335x-boneblack-custom

# Full 4-step validation
make verify-dts
```

## References

- Custom DTS source: `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts`
- Base DTS: `linux/arch/arm/boot/dts/am335x-boneblack.dts`
- AM335x TRM Chapter 9: Control Module
- BBB SRM Rev C Section 8: Connectors
