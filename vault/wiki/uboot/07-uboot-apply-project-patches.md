---
title: Apply Project U-Boot Patches
last_updated: 2026-05-04
category: bootloader
---

# Apply Project U-Boot Patches

U-Boot patches are managed by the Yocto recipe and applied automatically by
BitBake during `do_patch`. No manual `git apply` needed.

## Patch Location

```text
meta-bbb/recipes-bsp/u-boot/files/
├── 0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch
├── 0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch
└── 0003-am335x-board-set-usbnet-devaddr-from-efuse.patch
```

Declared in `meta-bbb/recipes-bsp/u-boot/u-boot-bbb_2022.07.bb`:

```bitbake
SRC_URI += " \
    file://0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch \
    file://0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch \
    file://0003-am335x-board-set-usbnet-devaddr-from-efuse.patch \
"
```

## Build (patches applied automatically)

```bash
make yocto-stage-image STORAGE_BASE=/mnt/data/beaglebone-bsp
```

BitBake fetches U-Boot at `SRCREV = e092e325...`, applies all patches via quilt,
then builds `MLO` and `u-boot.img`.

## Verify Patches Applied

```bash
# Check quilt applied all patches
bitbake -c devshell u-boot-bbb
# inside devshell:
quilt applied
```

Expected:

```text
0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch
0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch
0003-am335x-board-set-usbnet-devaddr-from-efuse.patch
```

## Add a New Patch

See [[04-uboot-patches.md]] — "Add or Regenerate a Patch" section.

## Common Mistakes

| Mistake                            | Fix                                                              |
| ---------------------------------- | ---------------------------------------------------------------- |
| Writing patch context manually     | Use `git format-patch` — quilt context must match exactly        |
| Putting patch in `patches/u-boot/` | Put in `meta-bbb/recipes-bsp/u-boot/files/` and add to SRC_URI  |
| Applying patch before Yocto build  | Not needed — BitBake handles it                                  |
