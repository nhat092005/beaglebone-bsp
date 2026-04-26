---
title: Build zImage and DTB
tags:
  - linux
  - kernel
  - build
date: 2026-04-26
category: kernel
---

# Build zImage and DTB

## Current Project Build

```bash
cd "${BSP_ROOT}"
make kernel
```

Current `scripts/build.sh kernel` behavior:

1. Generates `omap2plus_defconfig`.
2. Merges `linux/configs/reproducible.config` if present.
3. Builds `zImage`, DTBs, and modules.
4. Copies artifacts to `build/kernel/`.

Expected artifacts:

```bash
ls -lh build/kernel/zImage build/kernel/am335x-boneblack-custom.dtb
```

Important current gap:

- `linux/configs/boneblack-custom.config` exists, but `make kernel` does not
  merge it today.
- Use the manual full-custom workflow below when validating GPIO/I2C/PWM/HWMON
  config symbols.

## Manual Full-Custom Build

```bash
cd "${BSP_ROOT}/linux"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- omap2plus_defconfig
scripts/kconfig/merge_config.sh -m .config configs/boneblack-custom.config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules
```

## Direct Docker Build

Prefer `make kernel`. If bypassing the `Makefile`, align the Docker image
explicitly and run the same config setup:

```bash
cd "${BSP_ROOT}"
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace/linux \
  bbb-builder \
  bash -c "make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- omap2plus_defconfig
           scripts/kconfig/merge_config.sh -m .config configs/reproducible.config
           make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc) zImage dtbs modules"
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
| Copied zImage | `build/kernel/zImage` |
| Copied DTB | `build/kernel/am335x-boneblack-custom.dtb` |

## Build Time

Expected: < 20 minutes on 4-core host

## Common Errors

### "dtc: command not found"

Rebuild the project Docker image with `make docker`; `device-tree-compiler`
belongs in `docker/Dockerfile`, not as an ad hoc install inside a disposable
container.

### "No rule to make target 'zImage'"

```bash
# Need arm toolchain
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
```

## References

- Kernel ARM booting: Documentation/arm/booting.rst
