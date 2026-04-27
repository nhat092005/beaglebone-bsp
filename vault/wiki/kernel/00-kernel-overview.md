---
title: Kernel Overview
tags:
  - linux
  - kernel
  - am335x
last_updated: 2026-04-26
category: kernel
---

# Kernel Overview

## Version

**Pinned version:** `v5.10.253` (Linux 5.10.y LTS)

Stored in `${BSP_ROOT}/linux/VERSION-PIN`.

## BSP Kernel Files

| Path | Purpose |
| --- | --- |
| `linux/configs/` | Config fragments |
| `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts` | Custom DTS built by `make dtbs` |
| `linux/dts/` | Project DTS copy used by packaging flows |
| `linux/patches/` | Backported stable patches |

## Build Artifacts

| Artifact                      | Location              | Description        |
| ----------------------------- | --------------------- | ------------------ |
| `zImage`                      | `build/kernel/zImage` | Linux kernel image |
| `am335x-boneblack-custom.dtb` | `build/kernel/`       | Device tree blob   |

## Prerequisites

- Preferred Docker image through `Makefile`: `bbb-builder`
- Cross-compiler: `arm-linux-gnueabihf-`
- Architecture: `arm`

Direct `scripts/build.sh` execution uses the same default Docker image,
`bbb-builder`. Override `DOCKER_IMAGE` only for custom tags.

## References

- Linux kernel: https://kernel.org
- AM335x TRM SPRUH73Q §9 (Control Module), §2 (Memory Map)
- BBB SRM Rev C §8 (Connectors)
