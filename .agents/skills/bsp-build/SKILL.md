---
name: bsp-build
description: Use when the user asks to build beaglebone-bsp targets or diagnose which build target to run for kernel, U-Boot, Yocto, drivers, or apps.
---

Detect target from user input first, otherwise from changed paths:

- `linux/` or `drivers/`: `make kernel` or `make driver DRIVER=<name>`
- `u-boot/`: `make uboot`
- `meta-bbb/`: `make yocto-shell` then `make bitbake BB=<recipe>` or the matching Make target
- `scripts/control/`: run shell syntax and the smallest relevant Make target

Do not flash, deploy, SSH, serial, or touch live board hardware without explicit user approval.
On failure, isolate the first failing command, collect the exact error, and use the `build-resolver` agent only for that target.
