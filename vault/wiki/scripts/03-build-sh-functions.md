---
title: build.sh Build Functions
tags:
  - scripts
  - build
  - kernel
  - uboot
  - drivers
date: 2026-04-20
category: scripts
---

# build.sh Build Functions

This document explains the core build functions in `scripts/build.sh`: how they compile kernel, U-Boot, and drivers.

## Overview

After the Docker auto-wrapper (see [[02-build-sh-docker-wrapper]]), the script calls one of these functions:

```bash
build_kernel()   # Build Linux kernel
build_uboot()    # Build U-Boot bootloader
build_driver()   # Build out-of-tree driver
build_all()      # Build everything
```

---

## build_kernel() - Linux Kernel Build

### Source Code

```bash
build_kernel() {
    local out="${BUILD_DIR}/kernel"
    mkdir -p "${out}"
    echo "[build] kernel"
    cd "${KERNEL_DIR}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_defconfig
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" zImage dtbs modules
    cp arch/arm/boot/zImage "${out}/"
    cp arch/arm/boot/dts/am335x-boneblack-custom.dtb "${out}/"
    echo "[build] kernel done → ${out}/"
}
```

### Step-by-Step Explanation

#### 1. Setup Output Directory

```bash
local out="${BUILD_DIR}/kernel"
mkdir -p "${out}"
```

**`local` keyword:**

- Variable only exists in this function
- Doesn't pollute global namespace
- Good practice for function-local variables

**`mkdir -p`:**

- `-p` = create parent directories if needed
- No error if directory already exists

**Example:**

```bash
BUILD_DIR="/workspace/build"
out="/workspace/build/kernel"
mkdir -p "/workspace/build/kernel"
# Creates: /workspace/build/ and /workspace/build/kernel/
```

---

#### 2. Change to Kernel Directory

```bash
cd "${KERNEL_DIR}"
```

**Why `cd`?**

- Kernel Makefile expects to run from kernel source root
- All paths in Makefile are relative to kernel root

**Example:**

```bash
KERNEL_DIR="/workspace/linux"
cd "/workspace/linux"
pwd  # Output: /workspace/linux
```

---

#### 3. Configure Kernel

```bash
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_defconfig
```

**What this does:**

- Loads default configuration for BeagleBone Black
- Creates `.config` file in kernel root
- `.config` contains ~5000 CONFIG\_\* options

**Variables:**

```bash
ARCH=arm
CROSS_COMPILE=arm-linux-gnueabihf-

# Expands to:
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_defconfig
```

**What is defconfig?**

Kernel has thousands of configuration options:

```
CONFIG_ARM=y
CONFIG_ARCH_OMAP2PLUS=y
CONFIG_SOC_AM33XX=y
CONFIG_GPIO_OMAP=y
CONFIG_I2C=y
CONFIG_SPI=y
...
```

**defconfig = default configuration file:**

```
linux/arch/arm/configs/
├── am335x_boneblack_defconfig  ← BeagleBone Black
├── omap2plus_defconfig         ← Generic OMAP
├── multi_v7_defconfig          ← Multi-platform ARMv7
└── ...
```

**Output:**

```
  HOSTCC  scripts/basic/fixdep
  HOSTCC  scripts/kconfig/conf.o
  HOSTCC  scripts/kconfig/confdata.o
  ...
  GEN     Makefile
#
# configuration written to .config
#
```

**Result:** `.config` file created with ~5000 options.

---

#### 4. Build Kernel

```bash
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" zImage dtbs modules
```

**Three targets in one command:**

##### `zImage` - Compressed Kernel Image

**What it builds:**

```
linux/arch/arm/boot/zImage
```

**Build process:**

```
C source files (.c)
    ↓ (gcc compile)
Object files (.o)
    ↓ (ld link)
vmlinux (uncompressed ELF)
    ↓ (objcopy)
Image (raw binary)
    ↓ (gzip compress)
zImage (compressed + decompressor)
```

**zImage structure:**

```
[Decompressor code] + [Compressed kernel] + [DTB (optional)]
```

**Size:**

- vmlinux: ~15 MB (uncompressed ELF)
- Image: ~10 MB (raw binary)
- zImage: ~4 MB (compressed)

**Why "z"?**

- z = gzip compressed
- Smaller size → faster boot (less to load from SD card)
- Decompressor runs in RAM, extracts kernel

---

##### `dtbs` - Device Tree Blobs

**What it builds:**

```
linux/arch/arm/boot/dts/*.dtb
```

**Device Tree Source → Binary:**

```
am335x-boneblack-custom.dts (source)
    ↓ (dtc compile)
am335x-boneblack-custom.dtb (binary)
```

**Why needed?**

ARM boards have different hardware:

- Different GPIO pins
- Different I2C/SPI addresses
- Different peripherals

**Device Tree describes hardware to kernel:**

```dts
// am335x-boneblack.dts
&uart1 {
    status = "okay";
};

&i2c1 {
    clock-frequency = <100000>;
    tmp102@48 {
        compatible = "ti,tmp102";
        reg = <0x48>;
    };
};
```

**Kernel reads .dtb at boot:**

```
U-Boot loads: zImage + dtb
    ↓
Kernel boots
    ↓
Kernel parses dtb
    ↓
Kernel knows: "I have UART1, I2C1 with TMP102 sensor at 0x48"
    ↓
Kernel loads appropriate drivers
```

---

##### `modules` - Kernel Modules

**What it builds:**

```
drivers/gpio/gpio-omap.ko
drivers/i2c/i2c-omap.ko
drivers/spi/spi-omap2-mcspi.ko
...
```

**Kernel modules = loadable drivers:**

```bash
# Load module at runtime
insmod gpio-omap.ko

# Unload module
rmmod gpio-omap

# List loaded modules
lsmod
```

**Why modules instead of built-in?**

**Built-in (CONFIG_GPIO_OMAP=y):**

- Compiled into zImage
- Always loaded
- Increases zImage size

**Module (CONFIG_GPIO_OMAP=m):**

- Separate .ko file
- Load only when needed
- Smaller zImage

**Example:**

```
# Built-in:
zImage size: 5 MB (includes all drivers)

# Modules:
zImage size: 3 MB (minimal drivers)
+ gpio-omap.ko: 50 KB
+ i2c-omap.ko: 30 KB
+ ... (load only what you need)
```

---

#### 5. Parallel Build: `-j$(nproc)`

```bash
-j"$(nproc)"
```

**`$(nproc)` = number of CPU cores:**

```bash
nproc
# Output: 8 (on 8-core machine)

# Expands to:
make -j8 zImage dtbs modules
```

**Parallel compilation:**

```
# Serial (no -j):
compile file1.c → compile file2.c → compile file3.c → ...
Time: 10 minutes

# Parallel (-j8):
compile file1.c ┐
compile file2.c ├─ All run simultaneously
compile file3.c ┤
...             ┘
Time: 2 minutes (5x faster on 8 cores)
```

**Why not `-j100`?**

- Too many jobs → context switching overhead
- Rule of thumb: `-j$(nproc)` or `-j$(($(nproc) + 1))`

---

#### 6. Copy Artifacts

```bash
cp arch/arm/boot/zImage "${out}/"
cp arch/arm/boot/dts/am335x-boneblack-custom.dtb "${out}/"
```

**From:**

```
linux/arch/arm/boot/zImage
linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb
```

**To:**

```
build/kernel/zImage
build/kernel/am335x-boneblack-custom.dtb
```

**Why copy?**

- Centralized location for all artifacts
- Easy to find for deployment
- Separate from source tree (clean separation)

---

### Complete Build Output

```bash
bash scripts/build.sh kernel
```

**Output:**

```
[build] kernel
  HOSTCC  scripts/basic/fixdep
  HOSTCC  scripts/kconfig/conf.o
  ...
  GEN     Makefile
#
# configuration written to .config
#
  CC      init/main.o
  CC      init/version.o
  ...
  LD      vmlinux
  SORTEX  vmlinux
  SYSMAP  System.map
  OBJCOPY arch/arm/boot/Image
  Kernel: arch/arm/boot/Image is ready
  GZIP    arch/arm/boot/compressed/piggy.gzip
  AS      arch/arm/boot/compressed/piggy.gzip.o
  LD      arch/arm/boot/compressed/vmlinux
  OBJCOPY arch/arm/boot/zImage
  Kernel: arch/arm/boot/zImage is ready
  DTC     arch/arm/boot/dts/am335x-boneblack-custom.dtb
  CC [M]  drivers/gpio/gpio-omap.o
  LD [M]  drivers/gpio/gpio-omap.ko
  ...
[build] kernel done → /workspace/build/kernel/
```

**Time:** ~3-5 minutes (first build), ~30 seconds (incremental)

---

## build_uboot() - U-Boot Bootloader Build

### Source Code

```bash
build_uboot() {
    local out="${BUILD_DIR}/uboot"
    mkdir -p "${out}"
    echo "[build] uboot"
    cd "${UBOOT_DIR}"
    make CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_custom_defconfig
    make CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)"
    if [[ ! -f MLO || ! -f u-boot.img ]]; then
        echo "[build] ERROR: MLO or u-boot.img not produced" >&2
        exit 1
    fi
    cp MLO u-boot.img "${out}/"
    echo "[build] uboot done → ${out}/"
}
```

### Step-by-Step Explanation

#### 1. Configure U-Boot

```bash
make CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_custom_defconfig
```

**What is am335x_boneblack_custom_defconfig?**

```
u-boot/configs/
├── am335x_boneblack_custom_defconfig  ← BeagleBone Black (Custom)
├── am335x_evm_defconfig               ← AM335x EVM (Generic)
├── rpi_3_defconfig                    ← Raspberry Pi 3
└── ...
```

**Creates `.config` with U-Boot options:**

```
CONFIG_ARM=y
CONFIG_ARCH_OMAP2PLUS=y
CONFIG_TARGET_AM335X_EVM=y
CONFIG_SPL=y
CONFIG_SPL_FRAMEWORK=y
...
```

---

#### 2. Build U-Boot

```bash
make CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)"
```

**Builds two files:**

##### MLO (Memory LOader) - First Stage Bootloader

**What is MLO?**

- **SPL** (Secondary Program Loader)
- First code that runs after ROM bootloader
- Fits in internal SRAM (128 KB limit)
- Initializes DDR RAM
- Loads U-Boot from SD card to RAM

**Boot sequence:**

```
Power on
    ↓
ROM bootloader (in SoC, read-only)
    ↓
Loads MLO from SD card to SRAM
    ↓
MLO runs (initializes DDR)
    ↓
MLO loads u-boot.img to DDR
    ↓
U-Boot runs (full bootloader)
    ↓
U-Boot loads kernel
```

**Why two stages?**

- ROM bootloader can only load to SRAM (128 KB)
- Full U-Boot is ~500 KB (doesn't fit in SRAM)
- MLO is small (~100 KB), fits in SRAM
- MLO initializes DDR, then loads full U-Boot

**MLO size constraint:**

```bash
ls -lh MLO
# -rw-r--r-- 1 builder builder 103K Apr 20 10:00 MLO
# Must be < 128 KB to fit in SRAM!
```

---

##### u-boot.img - Second Stage Bootloader

**What is u-boot.img?**

- Full-featured bootloader
- Runs from DDR RAM (no size limit)
- Provides command-line interface
- Loads kernel from SD/eMMC/TFTP/USB

**Features:**

- Boot from multiple sources (SD, eMMC, TFTP, USB)
- Environment variables (bootargs, bootcmd)
- Scripting support
- Network support (TFTP, DHCP)
- File system support (FAT, ext4)

**Size:**

```bash
ls -lh u-boot.img
# -rw-r--r-- 1 builder builder 487K Apr 20 10:00 u-boot.img
```

---

#### 3. Verify Artifacts

```bash
if [[ ! -f MLO || ! -f u-boot.img ]]; then
    echo "[build] ERROR: MLO or u-boot.img not produced" >&2
    exit 1
fi
```

**Why this check?**

U-Boot build can succeed but not produce files if:

- Wrong defconfig selected
- SPL disabled in config
- Build error ignored

**`>&2` = redirect to stderr:**

```bash
echo "normal message"        # stdout (file descriptor 1)
echo "error message" >&2     # stderr (file descriptor 2)
```

**Why separate stderr?**

```bash
# Capture only stdout:
bash scripts/build.sh uboot > output.log
# Errors still visible on terminal

# Capture both:
bash scripts/build.sh uboot > output.log 2>&1
# Everything in output.log
```

---

#### 4. Copy Artifacts

```bash
cp MLO u-boot.img "${out}/"
```

**From:**

```
u-boot/MLO
u-boot/u-boot.img
```

**To:**

```
build/uboot/MLO
build/uboot/u-boot.img
```

---

### Complete Build Output

```bash
bash scripts/build.sh uboot
```

**Output:**

```
[build] uboot
  HOSTCC  tools/mkimage
  CC      arch/arm/cpu/armv7/start.o
  CC      arch/arm/cpu/armv7/cpu.o
  ...
  LD      spl/u-boot-spl
  OBJCOPY spl/u-boot-spl-nodtb.bin
  COPY    spl/u-boot-spl.bin
  MKIMAGE MLO
  CC      common/main.o
  CC      common/board_f.o
  ...
  LD      u-boot
  OBJCOPY u-boot-nodtb.bin
  COPY    u-boot.bin
  MKIMAGE u-boot.img
[build] uboot done → /workspace/build/uboot/
```

**Time:** ~1-2 minutes

---

## build_driver() - Out-of-Tree Driver Build

### Source Code

```bash
build_driver() {
    local name="${1:?driver name required}"
    local driver_dir="${REPO_ROOT}/drivers/${name}"
    if [[ ! -d "${driver_dir}" ]]; then
        echo "[build] ERROR: drivers/${name}/ not found" >&2
        exit 1
    fi
    local out="${BUILD_DIR}/drivers/${name}"
    mkdir -p "${out}"
    echo "[build] driver ${name}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KERNEL_DIR="${KERNEL_DIR}" -C "${driver_dir}"
    find "${driver_dir}" -name "*.ko" -exec cp {} "${out}/" \;
    echo "[build] driver ${name} done → ${out}/"
}
```

### Step-by-Step Explanation

#### 1. Parameter Validation

```bash
local name="${1:?driver name required}"
```

**Bash parameter expansion with error:**

```bash
${VAR:?error message}
# If VAR is set → use VAR
# If VAR is unset → print error and exit
```

**Example:**

```bash
# Correct usage:
bash scripts/build.sh driver led-gpio
# name = "led-gpio"

# Missing argument:
bash scripts/build.sh driver
# Output: bash: 1: driver name required
# Exit code: 1
```

---

#### 2. Check Driver Directory Exists

```bash
local driver_dir="${REPO_ROOT}/drivers/${name}"
if [[ ! -d "${driver_dir}" ]]; then
    echo "[build] ERROR: drivers/${name}/ not found" >&2
    exit 1
fi
```

**`[[ ! -d "${driver_dir}" ]]`:**

- `-d` = check if directory exists
- `!` = negate (true if directory does NOT exist)

**Example:**

```bash
# Driver exists:
bash scripts/build.sh driver led-gpio
# driver_dir = /workspace/drivers/led-gpio
# Directory exists → continue

# Driver doesn't exist:
bash scripts/build.sh driver nonexistent
# driver_dir = /workspace/drivers/nonexistent
# Directory doesn't exist → error and exit
```

---

#### 3. Build Driver

```bash
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KERNEL_DIR="${KERNEL_DIR}" -C "${driver_dir}"
```

**`-C` flag:**

- Change to directory before running make
- Equivalent to: `cd "${driver_dir}" && make ...`

**Variables passed to driver Makefile:**

```makefile
# drivers/led-gpio/Makefile
obj-m := led-gpio.o

# KERNEL_DIR passed from build.sh
KERNEL_DIR ?= /workspace/linux

all:
	make -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	make -C $(KERNEL_DIR) M=$(PWD) clean
```

**What happens:**

```
1. make -C drivers/led-gpio
2. Driver Makefile runs: make -C /workspace/linux M=/workspace/drivers/led-gpio modules
3. Kernel build system compiles driver
4. Output: drivers/led-gpio/led-gpio.ko
```

---

#### 4. Find and Copy Module

```bash
find "${driver_dir}" -name "*.ko" -exec cp {} "${out}/" \;
```

**`find` command breakdown:**

```bash
find "${driver_dir}"     # Search in driver directory
  -name "*.ko"           # Find files matching *.ko
  -exec cp {} "${out}/" \;  # Execute: cp <found_file> <output_dir>
```

**Why use `find`?**

- Driver might produce multiple .ko files
- .ko might be in subdirectory
- Flexible (works with any driver structure)

**Example:**

```bash
# Simple driver:
drivers/led-gpio/
└── led-gpio.ko

# Complex driver:
drivers/complex/
├── main.ko
├── subdir/
│   └── helper.ko
└── another.ko

# find copies all .ko files
```

**`{}` and `\;` explained:**

```bash
find . -name "*.ko" -exec cp {} /tmp/ \;
# For each file found:
#   {} = replaced with filename
#   \; = end of -exec command
# Example: cp ./led-gpio.ko /tmp/
```

---

### Complete Build Output

```bash
bash scripts/build.sh driver led-gpio
```

**Output:**

```
[build] driver led-gpio
make -C /workspace/linux M=/workspace/drivers/led-gpio modules
make[1]: Entering directory '/workspace/linux'
  CC [M]  /workspace/drivers/led-gpio/led-gpio.o
  MODPOST /workspace/drivers/led-gpio/Module.symvers
  CC [M]  /workspace/drivers/led-gpio/led-gpio.mod.o
  LD [M]  /workspace/drivers/led-gpio/led-gpio.ko
make[1]: Leaving directory '/workspace/linux'
[build] driver led-gpio done → /workspace/build/drivers/led-gpio/
```

**Time:** ~10-30 seconds

---

## build_all() - Build Everything

### Source Code

```bash
build_all() {
    build_kernel
    build_uboot
    for driver_dir in "${REPO_ROOT}"/drivers/*/; do
        [[ -d "${driver_dir}" ]] || continue
        build_driver "$(basename "${driver_dir}")"
    done
}
```

### Step-by-Step Explanation

#### 1. Build Kernel and U-Boot

```bash
build_kernel
build_uboot
```

**Sequential execution:**

- Kernel first (drivers need kernel headers)
- U-Boot second (independent of kernel)

---

#### 2. Loop Through All Drivers

```bash
for driver_dir in "${REPO_ROOT}"/drivers/*/; do
    [[ -d "${driver_dir}" ]] || continue
    build_driver "$(basename "${driver_dir}")"
done
```

**Glob pattern: `drivers/*/`**

```bash
"${REPO_ROOT}"/drivers/*/
# Expands to:
/workspace/drivers/led-gpio/
/workspace/drivers/i2c-sensor/
/workspace/drivers/pwm-fan/
```

**`[[ -d "${driver_dir}" ]] || continue`:**

- Check if it's a directory
- If not → skip (continue to next iteration)
- Handles case where glob matches files

**`basename` extracts directory name:**

```bash
driver_dir="/workspace/drivers/led-gpio/"
basename "${driver_dir}"
# Output: led-gpio

# Then calls:
build_driver "led-gpio"
```

---

### Complete Build Output

```bash
bash scripts/build.sh all
```

**Output:**

```
[build] kernel
  ...
  Kernel: arch/arm/boot/zImage is ready
[build] kernel done → /workspace/build/kernel/

[build] uboot
  ...
  MKIMAGE u-boot.img
[build] uboot done → /workspace/build/uboot/

[build] driver led-gpio
  LD [M]  /workspace/drivers/led-gpio/led-gpio.ko
[build] driver led-gpio done → /workspace/build/drivers/led-gpio/

[build] driver i2c-sensor
  LD [M]  /workspace/drivers/i2c-sensor/i2c-sensor.ko
[build] driver i2c-sensor done → /workspace/build/drivers/i2c-sensor/

[build] driver pwm-fan
  LD [M]  /workspace/drivers/pwm-fan/pwm-fan.ko
[build] driver pwm-fan done → /workspace/build/drivers/pwm-fan/
```

**Time:** ~5-7 minutes (first build), ~1 minute (incremental)

---

## Argument Parsing

### Source Code

```bash
if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    kernel) build_kernel ;;
    uboot)  build_uboot ;;
    driver)
        [[ $# -ge 2 ]] || usage
        build_driver "$2"
        ;;
    all)    build_all ;;
    *)      usage ;;
esac
```

### Explanation

#### 1. Check Argument Count

```bash
if [[ $# -lt 1 ]]; then
    usage
fi
```

**`$#` = number of arguments:**

```bash
bash scripts/build.sh kernel
# $# = 1

bash scripts/build.sh driver led-gpio
# $# = 2

bash scripts/build.sh
# $# = 0 → call usage() and exit
```

---

#### 2. Case Statement

```bash
case "$1" in
    kernel) build_kernel ;;
    uboot)  build_uboot ;;
    driver)
        [[ $# -ge 2 ]] || usage
        build_driver "$2"
        ;;
    all)    build_all ;;
    *)      usage ;;
esac
```

**Pattern matching:**

```bash
# $1 = "kernel"
case "kernel" in
    kernel) build_kernel ;;  ← Matches! Execute this
    ...
esac

# $1 = "invalid"
case "invalid" in
    kernel) ... ;;
    uboot) ... ;;
    driver) ... ;;
    all) ... ;;
    *)      usage ;;  ← Matches! (catch-all)
esac
```

---

#### 3. Driver Special Case

```bash
driver)
    [[ $# -ge 2 ]] || usage
    build_driver "$2"
    ;;
```

**Why check `$# -ge 2`?**

```bash
# Correct:
bash scripts/build.sh driver led-gpio
# $1 = "driver"
# $2 = "led-gpio"
# $# = 2 → OK

# Missing driver name:
bash scripts/build.sh driver
# $1 = "driver"
# $2 = (empty)
# $# = 1 → call usage() and exit
```

---

## Summary

**Four build functions:**

1. **`build_kernel()`**
   - Configure: `am335x_boneblack_defconfig`
   - Build: `zImage`, `dtbs`, `modules`
   - Output: `build/kernel/zImage`, `build/kernel/am335x-boneblack-custom.dtb`

2. **`build_uboot()`**
   - Configure: `am335x_boneblack_custom_defconfig`
   - Build: `MLO`, `u-boot.img`
   - Output: `build/uboot/MLO`, `build/uboot/u-boot.img`

3. **`build_driver()`**
   - Build: out-of-tree kernel module
   - Output: `build/drivers/<name>/<name>.ko`

4. **`build_all()`**
   - Orchestrates: kernel → uboot → all drivers

**Key techniques:**

- `local` variables (function scope)
- Error checking (`if [[ ! -f ... ]]`)
- Parallel builds (`-j$(nproc)`)
- Artifact copying (centralized `build/` directory)
- Glob patterns (`drivers/*/`)
- `find` with `-exec` (flexible file search)

---

## References

- Kernel build system: https://www.kernel.org/doc/html/latest/kbuild/index.html
- U-Boot build system: https://u-boot.readthedocs.io/en/latest/build/index.html
- Device Tree: https://www.devicetree.org/
- Kernel modules: https://www.kernel.org/doc/html/latest/kbuild/modules.html
- AM335x TRM: https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
