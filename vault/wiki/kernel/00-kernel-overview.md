---
title: Kernel Overview
tags:
  - linux
  - kernel
  - am335x
date: 2026-04-19
category: kernel
---

# Kernel Overview

## Version

**Pinned version:** `v5.10.253` (Linux 5.10.y LTS)

Stored in `${BSP_ROOT}/linux/VERSION-PIN`.

## BSP Kernel Files

| Path             | Purpose                                    |
| ---------------- | ------------------------------------------ |
| `linux/configs/` | Config fragments (boneblack-custom.config) |
| `linux/dts/`     | Device Tree Source overlays                |
| `linux/patches/` | Backported stable patches                  |

## Build Artifacts

| Artifact                      | Location              | Description        |
| ----------------------------- | --------------------- | ------------------ |
| `zImage`                      | `build/kernel/zImage` | Linux kernel image |
| `am335x-boneblack-custom.dtb` | `build/kernel/`       | Device tree blob   |

## Prerequisites

- Docker image: `beaglebone-bsp-builder:1.0`
- Cross-compiler: `arm-linux-gnueabihf-`
- Architecture: `ARM`

## References

- Linux kernel: https://kernel.org
- AM335x TRM SPRUH73Q §9 (Control Module), §2 (Memory Map)
- BBB SRM Rev C §8 (Connectors)
