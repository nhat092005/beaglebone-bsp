---
name: bsp-debugging
description: "Use for BeagleBone BSP runtime diagnosis: kernel oops, probe failure, DT bind failure, serial console logs, U-Boot boot issues, Yocto runtime failures, or FreeRTOS QEMU debug."
---

Start with evidence:

- Capture exact log lines and command history.
- Classify the failure: oops/panic, probe failure, DT mismatch, module load, U-Boot, Yocto runtime, or hardware/serial.
- Check recent git changes before proposing fixes.
- Prefer non-destructive probes first.
- For live board work, require explicit user approval before serial, SSH, deploy, or flash.

Useful checks:

- `dmesg | tail -100`
- `lsmod`, `modinfo`, `insmod`, `rmmod`
- `/proc/device-tree`, `/sys/bus/*/devices`, `/sys/kernel/debug/pinctrl`
- `scripts/debug/bbb-uart.py capture-boot`, `send`, `scan`, `replay`
- U-Boot `printenv`, `bdinfo`, `mmc part`, `tftpboot`

Return root cause confidence, evidence chain, and next verification step.
