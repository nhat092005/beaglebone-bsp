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
- Never modify upstream dtsi/dts files. Add/enable nodes in the project overlay (`linux/dts/am335x-boneblack-custom.dts`) only. Enable with `status = "okay"` in the overlay; leave upstream files untouched.
- `reg` addresses must come from the AM335x TRM, not guesses.
- Pinctrl: define groups in `am33xx-clocks.dtsi` style and reference by name in device node.
- Include `#address-cells` and `#size-cells` on every bus node.

## FreeRTOS / OpenAMP

- Use `xQueueSendFromISR` / `xSemaphoreGiveFromISR` variants inside ISR context -- never the non-ISR versions.
- Pre-allocate task stacks statically where possible (`StaticTask_t` + `StackType_t` array).
- Document task priorities and stack sizes in a comment block at the top of each task file.
- Always define `vApplicationStackOverflowHook` for stack overflow detection during development.
- Project target: QEMU `lm3s6965evb` (Stellaris Cortex-M3), standalone FreeRTOS. No OpenAMP, no PRU, no RPMsg in this project.

## Yocto / BitBake

- Every recipe needs `LICENSE` and `LIC_FILES_CHKSUM` -- no exceptions.
- Use `${D}`, `${S}`, `${WORKDIR}`, `${B}` -- never hardcode paths.
- Out-of-tree kernel modules: use `inherit module` -- do not write manual install steps.
- bbappend files: always use `FILESEXTRAPATHS:prepend := "${THISDIR}/files:"` -- never `=`.
- `SRC_URI` network entries (git://, https://): always pin with `SRCREV` + `LIC_FILES_CHKSUM`. Local `file://` patches do NOT require checksums.
- Separate kernel module recipe from userspace app recipe -- do not combine.

## Shell Scripts

- Shebang: `#!/usr/bin/env bash`
- Safety: `set -euo pipefail` at the top of every script.
- Quote all variables: `"${VAR}"` not `$VAR`.
- Check for root before using `sudo`: `[ "$(id -u)" -ne 0 ] && sudo ...`.
- No hardcoded absolute paths -- use `${SCRIPT_DIR}` relative to the script location.

## Static Analysis Gates (RULE-3 — all 8 required before a driver is done)

Every out-of-tree kernel module must pass all 8 gates:

1. `checkpatch.pl --strict -f <file.c>` → `total: 0 errors, 0 warnings, 0 checks`
2. `make C=2 CF="-D__CHECK_ENDIAN__"` (sparse) → 0 warnings
3. `insmod` succeeds, `dmesg` shows no errors
4. `/sys/` or `/dev/` entry appears as expected
5. Relevant kselftest or kunit test passes
6. 100× consecutive `insmod` / `rmmod` loop exits 0
7. Kernel built with `CONFIG_PROVE_LOCKING=y` — no lockdep splat
8. Kernel built with `CONFIG_KASAN=y` — no KASAN report

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

## Python (helper scripts only)

- Target: Python 3.10+. Type hints: use `list[T]`, `dict[K, V]` PEP 585 syntax. Import `annotations` from `__future__` for forward references.
- Every top-level script: `#!/usr/bin/env python3` + module docstring.
- CLI: `argparse` with subcommands. Emit JSON to stdout for machine-readable results, human-readable progress to stderr.
- Exceptions: exit with `sys.exit("error: ...")` for CLI user errors; raise for programmer bugs.
- No `requests`-style heavy deps unless justified. Use stdlib + `pyserial` + `PyYAML` only.
- Keep `.py` files under 250 LOC each. Split if longer.
- No `os.system` / `subprocess.shell=True`. Use list-form `subprocess.run([...])`.
- Format: PEP 8. Line length 88 (Black default). Run `python3 -m compileall scripts/` to syntax-check.
