---
description: Runtime debugging workflow for board bring-up and driver failures.
---

Use hypothesis-driven debugging for BSP failures.

Collect evidence first:

- serial/dmesg logs with the first failure signature
- module/device visibility (`lsmod`, `/sys`, `/dev`)
- relevant recent diffs in `linux/`, `drivers/`, `meta-bbb/`, `u-boot/`, `scripts/`

Classify and narrow:

- build-time vs runtime
- boot flow vs probe/binding vs runtime logic

Run one hypothesis test at a time; do not prescribe fixes before root-cause evidence.

Reference: `.opencode/skills/bsp-debugging/SKILL.md`.
