---
title: U-Boot Patches
last_updated: 2026-04-18
category: bootloader
---

# U-Boot Patches

Step 4-6 of U-Boot workflow.

## Patch 0001: TFTP boot environment

Modify `include/configs/am335x_evm.h` to add a `tftp_boot` env variable. Load addresses `0x82000000` (zImage) and `0x88000000` (dtb) are inside DDR3 range `0x80000000–0x9FFFFFFF` (AM335x TRM SPRUH73Q §7 Table 7-1).

Add before the `#define CONFIG_EXTRA_ENV_SETTINGS` block:

```c
/*
 * TFTP dev-boot env — addresses from DEFAULT_LINUX_BOOT_ENV (ti_armv7_common.h):
 *   loadaddr=0x82000000, fdtaddr=0x88000000 (DDR3 0x80000000–0x9FFFFFFF,
 *   AM335x TRM SPRUH73Q §7 Table 7-1). serverip overridden by uEnv.txt.
 */
#define TFTP_BOOT_ENV \
	"tftp_boot=" \
		"setenv serverip ${serverip}; " \
		"tftp ${loadaddr} zImage; " \
		"tftp ${fdtaddr} am335x-boneblack-custom.dtb; " \
		"bootz ${loadaddr} - ${fdtaddr}\0"
```

Add `TFTP_BOOT_ENV \` to `CONFIG_EXTRA_ENV_SETTINGS`:

```c
#define CONFIG_EXTRA_ENV_SETTINGS \
	DEFAULT_LINUX_BOOT_ENV \
	TFTP_BOOT_ENV \
	...
```

Commit with DCO sign-off:

```bash
git add include/configs/am335x_evm.h
git commit -s -m "arm: am335x: add TFTP boot env for dev workflow

Add TFTP_BOOT_ENV macro to am335x_evm board config.
...

Signed-off-by: BeagleBone BSP <bsp@example.com>"
```

## Patch 0002: reduce boot delay

```bash
echo "CONFIG_BOOTDELAY=1" >> configs/am335x_boneblack_custom_defconfig

git add configs/am335x_boneblack_custom_defconfig
git commit -s -m "configs: am335x_boneblack_custom: reduce boot delay to 1 s
...
Signed-off-by: BeagleBone BSP <bsp@example.com>"
```

## Generate patch files

```bash
mkdir -p patches
git format-patch HEAD~2 -o patches/

# Rename to project convention
mv patches/0001-*.patch patches/0001-boneblack-tftp-boot-env.patch
mv patches/0002-*.patch patches/0002-boneblack-reduce-boot-delay.patch

# Reset HEAD back to v2022.07 — patches live as files only
git reset --hard v2022.07
```

## Apply patches to working tree

```bash
git apply patches/0001-boneblack-tftp-boot-env.patch
git apply patches/0002-boneblack-reduce-boot-delay.patch
```

## Verify

```bash
git describe --tags --exact-match HEAD  # expect: v2022.07
grep -q 'tftp_boot' include/configs/am335x_evm.h && echo OK  # expect: OK
```
