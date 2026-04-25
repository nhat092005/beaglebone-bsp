---
title: Verify Kernel Artifacts
tags:
  - linux
  - kernel
  - verify
date: 2026-04-19
category: kernel
---

# Verify Kernel Artifacts

## Check zImage

```bash
# Size >= 2 MiB
ls -lh build/kernel/zImage
stat -c '%s' build/kernel/zImage
# expect: >= 2097152
```

## Check DTB

```bash
# File exists
ls -lh build/kernel/am335x-boneblack-custom.dtb
```

## Compile Test DTB

```bash
docker run --rm \
  -v "${BSP_ROOT}/linux:/workspace/linux" \
  -w /workspace/linux \
  beaglebone-bsp-builder:1.0 \
  make ARCH=arm am335x-boneblack-custom.dtb

# expect: no errors
```

## Verify DTB Schema

```bash
cd linux

# Run dtbs_check
make ARCH=arm dtbs_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/ 2>&1 | \
  grep -E 'am335x-boneblack-custom.*(error|warning)'
# expect: 0 matches
```

## Verify with W=1

```bash
cd linux

make ARCH=arm W=1 dtbs 2>&1 | grep -c 'am335x-boneblack-custom.*warning'
# expect: 0
```

## Copy to Build Directory

```bash
mkdir -p build/kernel

cp linux/arch/arm/boot/zImage build/kernel/
cp linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb build/kernel/

ls -lh build/kernel/
```

## Verify on Target (requires hardware)

```bash
# After TFTP boot
# Check kernel version
uname -r
# expect: 5.10.253-bbb-custom+

# Check device tree
cat /proc/device-tree/model
# expect: AM335x BeagleBoard Black
```

## References

- DT binding: https://www.devicetree.org/specifications/
