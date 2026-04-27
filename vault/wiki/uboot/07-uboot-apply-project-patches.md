---
title: Apply Project U-Boot Patches
last_updated: 2026-04-26
category: bootloader
---

# Apply Project U-Boot Patches

This page uses one standard layout: the BSP repo stores patches, and a separate clean U-Boot vendor clone receives them.

Do not store long-lived BSP patch queues inside a vendor source tree. Keep vendor trees disposable.

## Directory Layout

Use this layout:

```text
workspace/
├── beaglebone-bsp/
│   ├── patches/
│   │   ├── README.md
│   │   ├── u-boot/
│   │   │   └── v2022.07/
│   │   │       ├── series
│   │   │       ├── 0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch
│   │   │       └── 0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch
│   │   ├── linux/
│   │   │   └── README.md
│   │   └── yocto/
│   │       └── README.md
│   └── ...
└── u-boot-v2022.07/
    ├── drivers/
    ├── include/
    └── ...
```

Meaning:

- `beaglebone-bsp/` is this project repo.
- `beaglebone-bsp/patches/u-boot/v2022.07/` stores this project's U-Boot patches.
- `u-boot-v2022.07/` is a clean upstream/vendor U-Boot clone.
- `u-boot-v2022.07/` does not automatically contain the BSP patches. It gets them only after `git apply`.

## Patch Queue

Patch base:

```text
U-Boot v2022.07
```

Apply order lives in:

```text
beaglebone-bsp/patches/u-boot/v2022.07/series
```

Patch contents are documented in 04-uboot-patches.md.

These are raw `git diff` patches, so use:

```text
git apply
```

Do not use `git am` for these files.

## Clone Repos

Create workspace:

```bash
mkdir -p workspace
cd workspace
```

Clone this BSP repo:

```bash
git clone https://github.com/nhat092005/beaglebone-bsp.git beaglebone-bsp
```

Clone clean upstream U-Boot next to it:

```bash
git clone https://source.denx.de/u-boot/u-boot.git u-boot-v2022.07
cd u-boot-v2022.07
git checkout v2022.07
```

Confirm U-Boot base:

```bash
git status --short
git describe --tags --exact-match HEAD
```

Expected:

```text
v2022.07
```

## Apply Patches

From the clean U-Boot clone:

```bash
cd workspace/u-boot-v2022.07
```

Dry-run first:

```bash
while read patch; do
  git apply --check "../beaglebone-bsp/patches/u-boot/v2022.07/${patch}"
done < ../beaglebone-bsp/patches/u-boot/v2022.07/series
```

Apply:

```bash
while read patch; do
  git apply "../beaglebone-bsp/patches/u-boot/v2022.07/${patch}"
done < ../beaglebone-bsp/patches/u-boot/v2022.07/series
```

Check result:

```bash
git status --short
```

Expected:

```text
 M drivers/usb/gadget/ether.c
 M include/configs/am335x_evm.h
```

## Verify Content

Confirm the expected project edits exist:

```bash
grep -n "With DM_ETH" drivers/usb/gadget/ether.c
grep -n "CONFIG_IS_ENABLED(DM_ETH)" drivers/usb/gadget/ether.c
grep -n "TFTP_BOOT_ENV" include/configs/am335x_evm.h
grep -n "usb_ether" include/configs/am335x_evm.h
grep -n "am335x-boneblack-custom.dtb" include/configs/am335x_evm.h
```

## Build In BSP Project

The BSP build expects its configured U-Boot source tree. If using the project build flow, keep or sync the patched U-Boot tree as the project's `u-boot/` source, then build from BSP root:

```bash
cd workspace/beaglebone-bsp
make uboot
```

Expected artifacts:

```text
build/uboot/MLO
build/uboot/u-boot.img
```

## Runtime Smoke Test

Runtime TFTP/RNDIS environment checks and expected log lines are maintained in
06-uboot-tftp-rndis-boot.md.

## Roll Back

If patches were applied but not committed:

```bash
cd workspace/u-boot-v2022.07

git apply -R ../beaglebone-bsp/patches/u-boot/v2022.07/0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch
git apply -R ../beaglebone-bsp/patches/u-boot/v2022.07/0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch
```

Or reset vendor U-Boot back to the clean tag:

```bash
git reset --hard v2022.07
```

Use `reset --hard` only when local U-Boot changes are not needed.

## Common Mistakes

| Mistake                                     | Symptom                              | Fix                                               |
| ------------------------------------------- | ------------------------------------ | ------------------------------------------------- |
| Applying from `beaglebone-bsp/` root        | Path mismatch                        | `cd workspace/u-boot-v2022.07` first              |
| Using `git am`                              | Patch format error                   | Use `git apply`                                   |
| Applying to wrong U-Boot version            | Hunk failed                          | Checkout `v2022.07`                               |
| Applying same patch twice                   | Patch already applied / hunk failed  | Check `git status --short`                        |
| Committing inside vendor U-Boot by accident | Work lands in `u-boot-v2022.07/.git` | Keep project patches in `beaglebone-bsp/patches/` |

Short rule:

```text
beaglebone-bsp/patches/ = long-lived BSP patch archive
u-boot-v2022.07/        = disposable vendor source tree
git apply              = copy patch changes into vendor tree
```
