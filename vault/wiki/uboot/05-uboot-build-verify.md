---
title: U-Boot Build & Verify
last_updated: 2026-04-18
category: bootloader
---

# U-Boot Build & Verify

Step 7-9 of U-Boot workflow.

## Step 7 — Build inside Docker

The `beaglebone-bsp-builder:1.0` container has the cross-compiler:

```bash
cd "$BSP_ROOT"

docker run --rm \
  -v "${BSP_ROOT}/u-boot:/workspace/u-boot" \
  -w /workspace/u-boot \
  beaglebone-bsp-builder:1.0 bash -c "
    make CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_custom_defconfig
    make CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc)
  "
```

Expected tail:

```
  MKIMAGE u-boot.img
  CAT     u-boot-dtb.bin
  COPY    u-boot.dtb
  MKIMAGE u-boot-dtb.img
  COPY    u-boot.bin
```

## Step 8 — Verify artifacts

```bash
# Inspect u-boot.img
docker run --rm \
  -v "${BSP_ROOT}/u-boot:/workspace/u-boot" \
  -w /workspace/u-boot \
  beaglebone-bsp-builder:1.0 \
  ./tools/mkimage -l u-boot.img | grep -E '(Architecture: ARM|OS:.*U-Boot)'
# expect: two matching lines

# Check MLO size within SRAM limit (109 KiB per TRM §26.1.8.5)
stat -c '%s' u-boot/MLO
# expect: 64000–131072
```

## Copy to build directory

```bash
mkdir -p "${BSP_ROOT}/build/uboot"
cp u-boot/MLO u-boot/u-boot.img "${BSP_ROOT}/build/uboot/"
ls -lh "${BSP_ROOT}/build/uboot/"
```

## Step 9 — Re-apply patches after clean clone

If `u-boot/` is re-cloned:

```bash
cd u-boot
git apply patches/0001-boneblack-tftp-boot-env.patch
git apply patches/0002-boneblack-reduce-boot-delay.patch
```

Then build as in Step 7.

## Troubleshooting

| Issue        | Cause               | Fix                                                |
| ------------ | ------------------- | -------------------------------------------------- |
| MLO > 131072 | SPL too large       | Reduce features in defconfig                       |
| Build fails  | Wrong CROSS_COMPILE | Check `arm-linux-gnueabihf-` prefix                |
| No MLO       | Missing config      | Run `make am335x_boneblack_custom_defconfig` first |
