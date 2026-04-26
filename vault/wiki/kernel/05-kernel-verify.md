---
title: Verify Kernel Artifacts
tags:
  - linux
  - kernel
  - verify
last_updated: 2026-04-26
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
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace/linux \
  bbb-builder \
  make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs

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

`make kernel` already copies the two expected files:

```text
build/kernel/zImage
build/kernel/am335x-boneblack-custom.dtb
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
