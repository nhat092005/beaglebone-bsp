---
title: U-Boot Build & Verify
last_updated: 2026-04-26
category: bootloader
---

# U-Boot Build & Verify

Step 7-9 of U-Boot workflow.

## Step 7 — Build Through Makefile

Use the repository entry point:

```bash
cd "$BSP_ROOT"
make docker
make uboot
```

`Makefile` defaults to Docker image `bbb-builder`. The `uboot` target runs
`bash scripts/build.sh uboot` inside the container. The script then runs:

```bash
make CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_custom_defconfig
make CROSS_COMPILE=arm-linux-gnueabihf- -j"$(nproc)"
```

Expected build output includes:

```
  MKIMAGE u-boot.img
  CAT     u-boot-dtb.bin
  COPY    u-boot.dtb
  MKIMAGE u-boot-dtb.img
  COPY    u-boot.bin
```

## Step 8 — Verify artifacts

```bash
ls -lh build/uboot/MLO build/uboot/u-boot.img

# Inspect u-boot.img with the tool built in the U-Boot tree.
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace/u-boot \
  bbb-builder \
  ./tools/mkimage -l u-boot.img | grep -E '(Architecture: ARM|OS:.*U-Boot)'
# expect: two matching lines

# Check MLO size within SRAM limit (109 KiB per TRM §26.1.8.5)
stat -c '%s' u-boot/MLO
# expect: 64000–131072
```

## Direct Script Build

Prefer `make uboot`. If running `scripts/build.sh` directly from the host, align
the image name with the Makefile default:

```bash
DOCKER_IMAGE=bbb-builder bash scripts/build.sh uboot
```

Direct script execution defaults to `bbb-builder`; set `DOCKER_IMAGE` only for a
custom image tag.

## Step 9 — Re-apply Patches After Clean Clone

If `u-boot/` is re-cloned:

```bash
cd u-boot
while read patch; do
  git apply "../patches/u-boot/v2022.07/${patch}"
done < ../patches/u-boot/v2022.07/series
```

Then build as in Step 7.

## Troubleshooting

| Issue        | Cause               | Fix                                                |
| ------------ | ------------------- | -------------------------------------------------- |
| MLO > 131072 | SPL too large       | Reduce features in defconfig                       |
| Build fails  | Wrong CROSS_COMPILE | Check `arm-linux-gnueabihf-` prefix                |
| No MLO       | Missing config      | Run `make am335x_boneblack_custom_defconfig` first |
