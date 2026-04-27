---
title: U-Boot Workflow Overview
last_updated: 2026-04-26
category: bootloader
---

# U-Boot Workflow Overview

Reference: U-Boot v2022.07 | AM335x TRM SPRUH73Q §26.1 | Diátaxis tutorial.

This page is the short path through the project U-Boot workflow. Detailed clone,
defconfig, patch, build, and runtime notes live in the numbered pages below.

By the end you will have `MLO` and `u-boot.img` in `build/uboot/` built from `am335x_boneblack_custom_defconfig` with TFTP boot support.

## Prerequisites

- Preferred current path: build through the top-level `Makefile`
  (`make docker`, then `make uboot`).
- `Makefile` defaults to Docker image `bbb-builder`.
- Direct `scripts/build.sh` defaults to the same Docker image, `bbb-builder`.
- Repo root at `$BSP_ROOT` (e.g. `/home/user/beaglebone-bsp`)

## Current Project Path

```bash
cd "$BSP_ROOT"
make docker
make uboot
ls -lh build/uboot/MLO build/uboot/u-boot.img
```

`make uboot` runs `scripts/build.sh uboot` inside the Makefile Docker image and
copies successful artifacts to `build/uboot/`.

## Steps

| Step | Topic                                    | File                                             |
| ---- | ---------------------------------------- | ------------------------------------------------ |
| 1-2  | Clone at v2022.07, create working branch | 02-uboot-clone                                   |
| 3    | Custom defconfig                         | 03-uboot-custom-defconfig                        |
| 4-6  | Write/apply project patches              | 04-uboot-patches, 07-uboot-apply-project-patches |
| 7-9  | Build, verify, re-apply                  | 05-uboot-build-verify                            |

## Output Artifacts

| Artifact     | Location                 | Size                   |
| ------------ | ------------------------ | ---------------------- |
| `MLO`        | `build/uboot/MLO`        | 64–128 KiB (fits SRAM) |
| `u-boot.img` | `build/uboot/u-boot.img` | FIT image              |

## Quick Reference

| Task                | Command                                                |
| ------------------- | ------------------------------------------------------ |
| Verify tag          | `git -C u-boot describe --tags --exact-match HEAD`     |
| Check MLO           | `stat -c '%s' u-boot/MLO` → 64000–131072               |
| Build               | `make uboot`                                           |
| Direct script build | `DOCKER_IMAGE=bbb-builder bash scripts/build.sh uboot` |
