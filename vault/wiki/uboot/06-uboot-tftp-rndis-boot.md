---
title: U-Boot TFTP/RNDIS Boot Notes
last_updated: 2026-04-28
category: bootloader
---

# U-Boot TFTP/RNDIS Boot Notes

This page records the practical behavior of the BeagleBone Black U-Boot TFTP development boot path used by this BSP.

The current custom flow is a RAM boot: U-Boot downloads `zImage` and `am335x-boneblack-custom.dtb` from the host TFTP server into RAM, prepares `bootargs`, then starts Linux with `bootz`. It does not write the kernel or DTB to the SD card.

The core rule: **loading files is not the same as booting Linux correctly**.
For a visible and mountable Linux boot, U-Boot must provide all three parts:

1. `zImage` address: `${loadaddr}`.
2. DTB address: `${fdtaddr}`.
3. Kernel command line: `bootargs`.

For this BSP, `bootargs` is:

```text
console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
```

This tells Linux to print logs on BBB UART0 and mount the SD-card ext4 rootfs on
partition 2.

## Key Files

| Path                                               | Purpose                                                          |
| -------------------------------------------------- | ---------------------------------------------------------------- |
| `u-boot/include/configs/am335x_evm.h`              | Defines `TFTP_BOOT_ENV` and the `tftp_boot` environment variable |
| `u-boot/configs/am335x_boneblack_custom_defconfig` | Selects the custom boot command                                  |
| `meta-bbb/recipes-bsp/u-boot/files/*.patch`        | U-Boot patches applied by Yocto (BitBake)                        |
| `build/uboot/MLO`                                  | SPL image copied to the boot medium                              |
| `build/uboot/u-boot.img`                           | Full U-Boot image copied to the boot medium                      |
| `/srv/tftp/zImage`                                 | Kernel served by the host TFTP server                            |
| `/srv/tftp/am335x-boneblack-custom.dtb`            | Device tree served by the host TFTP server                       |

## Boot Command Chain

The custom defconfig contains:

```text
CONFIG_BOOTCOMMAND="run tftp_boot"
```

At runtime, this becomes the U-Boot environment variable:

```text
bootcmd=run tftp_boot
```

`run tftp_boot` means: find the environment variable named `tftp_boot`, then execute its contents.

The `tftp_boot` variable is provided by `TFTP_BOOT_ENV` in `include/configs/am335x_evm.h`:

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

Runtime chain:

```text
CONFIG_BOOTCOMMAND
  -> bootcmd=run tftp_boot
  -> tftp_boot=...
  -> setenv bootargs console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
  -> tftpboot ${loadaddr} zImage
  -> tftpboot ${fdtaddr} am335x-boneblack-custom.dtb
  -> bootz ${loadaddr} - ${fdtaddr}
```

Think of the chain this way:

| Step | Responsibility |
| ---- | -------------- |
| `setenv ethact usb_ether` | Use the mini-USB RNDIS network path. |
| `setenv ethrotate no` | Do not rotate to another Ethernet interface. |
| `setenv bootargs ...` | Tell Linux the console and rootfs. |
| `tftpboot ${loadaddr} zImage` | Put the kernel image in RAM. |
| `tftpboot ${fdtaddr} ...dtb` | Put the board description in RAM. |
| `bootz ${loadaddr} - ${fdtaddr}` | Jump into Linux with no initrd and with the DTB. |

## `tftpboot` Does Not Write SD Card

This command:

```text
tftpboot ${loadaddr} zImage
```

loads `zImage` from the TFTP server into RAM at `${loadaddr}`. In this BSP, `${loadaddr}` is normally:

```text
loadaddr=0x82000000
```

This command:

```text
tftpboot ${fdtaddr} am335x-boneblack-custom.dtb
```

loads the DTB into RAM at `${fdtaddr}`. In this BSP, `${fdtaddr}` is normally:

```text
fdtaddr=0x88000000
```

Neither command writes to SD/eMMC. To write to a FAT partition, U-Boot would need an explicit command such as:

```text
fatwrite mmc 0:1 ${loadaddr} zImage ${filesize}
```

To write to an ext4 partition, it would need an explicit command such as:

```text
ext4write mmc 0:2 ${loadaddr} /boot/zImage ${filesize}
```

The current development boot script intentionally avoids writing storage. It is meant for fast kernel/DTB testing from RAM.

## `bootz` Meaning

`bootz` starts a Linux kernel in `zImage` format.

General form:

```text
bootz <kernel_addr> <initrd_addr_or_-> <fdt_addr>
```

Current BSP form:

```text
bootz ${loadaddr} - ${fdtaddr}
```

Meaning:

| Argument      | Meaning                         |
| ------------- | ------------------------------- |
| `${loadaddr}` | RAM address containing `zImage` |
| `-`           | No initrd/initramfs             |
| `${fdtaddr}`  | RAM address containing the DTB  |

For BeagleBone Black, the DTB is important. It tells Linux about board hardware such as UART, MMC, Ethernet, GPIO, I2C, and memory layout.

`bootz` also uses the current U-Boot `bootargs` variable as the Linux command
line. That is why the BSP's `tftp_boot` sets `bootargs` before `bootz`. The DTB
describes the hardware, but `bootargs` still carries runtime policy such as
which console and root filesystem Linux should use.

Avoid using only:

```text
bootz ${loadaddr}
```

That omits the DTB argument. On AM335x boards this can cause early boot failure, no console output, missing MMC/rootfs, or incorrect device probing.

## USB RNDIS vs CPSW Ethernet

U-Boot sees two relevant network interfaces on BeagleBone Black:

| Interface     | Log Name            | Cable                          | Meaning                           |
| ------------- | ------------------- | ------------------------------ | --------------------------------- |
| CPSW Ethernet | `ethernet@4a100000` | RJ45 LAN cable                 | Native AM335x Ethernet controller |
| USB RNDIS     | `usb_ether`         | Mini-USB data cable to host PC | BBB appears as a USB network card |

The current custom script forces USB RNDIS:

```text
setenv ethact usb_ether
setenv ethrotate no
```

Effect:

| Behavior                                                           | Result                                           |
| ------------------------------------------------------------------ | ------------------------------------------------ |
| USB data cable and host RNDIS are present                          | TFTP can work immediately over `usb_ether`       |
| USB data cable is absent                                           | TFTP cannot load kernel/DTB                      |
| RJ45 Ethernet is present but `ethact=usb_ether` and `ethrotate=no` | U-Boot does not fall back to CPSW in this script |

If the script used CPSW Ethernet only, then RJ45 network would be required. If no LAN cable/network is available, TFTP would fail there too.

A more robust production-style script should try one network path, then fall back to another, and only call `bootz` after both kernel and DTB have loaded successfully.

## Common Log Lines

### SPL and Full U-Boot

```text
U-Boot SPL 2022.07-dirty
Trying to boot from MMC1
U-Boot 2022.07-dirty
```

SPL is the small first-stage U-Boot image. It initializes enough hardware, including DRAM, then loads full U-Boot.

`dirty` means the U-Boot source tree had uncommitted changes when the image was built.

### Missing Saved Environment

```text
Loading Environment from FAT... Unable to read "uboot.env" from mmc0:1...
```

U-Boot did not find a saved environment file on the FAT partition. This is not fatal. U-Boot falls back to the default environment compiled into `u-boot.img`.

### MAC Address Fallback

```text
<ethaddr> not set. Validating first E-fuse MAC
```

The environment did not provide `ethaddr`, so U-Boot reads a MAC address from AM335x eFuse.

### RNDIS Setup

```text
using musb-hdrc, OUT ep1out IN ep1in STATUS ep2in
MAC de:ad:be:ef:00:01
HOST MAC de:ad:be:ef:00:00
RNDIS ready
USB RNDIS network up!
```

U-Boot initialized the USB gadget Ethernet path. The board side is usually `192.168.7.2`; the host side is usually `192.168.7.1`.

### MUSB Reset Warning

```text
musb-hdrc: peripheral reset irq lost!
```

This warning comes from the AM335x MUSB USB controller while BBB is acting as a USB device/gadget. It means the host reset the USB bus and the driver believes a reset interrupt was missed or handled late.

This is not fatal if the following lines still appear:

```text
USB RNDIS network up!
Bytes transferred = ...
Starting kernel ...
```

It is a sign that USB/RNDIS timing is not perfectly clean. Possible causes include cable quality, hub behavior, powering BBB only through USB, or host-side USB re-enumeration.

### Successful TFTP Load

```text
Bytes transferred = 4582616 (45ecd8 hex)
Bytes transferred = 63728 (f8f0 hex)
```

The first line is `zImage`. The second line is the DTB.

### Kernel Handoff

```text
Starting kernel ...
```

U-Boot has handed execution to Linux. After this line, missing output is usually
a kernel console, device tree, or root filesystem issue rather than a U-Boot
TFTP transfer issue.

For this BSP, first check the handoff contract:

```text
printenv bootargs
printenv tftp_boot
```

Expected `tftp_boot` must include both:

```text
setenv bootargs console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
bootz ${loadaddr} - ${fdtaddr}
```

If the kernel banner appears after adding `bootargs`, the kernel and DTB were
valid; the failure was the U-Boot-to-Linux command line, not a missing kernel.

If the log goes even further and shows the Linux banner but later panics with
messages such as `No working init found`, treat that as a rootfs/userspace/init
failure. At that point, the TFTP transfer and the U-Boot → kernel handoff have
already succeeded.

If an old valid `uboot.env` exists on FAT p1, it can override compiled-in
defaults. In that case, a rebuilt `u-boot.img` may still appear to use the old
`tftp_boot` until the stale saved environment is removed or updated.

### Bad zImage Magic

```text
zimage: Bad magic!
```

`bootz` checked the address in `${loadaddr}` and did not find a valid `zImage` header.

Common causes:

- `tftpboot ${loadaddr} zImage` failed.
- Network was unavailable.
- `${loadaddr}` points to stale or random RAM contents.
- The file at the TFTP server path is not a valid ARM `zImage`.

With the current script, this can happen if USB RNDIS is unavailable but the script still reaches `bootz`.

## Inspect Runtime Environment

At the U-Boot prompt:

```text
printenv bootcmd
printenv tftp_boot
printenv loadaddr
printenv fdtaddr
```

Expected values:

```text
bootcmd=run tftp_boot
loadaddr=0x82000000
fdtaddr=0x88000000
tftp_boot=setenv ethact usb_ether; setenv ethrotate no; setenv bootargs console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait; tftpboot ${loadaddr} zImage; tftpboot ${fdtaddr} am335x-boneblack-custom.dtb; bootz ${loadaddr} - ${fdtaddr}
```

Long `printenv` lines can appear truncated or garbled on a noisy serial console. If the source and binary are correct, suspect serial capture first.

## Inspect Compiled U-Boot Binary

To confirm the default environment embedded inside `u-boot.img`:

```bash
cd u-boot
strings u-boot.img | grep -A1 -B1 'tftp_boot='
```

Expected output includes:

```text
ipaddr=192.168.7.2
tftp_boot=setenv ethact usb_ether; setenv ethrotate no; setenv bootargs console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait; tftpboot ${loadaddr} zImage; tftpboot ${fdtaddr} am335x-boneblack-custom.dtb; bootz ${loadaddr} - ${fdtaddr}
fdtfile=undefined
```

This reads the binary only. It does not modify anything.

## Manual Test Commands

Stop autoboot at:

```text
Hit any key to stop autoboot:
```

Then run:

```text
tftpboot ${loadaddr} zImage
tftpboot ${fdtaddr} am335x-boneblack-custom.dtb
setenv bootargs console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
bootz ${loadaddr} - ${fdtaddr}
```

This separates transfer failure from kernel handoff failure. If these commands
reach the Linux banner, persist the same behavior in the source-controlled
`TFTP_BOOT_ENV` rather than relying on a one-off `saveenv`.

## Relationship to `make deploy`

`make deploy` runs on the host. It copies kernel artifacts to the TFTP directory, usually `/srv/tftp`:

```text
build/kernel/zImage -> /srv/tftp/zImage
build/kernel/am335x-boneblack-custom.dtb -> /srv/tftp/am335x-boneblack-custom.dtb
```

It does not interact with U-Boot directly and does not write the SD card.

U-Boot later pulls those files over the selected network interface with `tftpboot`.

## Current Limitation

The current `tftp_boot` script is convenient for USB RNDIS development, but it is not robust fallback logic:

- It forces `usb_ether`.
- It disables Ethernet rotation with `ethrotate no`.
- It does not fall back to CPSW Ethernet.
- It does not fall back to SD card boot.
- It can still reach `bootz` after a failed TFTP transfer.

A safer future script should use conditional execution:

```text
if tftpboot ${loadaddr} zImage; then
  if tftpboot ${fdtaddr} am335x-boneblack-custom.dtb; then
    bootz ${loadaddr} - ${fdtaddr}
  fi
fi
```

For full robustness, add fallback from TFTP to MMC/SD boot.
