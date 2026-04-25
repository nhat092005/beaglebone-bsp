---
title: Build zImage and DTB
tags:
  - linux
  - kernel
  - build
date: 2026-04-19
category: kernel
---

# Build zImage and DTB

## Build in Docker

```bash
cd "${BSP_ROOT}"

docker run --rm \
  -v "${BSP_ROOT}/linux:/workspace/linux" \
  -w /workspace/linux \
  beaglebone-bsp-builder:1.0 \
  bash -c "make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc) zImage dtbs"
```

## Build on Host (if toolchain installed)

```bash
cd linux

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
    -j$(nproc) \
    zImage dtbs
```

## Output Locations

| Artifact | Path                                                  |
| -------- | ----------------------------------------------------- |
| zImage   | `linux/arch/arm/boot/zImage`                          |
| DTB      | `linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb` |

## Build Time

Expected: < 20 minutes on 4-core host

## Common Errors

### "dtc: command not found"

```bash
# Install in container
docker run --rm beaglebone-bsp-builder:1.0 apt-get update && apt-get install -y device-tree-compiler
```

### "No rule to make target 'zImage'"

```bash
# Need arm toolchain
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
```

## References

- Kernel ARM booting: Documentation/arm/booting.rst
