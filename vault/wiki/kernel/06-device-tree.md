---
title: Device Tree Source (DTS)
tags:
  - device-tree
  - dts
  - dtb
  - pinmux
date: 2026-04-19
category: kernel
---

# Device Tree Source (DTS)

## DTS Hierarchy

The kernel ships three relevant DTS files:

```
am33xx.dtsi                  ← SoC: all peripherals, disabled
  └─ am335x-bone-common.dtsi ← board common: eMMC, USB, PMIC, USR LEDs
       └─ am335x-boneblack.dts ← final board: enables HDMI, eMMC
            └─ am335x-boneblack-custom.dts  ← THIS FILE: adds peripherals
```

The custom file only **extends** the upstream tree using `#include`. It never modifies upstream nodes unless overriding a property.

---

## Control Module Pinmux

### Control Module

AM335x Control Module (base `0x44E10000`) contains pad control registers. Each pad register is 32 bits:

```
Control Module base: 0x44E10000
Pad register offset: from TRM SPRUH73Q §9.3
Full pad address:  0x44E10000 + offset
```

All pad registers use `pinctrl-single` driver. Entries are `<offset value>` pairs:

```dts
0x848 0x06   /* offset=0x848, value=0x06 */
```

### Pad Register Bit Layout

| Bits  | Field     | Description                           |
| ----- | --------- | ------------------------------------- |
| [2:0] | MUXMODE   | Function select (0–7)                 |
| [3]   | PULLUDDIS | 0 = pull enabled, 1 = pull disabled   |
| [4]   | PULLUP_EN | 0 = pull-down, 1 = pull-up            |
| [5]   | RXACTIVE  | 1 = input buffer enabled              |
| [6]   | SLEWCTRL  | 1 = slow slew rate (required for I2C) |

### Common Pad Values

| Value                | Hex    | Meaning                            |
| -------------------- | ------ | ---------------------------------- |
| MUX_MODE0, OUT       | `0x00` | Function 0, output                 |
| MUX_MODE0, IN+PULLUP | `0x30` | Function 0, input + pull-up        |
| MUX_MODE1, IN+PULLUP | `0x31` | Function 1, input + pull-up        |
| MUX_MODE1, OUT       | `0x01` | Function 1, output                 |
| MUX_MODE2, I2C       | `0x72` | Function 2, slow + pull-up + input |
| MUX_MODE6, OUT       | `0x06` | Function 6, output (EHRPWM)        |
| MUX_MODE7, GPIO      | `0x37` | GPIO mode, input + pull-up         |

### Pin Map

| Peripheral | P8/P9 | Signal    | Offset  | Value  | MUX |
| ---------- | ----- | --------- | ------- | ------ | --- |
| UART1 RX   | P9.26 | uart1_rxd | `0x980` | `0x30` | 0   |
| UART1 TX   | P9.24 | uart1_txd | `0x984` | `0x00` | 0   |
| I2C1 SDA   | P9.18 | spi0_d1   | `0x958` | `0x72` | 2   |
| I2C1 SCL   | P9.17 | spi0_cs0  | `0x95c` | `0x72` | 2   |
| EHRPWM1A   | P9.14 | gpmc_a2   | `0x848` | `0x06` | 6   |
| GPIO BTN   | P9.12 | gpmc_be1n | `0x878` | `0x37` | 7   |

---

## Node Examples

### UART1

```dts
&uart1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&uart1_pins>;
};
```

UART1 (`0x48022000`) is in upstream with `status = "disabled"`. Setting `status = "okay"` causes kernel to bind `omap-serial`.

**Device node:** `/dev/ttyO1`

---

### I2C1 with TMP102

```dts
&i2c1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&i2c1_pins>;
    clock-frequency = <100000>;

    tmp102: sensor@48 {
        compatible = "ti,tmp102";
        reg = <0x48>;
    };
};
```

I2C1 base: `0x4802A000`. `clock-frequency = <100000>` = 100 kHz.

TMP102 wiring: `ADD0` to GND → I2C address `0x48`. `compatible = "ti,tmp102"` matches driver.

**WARNING:** I2C0 (`0x44E0B000`) is reserved for TPS65217 PMIC. Never add custom devices to I2C0.

---

### I2C2

```dts
&i2c2 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&i2c2_pins>;
    clock-frequency = <100000>;
};
```

I2C2 base: `0x4819C000`. P9.19 (SCL) and P9.20 (SDA) use MUX_MODE3.

---

### EHRPWM1A

```dts
&ehrpwm1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&ehrpwm1_pins>;
};
```

eHRPWM1 base: `0x48302200`. Channel A exposed on P9.14 via pad GPMC_A2 (offset `0x848`, MUX_MODE6).

`compatible = "ti,am33xx-ehrpwm"` matches `drivers/pwm/pwm-tiehrpwm.c`.

**On-target:**

```bash
ls /sys/class/pwm/          # expect: pwmchipN
echo 0 > /sys/class/pwm/pwmchip0/export
echo 40000 > /sys/class/pwm/pwmchip0/pwm0/period   # 25 kHz
echo 20000 > /sys/class/pwm/pwmchip0/pwm0/duty_cycle  # 50%
echo 1 > /sys/class/pwm/pwmchip0/pwm0/enable
```

---

### GPIO Button

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

**GPIO1_28 = P9.12:** `gpio = 1×32 + 28 = 60` → `/sys/class/gpio/gpio60`

`GPIO_ACTIVE_LOW`: pressing button pulls P9.12 to GND.

`linux,code = <KEY_PROG1>` = 148. Monitor with `evtest /dev/input/event0`.

`wakeup-source`: button can resume system from suspend.

---

## Pin Conflict: SPI0 vs I2C1 vs UART2

Shared pins:

| Pin   | SPI0 (MUX0) | I2C1 (MUX2) | UART2 (MUX1) |
| ----- | ----------- | ----------- | ------------ |
| P9.17 | SPI0_CS0    | I2C1_SCL    | —            |
| P9.18 | SPI0_D1     | I2C1_SDA    | —            |
| P9.21 | SPI0_D0     | —           | UART2_TX     |
| P9.22 | SPI0_SCLK   | —           | UART2_RX     |

Only one function active at boot. The custom DTS enables I2C1 and UART2.

---

## How to Add New I2C Device

**Goal:** add SHT31 humidity sensor at address `0x44` on I2C1.

1. **Check address conflicts:**

   ```bash
   i2cdetect -y 1
   ```

2. **Find compatible string:**

   ```bash
   grep -r 'sht31\|sht3x' linux/Documentation/devicetree/bindings/
   ```

3. **Add child node to `&i2c1`:**

   ```dts
   &i2c1 {
       sht31: humidity@44 {
           compatible = "sensirion,sht3x";
           reg = <0x44>;
       };
   };
   ```

4. **Enable driver:**

   ```
   CONFIG_SENSORS_SHT3x=m
   ```

5. **Validate:**
   ```bash
   cpp -nostdinc -I linux/arch/arm/boot/dts -I linux/include \
       -undef -D__DTS__ linux/arch/arm/boot/dts/am335x-boneblack-custom.dts | \
     dtc -I dts -O dtb -o /tmp/test.dtb -
   ```

---

## How to Add New GPIO Output (LED)

**Goal:** add LED on P8.12 (GPIO1_12).

1. **Find pad offset:** P8.12 = `gpmc_ad12`, offset `0x030`.

2. **Add pinmux group:**

   ```dts
   ext_led_pins: pinmux_ext_led_pins {
       pinctrl-single,pins = <
           0x030 0x07   /* P8.12 — GPIO1_12, OUTPUT */
       >;
   };
   ```

3. **Add leds node:**

   ```dts
   / {
       leds_ext: leds_external {
           compatible = "gpio-leds";
           pinctrl-names = "default";
           pinctrl-0 = <&ext_led_pins>;

           ext_led0 {
               label = "ext:green:status";
               gpios = <&gpio1 12 GPIO_ACTIVE_HIGH>;
               default-state = "off";
           };
       };
   };
   ```

4. **Validate:**
   ```bash
   cd linux && make ARCH=arm dtbs
   ls arch/arm/boot/dts/am335x-boneblack-custom.dtb
   ```

---

## Compile DTB

### Kernel Build

```bash
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
# produces: arch/arm/boot/dts/am335x-boneblack-custom.dtb
```

### Standalone Validation

```bash
cpp -nostdinc \
    -I linux/arch/arm/boot/dts \
    -I linux/include \
    -undef -D__DTS__ \
    linux/arch/arm/boot/dts/am335x-boneblack-custom.dts | \
  dtc -I dts -O dtb -o /tmp/custom.dtb -

echo $?   # expect: 0
```

---

## On-Target Verification

```bash
# I2C bus 1 present
ls /dev/i2c-1

# TMP102 at 0x48
i2cdetect -y 1
# expect: address 48 shown

# EHRPWM pwmchip registered
ls /sys/class/pwm/
# expect: pwmchipN directory

# GPIO button
cat /proc/bus/input/devices | grep -A3 "user-button"

# dmesg probes
dmesg | grep -E 'omap_i2c|tmp102|ehrpwm|gpio-keys'
```

### dmesg Probe Verification

```bash
# UART
dmesg | grep "48022000.serial\|48024000.serial"
# expect: omap_uart 48022000.serial: no wakeirq for uart1

# I2C
dmesg | grep "4802a000.i2c\|4819c000.i2c"
# expect: omap_i2c 4802a000.i2c: bus 1 rev0.11 at 100 kHz

# TMP102
dmesg | grep tmp102
# expect: tmp102 1-0048: configured in extended mode

# EHRPWM
dmesg | grep "ehrpwm\|48302"
# expect: 48302200.pwm: pwmchip registered

# GPIO keys
dmesg | grep "gpio-keys"
# expect: gpio-keys gpio_keys@0: user-button at gpio-1-28
```

### Per-Peripheral Test Commands

#### UART1 / UART2

```bash
ls /dev/ttyO*
# Loopback: connect P9.24 TX to P9.26 RX
stty -F /dev/ttyO1 115200 raw
echo "test" > /dev/ttyO1 && cat /dev/ttyO1
```

#### I2C1 — TMP102

```bash
i2cdetect -y 1
# expect: address 48 shown

i2cget -y 1 0x48 0x00 w
# raw temperature register

cat /sys/bus/i2c/devices/1-0048/hwmon/hwmon*/temp1_input
# millidegrees Celsius
```

#### GPIO LEDs

```bash
cat /sys/class/leds/beaglebone:green:usr0/trigger
echo none > /sys/class/leds/beaglebone:green:usr0/trigger
echo 1 > /sys/class/leds/beaglebone:green:usr0/brightness
echo 0 > /sys/class/leds/beaglebone:green:usr0/brightness
```

#### GPIO Button (P9.12 = GPIO1_28 = sysfs gpio60)

```bash
echo 60 > /sys/class/gpio/export
cat /sys/class/gpio/gpio60/value
echo 60 > /sys/class/gpio/unexport

cat /proc/bus/input/devices | grep -A5 "user-button"
```

#### EHRPWM1A

```bash
ls /sys/class/pwm/
CHIP=$(ls /sys/class/pwm/ | grep pwmchip | head -1)
echo 0 > /sys/class/pwm/${CHIP}/export
echo 40000 > /sys/class/pwm/${CHIP}/pwm0/period   # 25 kHz
echo 20000 > /sys/class/pwm/${CHIP}/pwm0/duty_cycle  # 50%
echo 1 > /sys/class/pwm/${CHIP}/pwm0/enable
```

---

## Compatible Strings and Binding YAMLs

Every `compatible` string used in the custom DTS:

| compatible string  | Binding YAML path                                        |
| ------------------ | -------------------------------------------------------- |
| `ti,tmp102`        | `Documentation/devicetree/bindings/trivial-devices.yaml` |
| `ti,am33xx-ehrpwm` | `Documentation/devicetree/bindings/pwm/pwm-tiehrpwm.txt` |
| `gpio-leds`        | `Documentation/devicetree/bindings/leds/leds-gpio.yaml`  |
| `gpio-keys`        | `Documentation/devicetree/bindings/input/gpio-keys.yaml` |

---

## I2C Bus Reservation — WARNING

**I2C0 (`0x44E0B000`) is RESERVED for PMIC (TPS65217).**

- I2C0 base: `0x44E0B000` (AM335x TRM SPRUH73Q §2.1)
- TPS65217 slave address: `0x24`
- Adding devices under `&i2c0` risks PMIC interference → power-rail misbehavior or board lockup
- Use I2C1 (`0x4802A000`) or I2C2 (`0x4819C000`) only

---

## Pin Mapping Complete

| Peripheral | P8/P9    | Signal     | Pad offset | MUX | Direction       | Pull |
| ---------- | -------- | ---------- | ---------- | --- | --------------- | ---- |
| UART1 RX   | P9.26    | uart1_rxd  | 0x980      | 0   | IN, UP          |
| UART1 TX   | P9.24    | uart1_txd  | 0x984      | 0   | OUT             |
| UART2 RX   | P9.22    | spi0_sclk  | 0x950      | 1   | IN, UP          |
| UART2 TX   | P9.21    | spi0_d0    | 0x954      | 1   | OUT             |
| I2C1 SDA   | P9.18    | spi0_d1    | 0x958      | 2   | IN/OUT, UP+SLOW |
| I2C1 SCL   | P9.17    | spi0_cs0   | 0x95c      | 2   | IN/OUT, UP+SLOW |
| I2C2 SDA   | P9.20    | uart1_ctsn | 0x978      | 3   | IN/OUT, UP+SLOW |
| I2C2 SCL   | P9.19    | uart1_rtsn | 0x97c      | 3   | IN/OUT, UP+SLOW |
| EHRPWM1A   | P9.14    | gpmc_a2    | 0x848      | 6   | OUT             |
| GPIO BTN   | P9.12    | gpmc_be1n  | 0x878      | 7   | IN, UP          |
| USR LED 0  | on-board | GPIO1_21   | —          | —   | OUT             |
| USR LED 1  | on-board | GPIO1_22   | —          | —   | OUT             |
| USR LED 2  | on-board | GPIO1_23   | —          | —   | OUT             |
| USR LED 3  | on-board | GPIO1_24   | —          | —   | OUT             |

---

## References

- Device Tree Specification: https://www.devicetree.org/specifications/
- Kernel DT bindings: `Documentation/devicetree/bindings/`
- AM335x TRM SPRUH73Q §9 (Control Module)
