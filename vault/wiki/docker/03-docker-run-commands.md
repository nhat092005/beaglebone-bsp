---
title: Run Commands Inside Container
tags:
  - docker
  - container
  - run
date: 2026-04-18
category: docker
---

# Run Commands Inside Container

## General Pattern

```bash
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace \
  beaglebone-bsp-builder:1.0 \
  <command>
```

## Build U-Boot

```bash
docker run --rm \
  -v "${BSP_ROOT}/u-boot:/workspace/u-boot" \
  -w /workspace/u-boot \
  beaglebone-bsp-builder:1.0 \
  bash -c "make CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_custom_defconfig && make CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc)"
```

## Build Kernel

```bash
docker run --rm \
  -v "${BSP_ROOT}/linux:/workspace/linux" \
  -w /workspace/linux \
  beaglebone-bsp-builder:1.0 \
  bash -c "make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc) zImage dtbs"
```

## Run Static Analysis

### Shellcheck on scripts

```bash
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace \
  beaglebone-bsp-builder:1.0 \
  shellcheck scripts/*.sh
```

### Kernel checkpatch

```bash
docker run --rm \
  -v "${BSP_ROOT}/linux:/workspace/linux" \
  -w /workspace/linux \
  beaglebone-bsp-builder:1.0 \
  ./scripts/checkpatch.pl --strict -f drivers/led-gpio/led-gpio.c
```

### Cppcheck

```bash
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace \
  beaglebone-bsp-builder:1.0 \
  cppcheck --enable=all apps/sensor-monitor/sensor-monitor.c
```

## Interactive Shell

```bash
docker run --rm -it \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace \
  beaglebone-bsp-builder:1.0 \
  bash
```

## Build Out-of-Tree Driver

```bash
docker run --rm \
  -v "${BSP_ROOT}/linux:/workspace/linux" \
  -v "${BSP_ROOT}/drivers/led-gpio:/workspace/driver" \
  -w /workspace/driver \
  beaglebone-bsp-builder:1.0 \
  make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_DIR=/workspace/linux -C /workspace/driver
```
