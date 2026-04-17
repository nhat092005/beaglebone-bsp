# Coding Standards — BeagleBone BSP

Specific coding rules for each layer of the BSP. Apply these alongside the general workflow rules in `workflow.md`.

## Kernel Drivers

- Always use `devm_*` for resource management. Never use raw `kzalloc` in probe without devm.
- Return negative errno values (`-ENOMEM`, `-EINVAL`). Never return positive error codes.
- Use `dev_err`, `dev_warn`, `dev_dbg` -- not bare `printk`. They include device context automatically.
- IRQ handlers must be fast: no sleeping, no `GFP_KERNEL` allocation, no mutex.
- Use `spin_lock_irqsave` for data shared between IRQ context and process context.
- MMIO: use `ioread32` / `iowrite32`. Never dereference a `void __iomem *` directly.
- Module must have `MODULE_LICENSE`, `MODULE_AUTHOR`, `MODULE_DESCRIPTION`.
- Use `goto err_label` pattern for cleanup on probe failure -- do not nest if-blocks.

## Device Tree

- `compatible` string must exactly match the driver's `of_match_table` entry -- character by character.
- Add `status = "disabled"` in SoC dtsi file. Enable with `status = "okay"` in board dts only.
- `reg` addresses must come from the AM335x TRM, not guesses.
- Pinctrl: define groups in `am33xx-clocks.dtsi` style and reference by name in device node.
- Include `#address-cells` and `#size-cells` on every bus node.

## FreeRTOS / OpenAMP

- Use `xQueueSendFromISR` / `xSemaphoreGiveFromISR` variants inside ISR context -- never the non-ISR versions.
- Pre-allocate task stacks statically where possible (`StaticTask_t` + `StackType_t` array).
- Document task priorities and stack sizes in a comment block at the top of each task file.
- Always define `vApplicationStackOverflowHook` for stack overflow detection during development.
- For RPMsg: use endpoint registration pattern from `OpenAMP/rpmsg.h`.

## Yocto / BitBake

- Every recipe needs `LICENSE` and `LIC_FILES_CHKSUM` -- no exceptions.
- Use `${D}`, `${S}`, `${WORKDIR}`, `${B}` -- never hardcode paths.
- Out-of-tree kernel modules: use `inherit module` -- do not write manual install steps.
- bbappend files: always use `FILESEXTRAPATHS:prepend := "${THISDIR}/files:"` -- never `=`.
- `SRC_URI` entries for local patches: include `sha256sum` checksum.
- Separate kernel module recipe from userspace app recipe -- do not combine.

## Shell Scripts

- Shebang: `#!/usr/bin/env bash`
- Safety: `set -euo pipefail` at the top of every script.
- Quote all variables: `"${VAR}"` not `$VAR`.
- Check for root before using `sudo`: `[ "$(id -u)" -ne 0 ] && sudo ...`.
- No hardcoded absolute paths -- use `${SCRIPT_DIR}` relative to the script location.

## General C / C++

- No magic numbers for register offsets -- use `#define` or `BIT(n)` macros.
- Busy-wait loops must have a timeout: never `while (!ready)` without an exit condition.
- Missing `volatile` on MMIO-mapped structs is a bug -- use `ioread`/`iowrite` instead.

## Comment Policy

Default: NO comments.

Only write a comment when one of these triggers applies:

1. Non-obvious hardware constraint (spec-mandated ordering, clock dependency, reset sequence)
2. Subtle invariant that a future reader could accidentally break
3. CRITICAL: code running in IRQ context or timing-sensitive sections
4. Section separator in files longer than 300 lines

Do NOT write comments to:

- Explain what the code is doing when the code is already clear
- Restate a register name or function name
- Describe a phase or task ("Phase 1", "TODO sprint")

BAD:

```c
/* Clear status register */
iowrite32(0xFFFFFFFF, base + REG_STAT);
```

GOOD:

```c
/* Spec requires writing all-ones to clear. Write-zero has no effect. */
iowrite32(0xFFFFFFFF, base + REG_STAT);
```

Logging: module name prefix is MANDATORY:
dev_dbg(dev, "[UART] init complete, baud=%d\n", baud);
