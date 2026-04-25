---
title: Docker Overview
tags:
  - docker
  - container
date: 2026-04-18
category: docker
---

# Docker Overview

## Why Docker for BSP?

- **Reproducible builds** — same environment across machines
- **Isolated** — no host toolchain pollution
- **Consistent** — digest-pinned base image
- **Portable** — works on any x86_64 host with Docker

## BSP Docker Image

**Image name:** `beaglebone-bsp-builder:1.0`

**Base:** Ubuntu 22.04 (digest-pinned)

**Includes:**

- `gcc-arm-linux-gnueabihf=4:11.2.0-1ubuntu1`
- `device-tree-compiler`, `u-boot-tools`
- `bc`, `bison`, `flex`, `libssl-dev`, `libelf-dev`
- `kmod`, `cpio`, `rsync`, `git`
- `shellcheck`, `cppcheck`
- User: `builder` (UID 1000)
- ENV: `CROSS_COMPILE=arm-linux-gnueabihf-`, `ARCH=arm`

## Usage Pattern

```bash
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace \
  beaglebone-bsp-builder:1.0 \
  <command>
```

## References

- Docker docs: https://docs.docker.com/engine/install/ubuntu/
- Reproducible Builds: https://reproducible-builds.org/docs/definition/
