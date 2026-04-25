---
title: Verify Artifacts
tags:
  - docker
  - verify
  - artifacts
date: 2026-04-18
category: docker
---

# Verify Artifacts

## Verify U-Boot Artifacts

### Check MLO size

MLO must be within AM335x internal SRAM limit (64000–131072 bytes per TRM SPRUH73Q §26.1.8.5).

```bash
docker run --rm \
  -v "${BSP_ROOT}/u-boot:/workspace/u-boot" \
  -w /workspace/u-boot \
  beaglebone-bsp-builder:1.0 \
  stat -c '%s' MLO

# expect: integer in range [64000, 131072]
# Phase 2 result: 103004 bytes ✓
```

### Inspect u-boot.img

v2022.07 uses FIT format, not legacy uImage.

```bash
docker run --rm \
  -v "${BSP_ROOT}/u-boot:/workspace/u-boot" \
  -w /workspace/u-boot \
  beaglebone-bsp-builder:1.0 \
  ./tools/mkimage -l u-boot.img | grep -E '(Architecture: ARM|OS:.*U-Boot)'

# expect: two matching lines
```

## Verify Kernel Artifacts

### Check zImage

```bash
ls -lh build/kernel/zImage

# expect: integer >= 2097152 (2 MiB)
```

### Check DTB

```bash
ls -lh build/kernel/am335x-boneblack-custom.dtb

# expect: file exists
```

### Compile test DTB

```bash
docker run --rm \
  -v "${BSP_ROOT}/linux:/workspace/linux" \
  -w /workspace/linux \
  beaglebone-bsp-builder:1.0 \
  make ARCH=arm am335x-boneblack-custom.dtb

# expect: no errors
```

## Copy Artifacts to Build Directory

### Create directories

```bash
mkdir -p build/{uboot,kernel}
```

### Copy U-Boot

```bash
cp u-boot/MLO u-boot/u-boot.img build/uboot/
ls -lh build/uboot/
```

### Copy Kernel

```bash
cp linux/arch/arm/boot/zImage build/kernel/
cp linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb build/kernel/
ls -lh build/kernel/
```

### Copy Modules (if built)

```bash
mkdir -p build/modules
cp -r linux/drivers/*/modules/*.ko build/modules/ 2>/dev/null || true
ls build/modules/
```
