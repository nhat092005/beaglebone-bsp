---
title: U-Boot Patch Queue
last_updated: 2026-04-28
category: bootloader
---

# U-Boot Patch Queue

Step 4-6 of U-Boot workflow.

Project U-Boot patches live in the Yocto recipe and are applied automatically by BitBake:

```text
meta-bbb/recipes-bsp/u-boot/files/
├── 0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch
├── 0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch
└── 0003-am335x-board-set-usbnet-devaddr-from-efuse.patch
```

Wired into `meta-bbb/recipes-bsp/u-boot/u-boot-bbb_2022.07.bb` via `SRC_URI`.
BitBake applies them in order during `do_patch` using quilt.

This page records what each project patch changes.

## Patch 0001: USB gadget Ethernet DM_ETH teardown fix

Modify `drivers/usb/gadget/ether.c` so `_usb_eth_halt()` does not release the UDC device when `CONFIG_DM_ETH=y`.

Reason: with driver model Ethernet, `usb_ether` is a child of the UDC device. Calling `usb_gadget_release(0)` from the child stop path can remove/free the child before `eth_halt()` finishes updating the Ethernet uclass private state.

```c
/*
 * With DM_ETH the UDC owns this usb_ether device. Releasing the UDC
 * here recursively removes this child while eth_halt() still updates
 * its uclass private state after ->stop() returns.
 */
if (!CONFIG_IS_ENABLED(DM_ETH))
	usb_gadget_release(0);
```

## Patch 0002: USB RNDIS TFTP boot environment

Modify `include/configs/am335x_evm.h` to add a `tftp_boot` env variable. Load addresses `0x82000000` (`zImage`) and `0x88000000` (`dtb`) are inside the BeagleBone Black DDR range.

The important detail is that `tftp_boot` must be a complete Linux handoff, not
only a pair of TFTP downloads. TFTP only places bytes in RAM; it does not tell
Linux which UART to use or which root filesystem to mount. Therefore the script
sets `bootargs` immediately before `bootz`:

```text
console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
```

That command line matches this BSP's SD layout: UART0 console and ext4 rootfs on
partition 2. Without it, a valid kernel and DTB can still appear to stop at
`Starting kernel ...` because Linux was entered without the expected console/root
configuration.

Add before the `#define CONFIG_EXTRA_ENV_SETTINGS` block:

```c
#define TFTP_BOOT_ENV                                       \
	"serverip=192.168.7.1\0"                            \
	"ipaddr=192.168.7.2\0"                              \
	"tftp_boot="                                        \
	"setenv ethact usb_ether; "                         \
	"setenv ethrotate no; "                             \
	"setenv bootargs console=ttyO0,115200n8 "           \
	"root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait; " \
	"tftpboot ${loadaddr} zImage; "                     \
	"tftpboot ${fdtaddr} am335x-boneblack-custom.dtb; " \
	"bootz ${loadaddr} - ${fdtaddr}\0"
```

Add `TFTP_BOOT_ENV \` to `CONFIG_EXTRA_ENV_SETTINGS`:

```c
#define CONFIG_EXTRA_ENV_SETTINGS \
	DEFAULT_LINUX_BOOT_ENV \
	TFTP_BOOT_ENV \
	...
```

## Add or Regenerate a Patch

From `beaglebone-bsp/u-boot` after editing source:

```bash
# Stage the change, commit temporarily, generate patch
git add <changed-file>
git commit -m "description of fix"
git format-patch HEAD~1 --stdout > /tmp/NNNN-description.patch

# Reset temp commit, copy patch to recipe
git reset HEAD~1
git checkout -- <changed-file>
cp /tmp/NNNN-description.patch ../meta-bbb/recipes-bsp/u-boot/files/
```

Then add the filename to `SRC_URI` in `u-boot-bbb_2022.07.bb`.

## Verify

```bash
git describe --tags --exact-match HEAD  # expect: v2022.07
grep -q 'tftp_boot' include/configs/am335x_evm.h && echo OK  # expect: OK
```
