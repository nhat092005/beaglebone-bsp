---
title: BeagleBone Black Hardware
last_updated: 2026-04-26
category: hardware-beagleboneblack
---

# BeagleBone Black Hardware

Hardware reference for BeagleBone Black (AM335x): bring-up wiring, header pinouts, and board schematic artifacts.

## Workflow

| #   | Topic                      | File                              |
| --- | -------------------------- | --------------------------------- |
| 00  | Bring-up Notes             | [[00-bringup-notes.md]]           |
| 01  | P8 Header Pinout (46 pins) | [[01-bbb_p8_header_pinout.md]]    |
| 02  | P9 Header Pinout (46 pins) | [[02-bbb_p9_header_pinout.md]]    |
| 03  | Board Schematic (JSON)     | `beaglebone_black_schematic.json` |

## How To Use This Section

- Start with `00-bringup-notes.md` for serial wiring and first power-on checks.
- Use `01-bbb_p8_header_pinout.md` and `02-bbb_p9_header_pinout.md` when mapping pins to peripherals.
- Use `beaglebone_black_schematic.json` for net-level trace/debug and connector-level verification.

## References

- BeagleBone Black System Reference Manual: https://github.com/beagleboard/beaglebone-black/wiki/System-Reference-Manual
- AM335x Technical Reference Manual (SPRUH73Q): https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
