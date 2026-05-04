# RUNBOOK

Step-by-step execution and verification guide for the current repository
checkout.

This file is an operations runbook, not a roadmap. `TODO.md` may describe
future acceptance targets; this runbook records what the repository currently
supports and where current gaps are known.

## 0. Current State Summary

| Area | Current status | Notes |
| --- | --- | --- |
| Docker | Implemented | `make docker` builds the shared default image `bbb-builder`. Direct `scripts/build.sh` also defaults to `bbb-builder`. |
| Kernel | Implemented | Linux is pinned by `linux/VERSION-PIN` to `v5.10.253`. `make kernel` defaults to dev mode; `make kernel-reproducible` builds with deterministic settings. Both modes merge `linux/configs/boneblack-custom.config` via `scripts/build.sh`. |
| Device tree | Implemented | `am335x-boneblack-custom.dts` exists in both `linux/arch/arm/boot/dts/` for direct kernel builds and `linux/dts/` for Yocto packaging. |
| U-Boot | Implemented | Custom defconfig and external patch archive exist under `meta-bbb/recipes-bsp/u-boot/files/`. |
| Deploy | Implemented as local TFTP directory copy | `scripts/deploy.sh` copies `zImage` and DTB to `TFTP_DIR`. It does not run a TFTP client and does not copy a rootfs tarball. |
| Flash | Implemented, destructive | `scripts/flash_sd.sh` writes boot files to an `/dev/sdX` card and optionally extracts a rootfs. Current `uEnv.txt` runs `tftp_boot`, so the flashed card still expects the TFTP boot flow for kernel handoff. |
| Drivers | Implemented | `drivers/led-gpio/`, `drivers/sht3x/`, `drivers/pwm-led/`, and `drivers/pwm-servo/` all have complete source trees and build successfully. |
| Yocto | Partial but coherent | `meta-bbb/` has machine, image, app, driver, and kernel append recipes. Phase 6 app sources now exist; `qt-hmi` still depends on `meta-qt5` being present in `BBLAYERS`. |
| Apps | Implemented, target validation pending | `apps/sensor-monitor/`, `apps/qt-hmi/`, and `apps/gstreamer-demo/` now contain source/build artifacts matching their recipes. |
| FreeRTOS | Scaffold only | `freertos/demo/` and `freertos/drivers/` exist but contain no source files. |
| Tests/CI | Partial | `tests/test-reproducible-build.sh`, `test-gpio.sh`, `test-i2c.sh`, `test-pwm.sh`, `test-pwm-servo.sh`, `test-bh1750.sh`, `test-rtc-ds3231.sh`, and `test-phase6-sensor-monitor.sh` exist and contain target-side checks. `.github/workflows/*.yml` still remain unimplemented in the current checkout. |

## 1. Common Commands

### 1.1 Primary commands

```bash
make docker
make kernel
make uboot
make driver DRIVER=led-gpio
make deploy TFTP_DIR=/srv/tftp
make flash DEV=/dev/sdX
make check
```

Use these with care:

```bash
make all
make yocto-shell
make bitbake BB=bbb-image
```

Current caveats:

- `make all` now has source trees for all three drivers, but it still depends on
  the Docker image, the current kernel build mode, and any live Yocto/runtime
  prerequisites needed by later phases.
- `make yocto-shell` and `make bitbake` assume a Yocto/Poky checkout at
  `./poky` inside this repo, or use `POKY_DIR=/path/to/poky`.
- `make flash` runs `sudo bash scripts/flash_sd.sh $(DEV)` and is destructive.
  Do not run it without explicitly verifying the target block device.

### 1.2 Manual cross-compile defaults

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
```

### 1.3 Serial console

```bash
minicom -D /dev/ttyUSB0 -b 115200
```

### 1.4 TFTP service check

```bash
systemctl status tftpd-hpa
```

### 1.5 Static analysis examples

```bash
cppcheck --enable=all --suppress=missingIncludeSystem <file.c>
linux/scripts/checkpatch.pl --strict -f <file.c>
```

## 2. Docker

Docker section sources:

- `docker/Dockerfile`
- `Makefile`
- `scripts/build.sh`
- `vault/wiki/docker/*.md`
- `vault/wiki/scripts/02-build-sh-docker-wrapper.md`

### 2.1 Image name reality

The current checkout uses one default Docker image name:

| Path | Default image |
| --- | --- |
| `Makefile` | `bbb-builder` |
| `scripts/build.sh` when run directly outside Docker | `bbb-builder` |

Recommended current workflow: use the `Makefile` entry points.

If running `scripts/build.sh` directly, override `DOCKER_IMAGE` only when using
a custom image tag:

```bash
DOCKER_IMAGE=my-custom-builder:2.0 bash scripts/build.sh kernel
```

### 2.2 Set workspace path

Goal: define `BSP_ROOT` once and reuse in all Docker commands.

Commands:

```bash
export BSP_ROOT="${HOME}/Working_Space/my-project/beaglebone-bsp"
export IMAGE="${IMAGE:-bbb-builder}"
ls -la "${BSP_ROOT}"
```

Expected:

- `ls` lists repo folders like `docker/`, `linux/`, `u-boot/`, `drivers/`.

If failed:

- Fix `BSP_ROOT` to the actual repo path.

### 2.3 Install Docker Engine (Ubuntu 22.04)

Skip if Docker is already installed and working.

Goal: install Docker engine and CLI tools required by this BSP.

Commands:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Expected:

- Docker packages install successfully with no dependency errors.
- `usermod` finishes without error.

If failed:

- Start daemon: `sudo systemctl start docker && sudo systemctl enable docker`.
- Re-login after `usermod -aG docker $USER`.

### 2.4 Verify Docker installation

Goal: confirm daemon and CLI are ready.

Commands:

```bash
sudo docker run --rm hello-world
docker images
```

Expected:

- `hello-world` prints success message.
- `docker images` runs without daemon permission errors.

If failed:

- If permission denied: re-login after group change or use `sudo`.
- Check daemon logs: `sudo journalctl -u docker -f`.

### 2.5 Build BSP Docker image

Goal: build reproducible project image `${IMAGE}` from `docker/Dockerfile`.
For the current `Makefile`, `${IMAGE}` defaults to `bbb-builder`.

Commands:

```bash
cd "${BSP_ROOT}"
make docker
```

Manual equivalent:

```bash
cd "${BSP_ROOT}"
docker build -f docker/Dockerfile -t "${IMAGE}" .
```

Expected:

- Build ends with image tagged `${IMAGE}` (default: `bbb-builder`).

If failed:

- Clean cache and retry: `sudo docker system prune -a`.
- Verify Dockerfile base digest line exists:
  `grep -E '^FROM ubuntu@sha256:[0-9a-f]{64}' docker/Dockerfile`.

### 2.6 Verify BSP image and toolchain

Goal: validate image existence, compiler availability, and basic constraints.

Commands:

```bash
docker images "${IMAGE}"

docker run --rm "${IMAGE}" arm-linux-gnueabihf-gcc --version

docker images "${IMAGE}" --format "{{.Size}}"

grep -E '^FROM ubuntu@sha256:[0-9a-f]{64}' "${BSP_ROOT}/docker/Dockerfile"
```

Expected:

- Image appears in `docker images`.
- Cross-compiler command prints ARM GCC version.
- Image size is around ~1.04 GB (and below 2.5 GiB policy target).
- Dockerfile `FROM` line is digest-pinned.

If failed:

- Rebuild image with `--no-cache` once.
- Check network/proxy access to Docker Hub.

### 2.7 Run one command inside container

Goal: confirm bind mount and container working directory are correct for project usage.

Commands:

```bash
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace \
  "${IMAGE}" \
  ls -la
```

Optional interactive shell:

```bash
docker run --rm -it \
  -v "${BSP_ROOT}:/workspace" \
  -w /workspace \
  "${IMAGE}" \
  bash
```

Expected:

- `ls -la` inside container shows repository files.
- Interactive shell opens and exits cleanly.

If failed:

- Ensure `BSP_ROOT` is absolute and exists.
- Validate mount path with:
  `docker run --rm -v "${BSP_ROOT}:/workspace" -w /workspace "${IMAGE}" ls -la`.

### 2.8 Done criteria

Docker stage is complete when all conditions pass:

- `docker run --rm hello-world` succeeds.
- Docker image `${IMAGE}` exists.
- `arm-linux-gnueabihf-gcc --version` runs in container.
- Repo mount works with `-v "${BSP_ROOT}:/workspace"`.

## 3. Kernel

Kernel section sources:

- `linux/VERSION-PIN`
- `linux/configs/reproducible.config`
- `linux/configs/boneblack-custom.config`
- `linux/arch/arm/boot/dts/am335x-boneblack-custom.dts`
- `linux/dts/am335x-boneblack-custom.dts`
- `linux/patches/0001-gpio-omap-fix-irq-unmask-on-resume.patch`
- `scripts/build.sh`
- `docs/04-kernel-workflow.md`
- `vault/wiki/kernel/*.md`

### 3.1 Pinned kernel version

Commands:

```bash
cat "${BSP_ROOT}/linux/VERSION-PIN"
```

Expected:

```text
LINUX_TAG=v5.10.253
```

If `linux/` is a kernel git checkout, also verify:

```bash
cd "${BSP_ROOT}/linux"
git describe --tags HEAD
```

Expected:

- `v5.10.253` for the current documented pin.

### 3.2 Scripted build path

Goal: build the current project kernel artifacts through the top-level
`Makefile`.

Commands:

```bash
cd "${BSP_ROOT}"
make kernel
```

Current `scripts/build.sh kernel` behavior defaults to dev mode:

1. Uses `build/linux/dev` as an out-of-tree kernel object directory.
2. Reuses the existing dev `.config` for incremental builds.
3. Enables debug symbols on first dev config generation unless `KERNEL_DEV_DEBUG=0`.
4. Builds `zImage`, `dtbs`, and `modules`.
5. Copies artifacts to `build/kernel/`.

For deterministic output, use:

```bash
bash scripts/build.sh kernel reproducible
```

Expected:

```bash
ls -lh "${BSP_ROOT}/build/kernel/zImage"
ls -lh "${BSP_ROOT}/build/kernel/am335x-boneblack-custom.dtb"
```

Current scripted-build gap:

- `linux/configs/boneblack-custom.config` exists, but
  `scripts/build.sh kernel` does not merge it.
- Do not claim that the scripted build enables the full GPIO/I2C/PWM/HWMON/KASAN
  custom fragment unless that script is updated or you merge the fragment
  manually.

### 3.3 Full custom config manual path

Use this path when validating the config fragment described in
`docs/04-kernel-workflow.md`.

Commands:

```bash
cd "${BSP_ROOT}/linux"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- omap2plus_defconfig
scripts/kconfig/merge_config.sh -m .config configs/boneblack-custom.config
grep -E '^CONFIG_(GPIO_SYSFS|I2C_OMAP|PWM_TIECAP|PWM_TIEHRPWM|SENSORS_TMP102|KASAN)=' .config
```

Expected:

- `CONFIG_GPIO_SYSFS=y`
- `CONFIG_I2C_OMAP=y`
- `CONFIG_PWM_TIECAP=y`
- `CONFIG_PWM_TIEHRPWM=y`
- `CONFIG_SENSORS_TMP102=m`
- `CONFIG_KASAN=y`

Build:

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules
```

### 3.4 Device tree

Current direct-build DTS:

```text
linux/arch/arm/boot/dts/am335x-boneblack-custom.dts
```

Current Yocto-copy DTS:

```text
linux/dts/am335x-boneblack-custom.dts
```

Current kernel DTS Makefile includes:

```text
am335x-boneblack-custom.dtb
```

Current custom DTS content includes:

- UART1 on P9.24 (TX) / P9.26 (RX).
- I2C2 on P9.19 (SCL) / P9.20 (SDA) at 100 kHz.
  - SHT3x at `0x44`, BH1750 at `0x23`, DS3231 RTC at `0x68` are present but commented out.
- SPI0 on P9.17 (CS0) / P9.18 (D1) / P9.21 (D0) / P9.22 (SCLK).
- EHRPWM1A on P9.14.
- GPIO button on P9.12 / GPIO1_28 (active-low, falling-edge IRQ).
- `led-gpio` platform node (LED on GPIO1_21, button on GPIO1_28).
- `pwm-led` platform node (disabled to avoid conflict with servo on EHRPWM1 channel 0).
- `pwm-servo` platform node (enabled on EHRPWM1 channel 0).

Standalone DTS compile check:

```bash
cd "${BSP_ROOT}"
cpp -nostdinc \
  -I linux/arch/arm/boot/dts \
  -I linux/include \
  -undef -D__DTS__ \
  linux/arch/arm/boot/dts/am335x-boneblack-custom.dts | \
dtc -I dts -O dtb -o /tmp/am335x-boneblack-custom.dtb -
```

Expected:

- Command exits 0.
- `/tmp/am335x-boneblack-custom.dtb` is created.

### 3.5 Reproducible build test

Implemented test:

```bash
bash tests/test-reproducible-build.sh
```

Expected:

- Three consecutive `make kernel-reproducible` runs produce identical
  `build/kernel/zImage` SHA256 values.

### 3.6 Kernel verify (host-side Phase 3 gate)

```bash
make kernel-verify
```

Expected:

- Validates kernel and DTS artifacts exist in `build/kernel/`.

## 4. U-Boot

U-Boot section sources:

- `u-boot/configs/am335x_boneblack_custom_defconfig`
- `u-boot/include/configs/am335x_evm.h`
- `meta-bbb/recipes-bsp/u-boot/files/ (applied by BitBake)`
- `meta-bbb/recipes-bsp/u-boot/files/*.patch`
- `scripts/build.sh`
- `docs/03-uboot-workflow.md`
- `vault/wiki/uboot/*.md`

### 4.1 Prerequisites

Goal: ensure Docker toolchain and workspace are ready before building U-Boot.

Commands:

```bash
export BSP_ROOT="${HOME}/Working_Space/my-project/beaglebone-bsp"
export IMAGE="${IMAGE:-bbb-builder}"
docker images "${IMAGE}"
ls -la "${BSP_ROOT}/u-boot"
```

Expected:

- Docker image `${IMAGE}` is present.
- `u-boot/` exists in repository root.

If failed:

- Build Docker image first from section `2. Docker`.
- If `u-boot/` is missing, restore repo sources before continuing.

### 4.2 Verify custom defconfig and patch queue

Goal: confirm project-specific U-Boot config and patch ordering are in place.

Commands:

```bash
grep -E '^(CONFIG_CMD_TFTPPUT|CONFIG_CMD_BOOTZ|CONFIG_OF_LIBFDT|CONFIG_BOOTDELAY)=' \
  "${BSP_ROOT}/u-boot/configs/am335x_boneblack_custom_defconfig"

grep 'SPL_OS_BOOT' "${BSP_ROOT}/u-boot/configs/am335x_boneblack_custom_defconfig"

ls -la "${BSP_ROOT}/meta-bbb/recipes-bsp/u-boot/files/ (applied by BitBake)"
```

Expected:

- Defconfig includes `CONFIG_CMD_TFTPPUT=y`, `CONFIG_CMD_BOOTZ=y`, `CONFIG_OF_LIBFDT=y`, and `CONFIG_BOOTDELAY=1`.
- `# CONFIG_SPL_OS_BOOT is not set` appears.
- Patch series file exists at `meta-bbb/recipes-bsp/u-boot/files/ (applied by BitBake)`.

Current repository note:

- `u-boot/patches/` is not the current patch archive location.
- Some older TODO text may refer to `u-boot/patches/*.patch`; use
  `meta-bbb/recipes-bsp/u-boot/files/` for this checkout.

If failed:

- Re-sync `u-boot/configs/am335x_boneblack_custom_defconfig` from project branch.
- Check patch directory path/version (`v2022.07`).

### 4.3 Apply project patch queue (when needed)

Goal: re-apply BSP U-Boot patches after re-clone or clean source reset.
Use this only on a clean U-Boot v2022.07 source tree that does not already
contain the project changes.

Commands:

```bash
cd "${BSP_ROOT}/u-boot"
while read patch; do
  git apply "../meta-bbb/recipes-bsp/u-boot/files/${patch}"
done < "../meta-bbb/recipes-bsp/u-boot/files/ (applied by BitBake)"
```

Expected:

- Loop completes without patch rejects.

If failed:

- Verify U-Boot source base is compatible with `v2022.07` patch set.
- Inspect reject context and re-clone clean tree if patch drift is large.

### 4.4 Build U-Boot inside Docker

Goal: produce `MLO` and `u-boot.img` from `am335x_boneblack_custom_defconfig`.

Commands:

```bash
cd "${BSP_ROOT}"
docker run --rm \
  -v "${BSP_ROOT}/u-boot:/workspace/u-boot" \
  -w /workspace/u-boot \
  "${IMAGE}" bash -c "
    make CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_custom_defconfig
    make CROSS_COMPILE=arm-linux-gnueabihf- -j\$(nproc)
  "
```

Expected:

- Build finishes successfully and emits U-Boot image generation lines.

If failed:

- Confirm `CROSS_COMPILE=arm-linux-gnueabihf-` is used.
- Re-run defconfig before build.

### 4.5 Verify U-Boot artifacts

Goal: validate image format and SPL size constraints for AM335x.

Commands:

```bash
docker run --rm \
  -v "${BSP_ROOT}/u-boot:/workspace/u-boot" \
  -w /workspace/u-boot \
  "${IMAGE}" \
  ./tools/mkimage -l u-boot.img | grep -E '(Architecture: ARM|OS:.*U-Boot)'

stat -c '%s' "${BSP_ROOT}/u-boot/MLO"
```

Expected:

- `mkimage -l` output confirms ARM/U-Boot metadata.
- `MLO` size is in `[64000, 131072]` bytes.

If failed:

- If MLO is too large, reduce SPL features in defconfig.
- If `u-boot.img` inspection fails, rebuild from clean tree.

### 4.6 Copy artifacts to build directory

Goal: standardize outputs for deploy/flash pipeline.

Commands:

```bash
mkdir -p "${BSP_ROOT}/build/uboot"
cp "${BSP_ROOT}/u-boot/MLO" "${BSP_ROOT}/u-boot/u-boot.img" "${BSP_ROOT}/build/uboot/"
ls -lh "${BSP_ROOT}/build/uboot/"
```

Expected:

- `build/uboot/MLO` and `build/uboot/u-boot.img` both exist.

If failed:

- Re-check section `4.4` build output for missing artifacts.

### 4.7 Runtime environment checks (serial prompt)

Goal: verify board is using compiled default boot flow and expected addresses.

Commands at U-Boot prompt:

```text
printenv bootcmd
printenv tftp_boot
printenv serverip
printenv ipaddr
printenv loadaddr
printenv fdtaddr
```

Expected:

- `bootcmd` invokes the TFTP boot flow.
- `tftp_boot` contains kernel + DTB download sequence and Linux handoff.
- Default `serverip` is `192.168.7.1`.
- Default `ipaddr` is `192.168.7.2`.
- `loadaddr`/`fdtaddr` are valid RAM addresses for kernel and DTB.

Binary-level check on host:

```bash
cd "${BSP_ROOT}/u-boot"
strings u-boot.img | grep -A1 -B1 'tftp_boot='
```

If failed:

- If runtime env differs from binary defaults, check whether saved environment overrides defaults.
- If serial output is garbled/truncated, verify cable and baud (`115200 8N1`).

### 4.8 Done criteria

U-Boot stage is complete when all conditions pass:

- `MLO` and `u-boot.img` are built and copied to `build/uboot/`.
- `MLO` size is within AM335x SPL SRAM-safe range.
- Runtime env confirms TFTP-oriented boot chain and valid load addresses.

## 5. Deploy and TFTP Boot

Deploy section sources:

- `scripts/deploy.sh`
- `Makefile`
- `vault/wiki/uboot/06-uboot-tftp-rndis-boot.md`
- `vault/wiki/scripts/04-deploy-sh.md`

Note: some older wiki examples still show a `TFTP_SERVER` / `tftp put` model.
The current script uses local copy into `TFTP_DIR`.

### 5.1 Current deploy script behavior

Current `scripts/deploy.sh` behavior:

- Reads `TFTP_DIR`, default `/srv/tftp`.
- Copies `build/kernel/zImage` into `TFTP_DIR`.
- Copies `build/kernel/am335x-boneblack-custom.dtb` into `TFTP_DIR`.
- Supports `--dry-run`.
- Does not copy `rootfs.tar.gz`.
- Does not call `tftp`.
- Does not use `TFTP_SERVER`.

Dry-run:

```bash
bash scripts/deploy.sh --dry-run
```

Expected output shape:

```text
cp <repo>/build/kernel/zImage /srv/tftp/zImage
cp <repo>/build/kernel/am335x-boneblack-custom.dtb /srv/tftp/am335x-boneblack-custom.dtb
```

Deploy:

```bash
make deploy TFTP_DIR=/srv/tftp
```

Expected:

- `/srv/tftp/zImage` exists.
- `/srv/tftp/am335x-boneblack-custom.dtb` exists.

Verify:

```bash
ls -lh /srv/tftp/zImage /srv/tftp/am335x-boneblack-custom.dtb
```

If deploy fails:

- Build the kernel first with `make kernel`.
- Check write permissions on `TFTP_DIR`.
- Check `tftpd-hpa` is configured to serve the same directory.

### 5.2 Host USB network defaults

The project U-Boot environment assumes the common BBB USB gadget pair:

```text
host/server: 192.168.7.1
board:       192.168.7.2
```

U-Boot uses:

```text
serverip=192.168.7.1
ipaddr=192.168.7.2
```

Host-side checks:

```bash
ip addr
ping -c 1 192.168.7.2
systemctl status tftpd-hpa
```

U-Boot manual TFTP checks:

```text
setenv serverip 192.168.7.1
setenv ipaddr 192.168.7.2
tftpboot ${loadaddr} zImage
tftpboot ${fdtaddr} am335x-boneblack-custom.dtb
bootz ${loadaddr} - ${fdtaddr}
```

## 6. Flash SD Card

Flash section sources:

- `scripts/flash_sd.sh`
- `Makefile`
- `vault/wiki/scripts/05-flash-sd-sh.md`

### 6.1 Safety rules

`scripts/flash_sd.sh` is destructive.

Current hard checks:

- Device argument must start with `/dev/sd`.
- Script refuses a device mounted as `/` or `/home`.
- Script requires root.
- Script requires the target to be a block device.
- User must type `yes` before partitioning.

Do not pass:

- `/dev/sda` if it is the host system disk.
- `/dev/nvme0n1`.
- `/dev/mmcblk0`.
- Any mounted production disk.

### 6.2 Current partition layout

The current script creates:

| Partition | Type | Size |
| --- | --- | --- |
| `${DEV}1` | FAT32 boot partition | `100M` |
| `${DEV}2` | ext4 rootfs partition | rest of card |

This differs from older project text that mentions a 64 MB boot partition.
For the current checkout, the script is the source of truth: `100M`.

### 6.3 Required artifacts

Before flashing:

```bash
make kernel
make uboot
ls -lh build/kernel/zImage build/kernel/am335x-boneblack-custom.dtb
ls -lh build/uboot/MLO build/uboot/u-boot.img
```

Flash command:

```bash
make flash DEV=/dev/sdX
```

Optional rootfs:

```bash
sudo bash scripts/flash_sd.sh /dev/sdX /path/to/rootfs.tar.gz
```

Current `uEnv.txt` written by the script:

```text
bootargs=console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
serverip=192.168.7.1
ipaddr=192.168.7.2
uenvcmd=run tftp_boot
```

Important:

- Even though `zImage` and DTB are copied to the FAT partition, the current
  `uEnv.txt` runs `tftp_boot`.
- A fully offline SD-card kernel boot is not what the current script configures.
- For the current scripted path, prepare TFTP deployment too.

## 7. Drivers

Driver section sources:

- `drivers/`
- `scripts/build.sh`
- `Makefile`
- `meta-bbb/recipes-drivers/*`
- `TODO.md` phase 5

### 7.1 Current driver tree

Current directories:

```text
drivers/led-gpio/
drivers/sht3x/
drivers/pwm-led/
drivers/pwm-servo/
```

Current source files:

```text
drivers/led-gpio/Makefile
drivers/led-gpio/led-gpio.c
drivers/sht3x/Makefile
drivers/sht3x/sht3x.c
drivers/pwm-led/Makefile
drivers/pwm-led/pwm-led.c
drivers/pwm-servo/Makefile
drivers/pwm-servo/pwm-servo.c
```

Current status:

- `led-gpio.c` — full platform driver with `led_classdev`, `miscdevice`, button IRQ thread, and `poll` support.
- `sht3x.c` — full I2C hwmon driver with CRC8 validation, exposing `temp1_input` and `humidity1_input`.
- `pwm-led.c` — full PWM LED driver via `led_classdev` with brightness scaling.
- `pwm-servo.c` — full PWM servo driver with sysfs controls (`enable`, `position_us`).

### 7.2 Build what currently exists

```bash
make driver DRIVER=led-gpio
```

Expected:

- All four drivers produce `.ko` files when the kernel build tree is ready.

Build all drivers:

```bash
make driver DRIVER=led-gpio
make driver DRIVER=sht3x
make driver DRIVER=pwm-led
make driver DRIVER=pwm-servo
make all
```

## 8. Yocto / meta-bbb

Yocto section sources:

- `meta-bbb/conf/layer.conf`
- `meta-bbb/conf/machine/beaglebone-custom.conf`
- `meta-bbb/recipes-core/images/bbb-image.bb`
- `meta-bbb/recipes-kernel/linux/linux-yocto_%.bbappend`
- `meta-bbb/recipes-drivers/*`
- `meta-bbb/recipes-apps/*`
- `Makefile`
- `TODO.md` phase 4

### 8.1 Current layer files

The current checkout has:

```text
meta-bbb/conf/layer.conf
meta-bbb/conf/machine/beaglebone-custom.conf
meta-bbb/recipes-core/images/bbb-image.bb
meta-bbb/recipes-kernel/linux/linux-yocto_%.bbappend
meta-bbb/recipes-drivers/led-gpio/led-gpio_1.0.bb
meta-bbb/recipes-drivers/sht3x/sht3x_1.0.bb
meta-bbb/recipes-drivers/pwm-led/pwm-led_1.0.bb
meta-bbb/recipes-drivers/pwm-servo/pwm-servo_1.0.bb
meta-bbb/recipes-apps/sensor-monitor/sensor-monitor_1.0.bb
meta-bbb/recipes-apps/qt-hmi/qt-hmi_1.0.bb
meta-bbb/recipes-apps/gstreamer-demo/gstreamer-demo_1.0.bb
```

### 8.2 Current machine config

`meta-bbb/conf/machine/beaglebone-custom.conf` currently:

- Requires `conf/machine/beaglebone-yocto.conf`.
- Sets `MACHINE_FEATURES = "usbgadget usbhost vfat alsa gpio i2c pwm"`.
- Sets serial console to `ttyO0`.
- Sets `KERNEL_DEVICETREE = "am335x-boneblack-custom.dtb"`.
- Sets `PREFERRED_PROVIDER_virtual/bootloader = "u-boot-bbb"`.
- Sets `PREFERRED_PROVIDER_virtual/kernel = "linux-yocto"` (extended by bbappend).
- Recommends `kernel-modules`.

### 8.3 Current recipe caveats

Most Phase 4–6 recipes now point at populated source trees. The remaining caveats are runtime- or layer-dependent:

| Recipe | Referenced source | Current source status |
| --- | --- | --- |
| `qt-hmi_1.0.bb` | `apps/qt-hmi/main.cpp`, `qt-hmi.pro`, `qt-hmi.service` | Source exists; build/install still depends on `meta-qt5` in `BBLAYERS` |
| `gstreamer-demo_1.0.bb` | `apps/gstreamer-demo/run-demo.sh` | Source exists; successful target execution still depends on GStreamer framebuffer plugins in the image |

Current Yocto expectation:

- The layer is coherent enough for Phase 6 source integration.
- `bitbake bbb-image` still depends on an available Poky checkout, any optional layers required by enabled packages, and target-side validation of framebuffer/runtime behavior.

### 8.4 Yocto shell commands

#### 8.4.1 Phase 6 runtime verification

For the current repo-side Phase 6 gate, run on the BBB target:

```bash
bash tests/test-phase6-sensor-monitor.sh
```

This script checks:

- `sensor-monitor.service` starts and stays active
- `/var/log/sensor-monitor.jsonl` exists
- the log gains new JSONL entries over a short sample window
- the last line matches the expected JSON shape
- `temp_mdeg` and `hum_mpct` stay within the expected bounds

Optional overrides:

```bash
SERVICE_NAME=sensor-monitor.service \
STATE_FILE=/var/log/sensor-monitor.jsonl \
SAMPLE_WINDOW_SEC=3 \
bash tests/test-phase6-sensor-monitor.sh
```

If `./poky` exists, or `POKY_DIR` points to a Poky checkout:

```bash
make yocto-shell
```

Build a target:

```bash
make bitbake BB=bbb-image
```

Current caveat:

- `Makefile` default `BB` is `core-image-minimal`; pass `BB=bbb-image` when
  validating the project image recipe.

## 9. FreeRTOS

FreeRTOS section sources:

- `freertos/`
- `TODO.md` phase 7

Current status:

- `freertos/demo/` exists but contains no source files.
- `freertos/drivers/` exists but contains no source files.
- No FreeRTOS build command is currently wired into the top-level `Makefile`.

Do not treat FreeRTOS/OpenAMP tasks as implemented in this checkout.

## 10. Tests and CI

Test section sources:

- `tests/`
- `.github/workflows/`
- `Makefile`

### 10.1 Current test files

Implemented:

```text
tests/test-reproducible-build.sh
```

Implemented target-side checks:

```text
tests/test-gpio.sh
tests/test-i2c.sh
tests/test-pwm.sh
tests/test-pwm-servo.sh
tests/test-bh1750.sh
tests/test-rtc-ds3231.sh
```

Current CI placeholders:

```text
.github/workflows/build.yml
.github/workflows/test.yml
.github/workflows/static-analysis.yml
```

All three workflow files are empty in the current checkout.

### 10.2 Local quality command

```bash
make check
```

Current behavior:

- Runs `shellcheck scripts/*.sh` inside Docker.
- Runs kernel `checkpatch.pl --strict -f` on C files under `drivers/*/`, but
  the command tolerates checkpatch failures with `|| true`.

Do not treat `make check` as a strict CI gate in the current checkout.

### 10.3 Reproducible kernel test

```bash
bash tests/test-reproducible-build.sh
```

Expected:

- Builds kernel three times.
- Prints three SHA256 values.
- Exits 0 only if all three match.

## 11. Hardware Verification

Hardware-required checks are not automatically run by this runbook.

Requires BBB hardware:

- Serial boot timing.
- U-Boot prompt verification.
- TFTP download from U-Boot.
- Kernel handoff with `Starting kernel ...`.
- Target-side `uname -r`.
- Driver probe/load tests.
- GPIO/I2C/PWM physical behavior.
- SD-card flashing.

Known debug report:

- `vault/wiki/debugging/reports/2026-04-24-smoke-test.md` records a board boot
  to login prompt with no critical errors, but it captured a Debian Bookworm
  login session and did not capture SPL/U-Boot from power-on.

## 12. Known Documentation Mismatches To Avoid

These mismatches exist across `TODO.md`, older wiki pages, or earlier docs.
Use this runbook section as the current correction list.

1. Docker image name is now synchronized:
   - `Makefile`: `bbb-builder`
   - Direct `scripts/build.sh`: `bbb-builder`

2. Deploy model is currently local-copy based:
   - Current code uses `TFTP_DIR`.
   - Current code does not use `TFTP_SERVER`.
   - Current code does not emit `tftp put`.
   - Current code does not deploy `rootfs.tar.gz`.

3. U-Boot patch archive is:
   - Current: `meta-bbb/recipes-bsp/u-boot/files/`
   - Not current: `u-boot/patches/`

4. Kernel scripted build merges `boneblack-custom.config`:
   - Both `dev` and `reproducible` modes merge the fragment via `scripts/build.sh`.
   - `reproducible` mode additionally merges `reproducible.config`.

5. SD boot is not fully offline by default:
   - `flash_sd.sh` copies kernel and DTB to FAT.
   - The generated `uEnv.txt` still runs `tftp_boot`.

6. Driver set is complete:
   - `led-gpio`, `sht3x`, `pwm-led`, and `pwm-servo` are all fully implemented.

7. Yocto layer machine config is complete:
   - `KERNEL_DEVICETREE`, `PREFERRED_PROVIDER_virtual/bootloader`, and `MACHINE_FEATURES` are set.
   - All driver/app recipes point at populated source trees.
   - `bitbake bbb-image` still depends on an available Poky checkout and optional layers (e.g., `meta-qt5`).

8. Tests and CI:
   - Host-side `test-reproducible-build.sh` is a deterministic gate.
   - Target-side driver tests (`test-gpio.sh`, `test-i2c.sh`, `test-pwm.sh`, etc.) contain checks but require hardware.
   - GitHub workflow files (`.github/workflows/*.yml`) remain empty placeholders.

## 13. Minimal Safe Bring-Up Sequence

This sequence avoids known incomplete areas.

```bash
export BSP_ROOT="${HOME}/Working_Space/my-project/beaglebone-bsp"
cd "${BSP_ROOT}"

make docker
make kernel
make uboot

ls -lh build/kernel/zImage build/kernel/am335x-boneblack-custom.dtb
ls -lh build/uboot/MLO build/uboot/u-boot.img

make deploy TFTP_DIR=/srv/tftp
ls -lh /srv/tftp/zImage /srv/tftp/am335x-boneblack-custom.dtb
```

Manual hardware steps after this point:

1. Connect BBB UART at `115200 8N1`.
2. Ensure USB gadget networking exposes host `192.168.7.1` and board
   `192.168.7.2`.
3. Ensure `tftpd-hpa` serves the same `TFTP_DIR`.
4. At U-Boot prompt, verify `printenv tftp_boot`.
5. Run `boot` or the manual `tftpboot` commands from section 5.2.

`make all` is now safe to include after `make kernel` and `make uboot` because all driver sources are populated. Yocto image build and target-side app/hardware tests remain outside this minimal gate.
