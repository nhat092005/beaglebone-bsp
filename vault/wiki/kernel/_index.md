---
title: Kernel
last_updated: 2026-04-26
category: kernel
status: In Progress
---

# Kernel (Linux 5.10.y)

Linux kernel build workflow for BeagleBone Black BSP.

## Workflow

| #   | Topic               | File                         |
| --- | ------------------- | ---------------------------- |
| 00  | Overview            | [[00-kernel-overview.md]]    |
| 01  | Clone at v5.10.253  | [[01-kernel-clone.md]]       |
| 02  | Generate Config     | [[02-kernel-config.md]]      |
| 03  | Build zImage & DTB  | [[03-kernel-build.md]]       |
| 04  | Apply Patches       | [[04-kernel-patches.md]]     |
| 05  | Verify Artifacts    | [[05-kernel-verify.md]]      |
| 06  | Device Tree (DTS)   | [[06-device-tree.md]]        |
| 07  | Reproducible Builds | [[07-reproducible-build.md]] |

## Quick Reference

```bash
# Clone kernel
cd linux && git fetch --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git refs/tags/v5.10.253 && git checkout FETCH_HEAD

# Build through project entry point
make kernel

# Verify
ls -lh build/kernel/zImage build/kernel/am335x-boneblack-custom.dtb
```

Current caveat: `make kernel` merges `linux/configs/reproducible.config` but
does not merge `linux/configs/boneblack-custom.config`. Use 03-kernel-build.md for the manual full-custom workflow.
