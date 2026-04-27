---
title: build.sh Overview
tags:
  - scripts
  - build
  - automation
date: 2026-04-20
category: scripts
---

# build.sh Overview

`scripts/build.sh` is the **unified entry point** for building all BSP components: kernel, U-Boot, and drivers.

## Purpose

**Single command to build everything:**

```bash
bash scripts/build.sh all
```

**Instead of remembering:**

```bash
# Kernel (complex):
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules
cp arch/arm/boot/zImage ../build/kernel/
cp arch/arm/boot/dts/am335x-boneblack.dtb ../build/kernel/

# U-Boot (complex):
cd ../u-boot
make CROSS_COMPILE=arm-linux-gnueabihf- am335x_evm_defconfig
make CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)
cp MLO u-boot.img ../build/uboot/

# Drivers (complex):
cd ../drivers/led-gpio
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_DIR=../../linux
cp led-gpio.ko ../../build/drivers/led-gpio/
```

**Too complex! Easy to make mistakes!**

---

## Key Features

### 1. Auto Docker Wrapper

**User doesn't need to know about Docker:**

```bash
# User runs (on host):
bash scripts/build.sh kernel

# Script auto-detects: "Not in Docker? Let me fix that!"
# Script re-execs inside Docker automatically
# Build happens in clean environment
```

---

### 2. Unified Interface

**One command, multiple targets:**

```bash
bash scripts/build.sh kernel          # Build kernel
bash scripts/build.sh uboot           # Build U-Boot
bash scripts/build.sh driver led-gpio # Build specific driver
bash scripts/build.sh all             # Build everything
```

---

### 3. Organized Output

**All artifacts go to `build/` directory:**

```
build/
├── kernel/
│   ├── zImage
│   └── am335x-boneblack.dtb
├── uboot/
│   ├── MLO
│   └── u-boot.img
└── drivers/
    ├── led-gpio/
    │   └── led-gpio.ko
    ├── sht3x/
    │   └── sht3x.ko
    └── pwm-led/
        └── pwm-led.ko
```

---

### 4. Strict Error Handling

**Script stops immediately on any error:**

```bash
set -euo pipefail
```

**Benefits:**

- No silent failures
- Catches undefined variables
- Detects pipeline errors

---

### 5. Absolute Path Resolution

**Works from any directory:**

```bash
# From repo root:
bash scripts/build.sh kernel

# From /tmp:
cd /tmp
bash /home/nhat/Working_Space/my-project/beaglebone-bsp/scripts/build.sh kernel

# From scripts/:
cd scripts/
bash build.sh kernel

# All work correctly!
```

**How?** Script calculates absolute paths:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
```

---

## Usage

### Build Kernel

```bash
bash scripts/build.sh kernel
```

**Output:**

```
[build] kernel
  HOSTCC  scripts/basic/fixdep
  HOSTCC  scripts/kconfig/conf.o
  ...
  LD      vmlinux
  OBJCOPY arch/arm/boot/zImage
  Kernel: arch/arm/boot/zImage is ready
  DTC     arch/arm/boot/dts/am335x-boneblack.dtb
[build] kernel done → /workspace/build/kernel/
```

**Artifacts:**

- `build/kernel/zImage` (kernel image)
- `build/kernel/am335x-boneblack.dtb` (device tree)

---

### Build U-Boot

```bash
bash scripts/build.sh uboot
```

**Output:**

```
[build] uboot
  HOSTCC  tools/mkimage
  CC      arch/arm/cpu/armv7/start.o
  ...
  LD      u-boot
  OBJCOPY u-boot.bin
  MKIMAGE u-boot.img
[build] uboot done → /workspace/build/uboot/
```

**Artifacts:**

- `build/uboot/MLO` (first-stage bootloader)
- `build/uboot/u-boot.img` (second-stage bootloader)

---

### Build Specific Driver

```bash
bash scripts/build.sh driver led-gpio
```

**Output:**

```
[build] driver led-gpio
  CC [M]  /workspace/drivers/led-gpio/led-gpio.o
  LD [M]  /workspace/drivers/led-gpio/led-gpio.ko
[build] driver led-gpio done → /workspace/build/drivers/led-gpio/
```

**Artifacts:**

- `build/drivers/led-gpio/led-gpio.ko` (kernel module)

---

### Build Everything

```bash
bash scripts/build.sh all
```

**Builds in order:**

1. Kernel (zImage + dtbs + modules)
2. U-Boot (MLO + u-boot.img)
3. All drivers (led-gpio, sht3x, pwm-led)

**Total time:** ~5 minutes (in Docker), ~3 minutes (on host)

---

## Script Structure

### High-Level Flow

```
User runs: bash scripts/build.sh kernel
    ↓
Check: Are we in Docker?
    ↓
NO → Re-exec inside Docker
    ↓
YES → Continue
    ↓
Parse arguments (kernel/uboot/driver/all)
    ↓
Call appropriate function:
    - build_kernel()
    - build_uboot()
    - build_driver()
    - build_all()
    ↓
Copy artifacts to build/
    ↓
Done!
```

---

### Code Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 2. Docker auto-wrapper
if [[ ! -f /.dockerenv ]]; then
    exec docker run ... bash scripts/build.sh "$@"
fi

# 3. Environment setup
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
ARCH="${ARCH:-arm}"

# 4. Build functions
build_kernel() { ... }
build_uboot() { ... }
build_driver() { ... }
build_all() { ... }

# 5. Argument parsing
case "$1" in
    kernel) build_kernel ;;
    uboot)  build_uboot ;;
    driver) build_driver "$2" ;;
    all)    build_all ;;
esac
```

---

## Integration with Makefile

**Makefile provides convenient shortcuts:**

```makefile
# Makefile
kernel:
	$(DOCKER_RUN) bash scripts/build.sh kernel

uboot:
	$(DOCKER_RUN) bash scripts/build.sh uboot

driver:
	$(DOCKER_RUN) bash scripts/build.sh driver $(DRIVER)

all:
	$(DOCKER_RUN) bash scripts/build.sh all
```

**User can use either:**

```bash
# Direct script:
bash scripts/build.sh kernel

# Or Makefile:
make kernel
```

**Both do the same thing!**

---

## Environment Variables

### DOCKER_IMAGE

**Override Docker image:**

```bash
DOCKER_IMAGE=my-custom-builder:2.0 bash scripts/build.sh kernel
```

**Default:** `bbb-builder`

---

### CROSS_COMPILE

**Override cross-compiler prefix:**

```bash
CROSS_COMPILE=arm-none-eabi- bash scripts/build.sh kernel
```

**Default:** `arm-linux-gnueabihf-`

---

### ARCH

**Override target architecture:**

```bash
ARCH=arm64 bash scripts/build.sh kernel
```

**Default:** `arm`

---

## Error Handling

### Example: Missing Kernel Source

```bash
bash scripts/build.sh kernel
```

**Output:**

```
[build] kernel
bash: line 41: cd: /workspace/linux: No such file or directory
```

**Script exits immediately (due to `set -e`).**

---

### Example: Build Failure

```bash
bash scripts/build.sh kernel
```

**Output:**

```
[build] kernel
  CC      drivers/gpio/gpio-omap.o
drivers/gpio/gpio-omap.c:123:5: error: 'struct gpio_bank' has no member named 'irq_usage'
  123 |     bank->irq_usage++;
      |     ^~~~
make[3]: *** [scripts/Makefile.build:283: drivers/gpio/gpio-omap.o] Error 1
make[2]: *** [scripts/Makefile.build:504: drivers/gpio] Error 2
make[1]: *** [Makefile:1872: drivers] Error 2
make: *** [Makefile:219: __sub-make] Error 2
```

**Script exits with error code 2.**

---

### Example: Driver Not Found

```bash
bash scripts/build.sh driver nonexistent
```

**Output:**

```
[build] driver nonexistent
[build] ERROR: drivers/nonexistent/ not found
```

**Script exits with error code 1.**

---

## Debugging

### Verbose Mode

**Enable bash tracing:**

```bash
bash -x scripts/build.sh kernel
```

**Output shows every command executed:**

```
+ SCRIPT_DIR=/workspace/scripts
+ REPO_ROOT=/workspace
+ [[ ! -f /.dockerenv ]]
+ CROSS_COMPILE=arm-linux-gnueabihf-
+ ARCH=arm
+ build_kernel
+ local out=/workspace/build/kernel
+ mkdir -p /workspace/build/kernel
+ echo '[build] kernel'
[build] kernel
+ cd /workspace/linux
+ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_defconfig
...
```

---

### Check Docker Detection

```bash
# On host:
bash scripts/build.sh kernel
# Should re-exec in Docker

# Inside Docker:
docker run -it --rm beaglebone-bsp-builder:1.0 bash
bash scripts/build.sh kernel
# Should build directly (no re-exec)
```

---

## Common Issues

### Issue: "docker: command not found"

**Cause:** Docker not installed or not in PATH

**Solution:**

```bash
# Install Docker
sudo apt install docker.io

# Or use host toolchain
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
```

---

### Issue: "Permission denied" when accessing Docker

**Cause:** User not in `docker` group

**Solution:**

```bash
sudo usermod -aG docker $USER
newgrp docker  # Or logout/login
```

---

### Issue: Build artifacts owned by root

**Cause:** Docker container runs as root

**Solution:** Already handled! Script uses `builder` user (UID 1000) in Docker.

**Verify:**

```bash
ls -l build/kernel/zImage
# -rw-r--r-- 1 nhat nhat 4567890 Apr 20 10:00 build/kernel/zImage
# ← Owned by your user, not root!
```

---

## Performance Tips

### 1. Use Parallel Builds

**Script already uses `-j$(nproc)`:**

```bash
make -j$(nproc) zImage  # Uses all CPU cores
```

**On 8-core machine:**

- Serial build: ~10 minutes
- Parallel build: ~3 minutes

---

### 2. Use Host Toolchain for Development

```bash
# Host build (faster):
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
# ~3 minutes

# Docker build (slower but reproducible):
bash scripts/build.sh kernel
# ~5 minutes
```

---

### 3. Incremental Builds

**Don't clean between builds:**

```bash
# First build (full):
bash scripts/build.sh kernel
# ~5 minutes

# Edit one file:
vim linux/drivers/gpio/gpio-omap.c

# Second build (incremental):
bash scripts/build.sh kernel
# ~30 seconds (only rebuilds changed files)
```

---

### 4. Use ccache (Advanced)

**Install ccache in Docker:**

```dockerfile
# In Dockerfile:
RUN apt-get install -y ccache
ENV PATH="/usr/lib/ccache:${PATH}"
```

**Speed improvement:**

- First build: ~5 minutes
- Subsequent builds: ~1 minute (90% cache hit)

---

## Next Steps

- **Understand Docker wrapper:** 02-build-sh-docker-wrapper
- **Understand build functions:** 03-build-sh-functions
- **Deploy to board:** 04-deploy-sh
- **Flash SD card:** 05-flash-sd-sh

---

## References

- Google Shell Style Guide: https://google.github.io/styleguide/shellguide.html
- Bash Strict Mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
- Kernel build system: https://www.kernel.org/doc/html/latest/kbuild/index.html
- U-Boot build system: https://u-boot.readthedocs.io/en/latest/build/index.html
