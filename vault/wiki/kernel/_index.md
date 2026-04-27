---
title: Kernel
last_updated: 2026-04-27
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
| 06  | DTS-Kernel Integration | [[06-dts-kernel-integration.md]] |
| 07  | Reproducible Builds | [[07-reproducible-build.md]] |

## Quick Reference

```bash
# Clone kernel
cd linux && git fetch --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git refs/tags/v5.10.253 && git checkout FETCH_HEAD

# Build through project entry points
make kernel-dev KERNEL_RECONFIGURE=1

# Verify host-side gates
make kernel-verify
```

Current layout uses an out-of-tree dev build in `build/linux/dev/` and exports
artifacts to `build/kernel/`. See `05-kernel-verify.md` for the canonical
Phase 3 verification flow.
