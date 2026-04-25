---
title: U-Boot Development Workflow
last_updated: 2026-04-18
category: bootloader
---

# U-Boot Development Workflow

Reference: U-Boot v2022.07 | AM335x TRM SPRUH73Q §26.1 | Diátaxis tutorial.

This tutorial walks through the full U-Boot development cycle for this project: clone a specific release, customize it via defconfig and patches, build inside the project Docker container, and verify the output artifacts.

By the end you will have `MLO` and `u-boot.img` in `build/uboot/` built from `am335x_boneblack_custom_defconfig` with TFTP boot support.

## Prerequisites

- Docker image built: `docker images beaglebone-bsp-builder:1.0`
- Repo root at `$BSP_ROOT` (e.g. `/home/user/beaglebone-bsp`)

## Quick Start

```bash
# Clone → customize → build → verify (all 9 steps)
cd "$BSP_ROOT"
git clone --depth 1 --branch v2022.07 https://github.com/u-boot/u-boot.git u-boot

# Step 3: custom defconfig
cp u-boot/configs/am335x_evm_defconfig u-boot/configs/am335x_boneblack_custom_defconfig

# Apply patches and build (Steps 4-7)
git -C u-boot apply u-boot/patches/0001-boneblack-tftp-boot-env.patch
git -C u-boot apply u-boot/patches/0002-boneblack-reduce-boot-delay.patch

docker run --rm -v "${BSP_ROOT}/u-boot:/workspace/u-boot" -w /workspace/u-boot \
  beaglebone-bsp-builder:1.0 bash -c "
    make CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_custom_defconfig
    make CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc)
  "

# Verify
docker run --rm -v "${BSP_ROOT}/u-boot:/workspace/u-boot" -w /workspace/u-boot \
  beaglebone-bsp-builder:1.0 ./tools/mkimage -l u-boot.img | grep -E 'Architecture:'

# Copy to build dir
mkdir -p "${BSP_ROOT}/build/uboot"
cp u-boot/MLO u-boot/u-boot.img "${BSP_ROOT}/build/uboot/"
```

## Steps

| Step | Topic                                    | File                      |
| ---- | ---------------------------------------- | ------------------------- |
| 1-2  | Clone at v2022.07, create working branch | 02-uboot-clone            |
| 3    | Custom defconfig                         | 03-uboot-custom-defconfig |
| 4-6  | Write patches (TFTP, boot delay)         | 04-uboot-patches          |
| 7-9  | Build, verify, re-apply                  | 05-uboot-build-verify     |

## Output Artifacts

| Artifact     | Location                 | Size                   |
| ------------ | ------------------------ | ---------------------- |
| `MLO`        | `build/uboot/MLO`        | 64–128 KiB (fits SRAM) |
| `u-boot.img` | `build/uboot/u-boot.img` | FIT image              |

## Quick Reference

| Task       | Command                                                                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Verify tag | `git -C u-boot describe --tags --exact-match HEAD`                                                                                                     |
| Check MLO  | `stat -c '%s' u-boot/MLO` → 64000–131072                                                                                                               |
| Build      | `make -C u-boot CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_custom_defconfig && make -C u-boot CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc)` |
