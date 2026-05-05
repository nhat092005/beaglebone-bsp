---
name: uboot-reasoning
description: Reasoning scaffold for U-Boot work. Covers SPL vs full U-Boot, defconfig/fragment strategy, boot environment, bootcmd, zImage+DTB load, TFTP, and the handoff contract with the kernel. Use when editing U-Boot sources/patches, tuning boot env, debugging boot-stage hangs.
origin: custom-bsp
---

# U-Boot Reasoning — AM335x / BeagleBone Black

A reasoning scaffold. For detailed sequences see `vault/wiki/uboot/00-boot-flow.md`, `vault/wiki/uboot/01-uboot-workflow.md`, and `vault/wiki/uboot/_index.md`.

## Boot stages

```
ROM (invisible)
  → SPL (MLO)                    ← small, fits in on-chip SRAM
     → initializes DDR3, loads u-boot.img from MMC FAT
        → U-Boot (full)
           → reads environment (FAT "uEnv.txt" or saved env)
              → runs bootcmd → loads zImage + DTB → bootz
                 → Linux kernel starts
```

Size matters at each stage:

- **SPL** fits in AM335x on-chip SRAM (~109 KB public). Overflow = silent failure.
- **U-Boot** loads into DDR3 at `0x80800000` by default.
- **zImage** loads at `0x82000000`, DTB at `0x88000000`.

## defconfig strategy

- Base: `am335x_boneblack_custom_defconfig` (this project's custom). Derived from upstream `am335x_boneblack_vboot_defconfig`.
- **NEVER** edit `arch/arm/dts/am335x-boneblack.dts` in the U-Boot tree. Use the project U-Boot patches (`u-boot/patches/`) and re-apply on source updates.
- Fragment pattern: enable/disable `CONFIG_*` symbols via defconfig rebuild, not ad-hoc `.config` edits.

## Environment + bootcmd

The `bootcmd` runs at boot if autoboot isn't interrupted. Typical sequence:

```
load mmc 0:1 $fdtaddr /boot/am335x-boneblack-custom.dtb
load mmc 0:1 $loadaddr /boot/zImage
bootz $loadaddr - $fdtaddr
```

Environment storage order (BBB):

1. `uEnv.txt` on boot partition (editable from host SD mount).
2. Saved env in MMC (`saveenv` command).
3. Defaults compiled into U-Boot (`include/configs/am335x_evm.h`).

Later entries override earlier only for unset vars. `uEnv.txt` is the easy knob.

## TFTP boot (dev-loop)

```
setenv serverip 192.168.7.1       ← host via USB gadget
setenv ipaddr 192.168.7.2
tftp $loadaddr zImage
tftp $fdtaddr am335x-boneblack-custom.dtb
bootz $loadaddr - $fdtaddr
```

Host side: `scripts/deploy.sh` drops artifacts at TFTP root. See `AGENTS.md` for `make deploy` usage.

## Handoff contract with kernel

U-Boot → kernel passes (via ATAG-less DTB mechanism on ARM):

- `r0` = 0
- `r1` = machine ID (ignored when DTB is present)
- `r2` = DTB physical address

DTB must be at an address the kernel can read BEFORE its own MMU is set up. That's why `$fdtaddr` is a low, unrelocated address.

## Common boot-stage failures

| Symptom                                                | Stage        | Likely cause                                                                  |
| ------------------------------------------------------ | ------------ | ----------------------------------------------------------------------------- |
| No UART output at all                                  | Pre-SPL      | Bad power / oscillator / eMMC; check 3.3 V, SYS_CLKIN                         |
| "U-Boot SPL" printed, hang                             | SPL          | DDR3 init failed (timing), or `u-boot.img` missing from MMC                   |
| "U-Boot 2022.07" printed, hang at "Hit any key" forever | U-Boot       | `bootdelay` too high or env corrupt                                           |
| "Starting kernel..." then nothing                      | Kernel early | Wrong `$fdtaddr`, DTB at bad address, or kernel `console=` wrong              |
| Kernel prints but no `[    0.000000]` timestamp        | earlycon     | `CONFIG_SERIAL_8250_OMAP_TTYO_FIXUP` or `earlycon` DT missing                 |

## Verify

```bash
# Version string
version

# Environment
printenv
printenv bootcmd

# Memory map
bdinfo

# MMC contents
mmc list
mmc part
ls mmc 0:1 /
```

## See also

- `.claude/rules/bsp-context.md` — boot sequence summary.
- `.claude/rules/tech-defaults.md` — U-Boot defconfig name.
- `vault/wiki/uboot/00-boot-flow.md` — stage-by-stage boot detail.
- `vault/wiki/uboot/01-uboot-workflow.md` — how to build / patch U-Boot.
- `vault/wiki/uboot/_index.md` — boot-env knowledge base.
- `skills/karpathy-discipline/` — think-before-patching scaffold.
