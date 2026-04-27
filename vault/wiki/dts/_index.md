---
title: Device Tree (DTS)
last_updated: 2026-04-27
category: dts
status: Complete
---

# Device Tree (DTS)

Device Tree Source documentation for BeagleBone Black custom board.

## Workflow

| #   | Topic                    | File                          |
| --- | ------------------------ | ----------------------------- |
| 00  | DTS Overview             | [[00-dts-overview.md]]        |
| 01  | Custom DTS Details       | [[01-custom-dts.md]]          |
| 02  | Pinmux and Pin Mapping   | [[02-pinmux-and-pins.md]]     |
| 03  | Validation (RULE-5)      | [[03-validation.md]]          |
| 04  | dtschema Integration     | [[04-dtschema.md]]            |

## Quick Reference

```bash
# Compile DTB
make kernel

# Validate DTS
make dtbs-check

# Full 4-step validation
make verify-dts
```

## Current Custom DTS

File: `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts`

Peripherals enabled:
- UART1 (P9.24/26)
- I2C2 (P9.19/20)
- SPI1 (P9.28/29/30/31)
- EHRPWM1A (P9.14)
- GPIO button (P9.12)

Strategy: Non-conflict pin allocation (I2C2 + SPI1 instead of I2C1 + SPI0)
