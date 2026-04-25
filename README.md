# BeagleBone Black BSP

> Self-learning BSP workspace for BeagleBone Black / TI AM335x.
> This repository tracks the full board support workflow: bootloader, kernel and device
> tree, out-of-tree drivers, Yocto BSP packaging, build/deploy scripts, debug/test scaffolding, and
> an Obsidian-compatible engineering wiki.

![BeagleBone Black BSP](assets/readme/hero.png)

**Target**: AM335x (BeagleBone Black), ARMv7-A, `arm-linux-gnueabihf-`
**Stack**: Linux 5.10.y-cip practice baseline, U-Boot 2022.07, Yocto Kirkstone, FreeRTOS scaffold

## Current Status

| Area                   | Status   | Notes                                                                                                           |
| ---------------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| Foundation / Toolchain | Active   | Docker build image and top-level Makefile targets are present.                                                  |
| U-Boot                 | Active   | U-Boot 2022.07 tree includes `am335x_boneblack_custom_defconfig` and BeagleBone Black TFTP boot patches.        |
| Linux Kernel / DTS     | Active   | Linux tree includes custom config fragments, `am335x-boneblack-custom.dts`, and a kernel patch area.            |
| Drivers                | Partial  | `drivers/led-gpio/` is present. `i2c-sensor` and `pwm-fan` are represented in Yocto recipes but need sources.   |
| Yocto BSP Layer        | Scaffold | `meta-bbb` has machine, image, kernel bbappend, driver recipes, and app recipes; some recipe sources are empty. |
| Userspace Apps         | Reserved | `apps/` exists as a workspace; no app source is currently populated.                                            |
| FreeRTOS               | Reserved | `freertos/` exists as a firmware workspace; no source is currently populated.                                   |
| Tests / Debugging      | Partial  | Debug helper files are present; `tests/` is currently reserved.                                                 |
| Wiki                   | Active   | `vault/wiki/` is the maintained project knowledge base.                                                         |

## Prerequisites

- Docker installed on the host.
- A Yocto `poky` checkout under `$(HOME)/Working_Space/poky` for `make yocto-shell` and `make bitbake`.
- Optional host tools for manual work: `arm-linux-gnueabihf-*`, `cppcheck`, `shellcheck`, `minicom`, `tftpd-hpa`.

## Boot Flow

```text
AM335x ROM -> SPL/MLO -> U-Boot -> Linux zImage + DTB
```

Current development boot flow:

```text
Host TFTP server
  -> zImage
  -> am335x-boneblack-custom.dtb
  -> U-Boot loads both into RAM
  -> bootz ${loadaddr} - ${fdtaddr}
  -> Linux starts
```

The current U-Boot script loads the kernel and DTB into RAM. It does not write them to the SD card.

Detailed notes:

```text
vault/wiki/bootloader/06-uboot-tftp-rndis-boot.md
docs/02-boot-flow.md
```

## Quick Start

Build the Docker image first:

```bash
make docker
```

Build core BSP artifacts:

```bash
make kernel
make uboot
make driver DRIVER=led-gpio
make all
```

Build through Yocto:

```bash
make yocto-shell
make bitbake BB=bbb-image
```

Deploy kernel artifacts to the TFTP directory:

```bash
make deploy TFTP_DIR=/srv/tftp
```

Flash an SD card:

```bash
make flash DEV=/dev/sdX
```

Run local quality checks:

```bash
make check
```

## Build Artifacts

`scripts/build.sh` copies successful outputs into `build/`:

| Target                      | Output                                                            |
| --------------------------- | ----------------------------------------------------------------- |
| `make kernel`               | `build/kernel/zImage`, `build/kernel/am335x-boneblack-custom.dtb` |
| `make uboot`                | `build/uboot/MLO`, `build/uboot/u-boot.img`                       |
| `make driver DRIVER=<name>` | `build/drivers/<name>/*.ko`                                       |

`make deploy` expects kernel artifacts already in `build/kernel/`.
`make flash DEV=/dev/sdX` expects boot files already in `build/`.

## Safety Notes

`make flash` is destructive. It runs `scripts/flash_sd.sh`, repartitions the target disk
after confirmation, and writes:

- partition 1: 100 MB FAT32 boot partition
- partition 2: ext4 rootfs partition

The flash script only accepts devices matching `/dev/sd*`, refuses devices mounted at
`/` or `/home`, requires root, and prompts for `yes` before writing. You must still
verify `DEV` before running it.

`make deploy` uses `scripts/deploy.sh` and copies `zImage` plus
`am335x-boneblack-custom.dtb` into `TFTP_DIR`, which defaults to `/srv/tftp`.

Do not run flash, deploy, SSH, serial console, or live board commands unless the board
and target device are intentionally connected.

## U-Boot TFTP Boot

The custom U-Boot boot command is:

```text
bootcmd=run tftp_boot
```

The `tftp_boot` environment loads the kernel and device tree over USB RNDIS/TFTP:

```text
tftpboot ${loadaddr} zImage
tftpboot ${fdtaddr} am335x-boneblack-custom.dtb
bootz ${loadaddr} - ${fdtaddr}
```

Useful U-Boot prompt commands:

```text
printenv bootcmd
printenv tftp_boot
printenv loadaddr
printenv fdtaddr
```

Inspect the embedded default environment inside `u-boot.img`:

```bash
cd u-boot
strings u-boot.img | grep -A1 -B1 'tftp_boot='
```

## Repository Layout

| Path             | Purpose                                        |
| ---------------- | ---------------------------------------------- |
| `apps/`          | Userspace app workspace, currently reserved    |
| `drivers/`       | Out-of-tree kernel modules                     |
| `freertos/`      | FreeRTOS firmware scaffold                     |
| `linux/`         | Linux kernel source, configs, DTS, and patches |
| `meta-bbb/`      | Yocto Kirkstone BSP layer                      |
| `u-boot/`        | U-Boot source, custom config, and patches      |
| `scripts/`       | Build, deploy, flash, and debug helpers        |
| `tests/`         | Reserved for local verification scripts        |
| `docs/`          | Technical docs and project roadmap             |
| `docker/`        | Reproducible build container                   |
| `assets/readme/` | README demo GIFs and screenshots               |
| `vault/wiki/`    | Obsidian-compatible engineering knowledge base |

## README Demo Assets

README demo images should live under:

```text
assets/
└── readme/
```

Suggested GIF names:

| Demo             | File                                | Status  |
| ---------------- | ----------------------------------- | ------- |
| Boot flow        | `assets/readme/01-boot-flow.gif`    | Planned |
| Docker build     | `assets/readme/02-docker-build.gif` | Planned |
| U-Boot TFTP boot | `assets/readme/03-uboot-tftp.gif`   | Planned |
| Kernel handoff   | `assets/readme/04-kernel-boot.gif`  | Planned |
| Driver probe     | `assets/readme/05-driver-demo.gif`  | Planned |
| Yocto build      | `assets/readme/06-yocto-build.gif`  | Planned |

Example embed:

```md
![U-Boot TFTP boot](assets/readme/03-uboot-tftp.gif)
```

## Engineering Vault

The `vault/wiki/` directory is an Obsidian-compatible knowledge base for this BSP.

It stores:

- Boot flow explanations.
- U-Boot notes.
- Kernel and device tree references.
- Debugging reports.
- Build procedures.
- Hardware references.

Start here:

```text
vault/wiki/_master-index.md
```

## Common Commands

```bash
make docker
make kernel
make uboot
make driver DRIVER=led-gpio
make all
make yocto-shell
make bitbake BB=bbb-image
make deploy TFTP_DIR=/srv/tftp
make flash DEV=/dev/sdX
make check
```

Manual cross-compile defaults:

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
```

Serial console:

```bash
minicom -D /dev/ttyUSB0 -b 115200
```

TFTP service check:

```bash
systemctl status tftpd-hpa
```

Static analysis examples:

```bash
cppcheck --enable=all --suppress=missingIncludeSystem <file.c>
linux/scripts/checkpatch.pl --strict -f <file.c>
```

## References

- AM335x Technical Reference Manual
- BeagleBone Black System Reference Manual
- U-Boot v2022.07
- Linux 5.10.y / CIP kernel practice baseline
- Yocto Project Kirkstone
- FreeRTOS documentation

## License

See `LICENSE`.
