---
title: Pinmux and Pin Mapping Reference
tags:
  - pinmux
  - pin-mapping
  - control-module
last_updated: 2026-04-27
category: dts
---

# Pinmux and Pin Mapping Reference

## Control Module Pad Register

**Base address:** `0x44E10000`
**Pad control base:** `0x44E10800`

### Bitfield Layout

| Bit | Field | Values | Description |
|-----|-------|--------|-------------|
| [31:7] | Reserved | - | Must be 0 |
| [6] | SLEWCTRL | 0=Fast, 1=Slow | Slew rate |
| [5] | RXACTIVE | 0=Output, 1=Input | Input buffer |
| [4] | PULLTYPESEL | 0=Pulldown, 1=Pullup | Pull type |
| [3] | PULLUDEN | 0=Enabled, 1=Disabled | Pull enable |
| [2:0] | MUXMODE | 0-7 | Function select |

**Source:** AM335x TRM SPRUH73Q Chapter 9.3.1

### MUX_MODE Selection

| MUXMODE | Function |
|---------|----------|
| 0 | Primary (matches pad name) |
| 1-6 | Alternate functions |
| 7 | GPIO mode |

## Common Config Values

| Hex | Binary | Use |
|-----|--------|-----|
| `0x00` | `00000000` | UART TX: output, no pull, mode 0 |
| `0x06` | `00000110` | PWM: output, mode 6 |
| `0x13` | `00010011` | SPI MISO/CS: input, pulldown, mode 3 |
| `0x30` | `00110000` | UART RX: input, pullup, mode 0 |
| `0x33` | `00110011` | SPI SCLK/MOSI: input, pullup, mode 3 |
| `0x37` | `00110111` | GPIO input: input, pullup, mode 7 |
| `0x73` | `01110011` | I2C: input, pullup, slow slew, mode 3 |

## Complete Pin Map (Custom DTS)

| Pin | Ball Name | Offset | Function | MUX | Config | Peripheral |
|-----|-----------|--------|----------|-----|--------|------------|
| P9.12 | gpmc_ben1 | `0x878` | GPIO1_28 | 7 | `0x37` | GPIO button |
| P9.14 | gpmc_a2 | `0x848` | EHRPWM1A | 6 | `0x06` | PWM output |
| P9.19 | uart1_rtsn | `0x97c` | I2C2_SCL | 3 | `0x73` | I2C2 |
| P9.20 | uart1_ctsn | `0x978` | I2C2_SDA | 3 | `0x73` | I2C2 |
| P9.24 | uart1_txd | `0x984` | UART1_TXD | 0 | `0x00` | UART1 |
| P9.26 | uart1_rxd | `0x980` | UART1_RXD | 0 | `0x30` | UART1 |
| P9.28 | mcasp0_ahclkr | `0x99c` | SPI1_CS0 | 3 | `0x13` | SPI1 |
| P9.29 | mcasp0_fsx | `0x994` | SPI1_D0 | 3 | `0x33` | SPI1 |
| P9.30 | mcasp0_axr0 | `0x998` | SPI1_D1 | 3 | `0x13` | SPI1 |
| P9.31 | mcasp0_aclkx | `0x990` | SPI1_SCLK | 3 | `0x33` | SPI1 |

**Source:** `linux/include/dt-bindings/pinctrl/am33xx.h`

## Pin Conflict Matrix

| Pin Group | Option A | Option B | Conflict? |
|-----------|----------|----------|-----------|
| P9.17/18 | I2C1 (mode 2) | SPI0 (mode 0) | Yes |
| P9.21/22 | UART2 (mode 1) | SPI0 (mode 0) | Yes |
| P9.19/20 | I2C2 (mode 3) | - | Safe |
| P9.24/26 | UART1 (mode 0) | - | Safe |
| P9.28-31 | SPI1 (mode 3) | - | Safe |
| P9.14 | EHRPWM1A (mode 6) | - | Safe |

**Strategy:** I2C2 + SPI1 avoids all conflicts with base DTS.

## Peripheral Base Addresses

| Peripheral | Base Address | Domain | Status |
|------------|--------------|--------|--------|
| UART0 | `0x44E09000` | L4_WKUP | Console (base DTS) |
| UART1 | `0x48022000` | L4_PER | Custom DTS |
| I2C0 | `0x44E0B000` | L4_WKUP | **PMIC ONLY** |
| I2C1 | `0x4802A000` | L4_PER | Available |
| I2C2 | `0x4819C000` | L4_PER | Custom DTS |
| SPI0 | `0x48030000` | L4_PER | Available |
| SPI1 | `0x481A0000` | L4_PER | Custom DTS |
| EHRPWM1 | `0x48302000` | L4_PER | Custom DTS |
| GPIO0 | `0x44E07000` | L4_WKUP | Base DTS |
| GPIO1 | `0x4804C000` | L4_PER | Button (custom DTS) |

**Source:** AM335x TRM Chapter 2 Memory Map

## CRITICAL: I2C0 Reservation

**DO NOT USE I2C0 (0x44E0B000) FOR ANY NON-PMIC DEVICES**

I2C0 is hardwired to TPS65217 PMIC on BeagleBone Black.

- TPS65217 controls board power rails (3.3V, 1.8V, 1.5V, 1.1V)
- Wrong I2C transactions can brick the board
- I2C0 is NOT exposed on P8/P9 headers

**Source:** BBB SRM Rev C Section 6.4

**Use I2C1 or I2C2 for sensors/peripherals.**

## EHRPWM Notes

- 3 modules (EHRPWM0/1/2), each with 2 channels (A/B)
- Custom DTS uses EHRPWM1 channel A on P9.14
- Kernel driver: `drivers/pwm/pwm-tiehrpwm.c`
- Compatible: `ti,am33xx-ehrpwm`

### Userspace Control

```bash
echo 0 > /sys/class/pwm/pwmchip0/export
echo 40000 > /sys/class/pwm/pwmchip0/pwm0/period
echo 20000 > /sys/class/pwm/pwmchip0/pwm0/duty_cycle
echo 1 > /sys/class/pwm/pwmchip0/pwm0/enable
```

## GPIO Calculation

GPIO number = bank * 32 + line

Example: GPIO1_28 = 1 * 32 + 28 = sysfs number 60

## DTS Syntax

### Pinmux Group

```dts
&am33xx_pinmux {
    label: node_name {
        pinctrl-single,pins = <
            offset value  /* Pin - Function, ModeN */
        >;
    };
};
```

### Peripheral Enable

```dts
&peripheral {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinmux_label>;
};
```

## Base DTS Warnings

Warnings from `am33xx-l4.dtsi`, `am33xx-clocks.dtsi` are upstream issues.

Safe to ignore if:
- No errors mention custom DTS file
- DTB compiles successfully
- `dtc` exit code is 0

## References

- AM335x TRM SPRUH73Q Chapter 9: Control Module
- AM335x TRM SPRUH73Q Chapter 2: Memory Map
- BBB SRM Rev C Section 8: Connectors
- Kernel: `linux/include/dt-bindings/pinctrl/am33xx.h`
- Custom DTS: `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts`
