---
title: U-Boot Patch Queue
last_updated: 2026-04-26
category: bootloader
---

# U-Boot Patch Queue

Step 4-6 of U-Boot workflow.

Current project patch archive lives outside the vendor U-Boot tree:

```text
patches/u-boot/v2022.07/
```

Apply order is stored in:

```text
patches/u-boot/v2022.07/series
```

This page records what each project patch changes. For the command sequence to
apply the queue to a clean U-Boot tree, use [[07-uboot-apply-project-patches.md]].

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

Add before the `#define CONFIG_EXTRA_ENV_SETTINGS` block:

```c
#define TFTP_BOOT_ENV                                       \
	"serverip=192.168.7.1\0"                            \
	"ipaddr=192.168.7.2\0"                              \
	"tftp_boot="                                        \
	"setenv ethact usb_ether; "                         \
	"setenv ethrotate no; "                             \
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

## Regenerate Patch Files

From `beaglebone-bsp/u-boot` after editing source:

```bash
mkdir -p ../patches/u-boot/v2022.07

git diff -- drivers/usb/gadget/ether.c \
  > ../patches/u-boot/v2022.07/0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch

git diff -- include/configs/am335x_evm.h \
  > ../patches/u-boot/v2022.07/0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch

printf '%s\n' \
  0001-usb-gadget-ether-avoid-udc-release-with-dm-eth.patch \
  0002-am335x-evm-add-usb-rndis-tftp-boot-env.patch \
  > ../patches/u-boot/v2022.07/series
```

## Verify

```bash
git describe --tags --exact-match HEAD  # expect: v2022.07
grep -q 'tftp_boot' include/configs/am335x_evm.h && echo OK  # expect: OK
```
