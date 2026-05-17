---
name: embedded-c-patterns
description: Use when writing or reviewing beaglebone-bsp C code for kernel drivers, U-Boot, FreeRTOS tasks, IRQ safety, MMIO, or DMA.
---

Use project kernel style and embedded safety rules:

- Prefer `devm_*` for kernel driver resources.
- Propagate negative errno values and keep cleanup paths explicit.
- Use `dev_err/dev_warn/dev_info/dev_dbg` instead of raw `printk` in drivers.
- Use `ioread*` and `iowrite*` for MMIO; document register offsets.
- Do not sleep in IRQ/atomic context.
- Protect IRQ-shared data with IRQ-safe locking.
- Include `of_match_table`, `MODULE_DEVICE_TABLE`, `MODULE_LICENSE`, and useful module metadata.
- For FreeRTOS, prefer static task stacks and ISR-safe APIs such as `xQueueSendFromISR`.
- Verify with checkpatch, cppcheck, targeted build, and runtime load/unload checks when available.
