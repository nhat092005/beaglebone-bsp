---
title: U-Boot Clone v2022.07
last_updated: 2026-04-18
category: bootloader
---

# U-Boot Clone v2022.07

Step 1-2 of U-Boot workflow.

## Step 1 — Clone at pinned tag

Always clone at `v2022.07` exactly. The v2024.01 release removed the `MLO` single-stage target and breaks `am335x_evm_defconfig`.

```bash
cd "$BSP_ROOT"
git clone --depth 1 --branch v2022.07 https://github.com/u-boot/u-boot.git u-boot
```

Verify the clone is at the correct tag:

```bash
cd u-boot
git describe --tags --exact-match HEAD
# expect: v2022.07

git log -1 --format=%H v2022.07
# expect: e092e3250270a1016c877da7bdd9384f14b1321e
```

## Step 2 — Create working branch

Patches in this project are stored as `git format-patch` files. To generate them you need commits.

```bash
git checkout -b boneblack-dev v2022.07
git config user.name "BeagleBone BSP"
git config user.email "bsp@example.com"
```

> **Note:** After generating patches with `git format-patch`, reset HEAD back to `v2022.07` so that `git describe --exact-match HEAD` keeps returning `v2022.07`.
> Apply patches to the working tree only (via `git apply`, not `git am`) for day-to-day builds.

## Verify state

```bash
git describe --tags --exact-match HEAD
# expect: v2022.07

git log --oneline -1
# expect: e092e3250 u-boot v2022.07
```

## Troubleshooting

| Issue         | Cause                    | Fix                                        |
| ------------- | ------------------------ | ------------------------------------------ |
| Tag not found | Wrong repository URL     | Use `https://github.com/u-boot/u-boot.git` |
| Wrong tag     | Clone without `--branch` | Re-clone with `--branch v2022.07`          |
