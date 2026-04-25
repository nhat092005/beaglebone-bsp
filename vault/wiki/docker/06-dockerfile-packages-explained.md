---
title: Dockerfile Packages Explained
tags:
  - docker
  - toolchain
  - packages
date: 2026-04-20
category: docker
---

# Dockerfile Packages Explained

This document explains every package installed in `docker/Dockerfile` and why it's needed for BeagleBone BSP development.

## Base Image

```dockerfile
FROM ubuntu@sha256:962f6cadeae0ea6284001009daa4cc9a8c37e75d1f5191cf0eb83fe565b63dd7
```

**Why Ubuntu 22.04?**

- LTS (Long Term Support) until 2027
- Stable toolchain versions
- Well-tested for embedded development

**Why SHA256 digest instead of tag?**

- `ubuntu:22.04` tag is mutable (can change over time)
- SHA256 digest is immutable (guarantees exact same base image)
- Ensures reproducible builds across all developers

---

## Layer 1: Cross-Compiler & Kernel Build Dependencies

```dockerfile
RUN apt-get update && apt-get install -y \
    gcc \
    gcc-arm-linux-gnueabihf=4:11.2.0-1ubuntu1 \
    binutils-arm-linux-gnueabihf \
    libssl-dev \
    libelf-dev \
    && rm -rf /var/lib/apt/lists/*
```

### gcc (Native Compiler)

**Purpose:** Compile tools that run on the build machine (x86_64)

**Used for:**

- Building kernel build tools (e.g., `scripts/basic/fixdep`)
- Compiling host utilities

**Not used for:** Compiling kernel or drivers (that's the cross-compiler's job)

---

### gcc-arm-linux-gnueabihf (Cross-Compiler)

**Purpose:** Compile code for ARM architecture from x86_64 host

**Why cross-compilation is needed:**

```
Your PC:         x86_64 (Intel/AMD CPU)
BeagleBone:      ARM Cortex-A8 (ARM CPU)

x86_64 binary ≠ ARM binary
```

**Example:**

```bash
# Native compile (for your PC):
gcc hello.c -o hello_x86
file hello_x86
# Output: ELF 64-bit LSB executable, x86-64

# Cross-compile (for BeagleBone):
arm-linux-gnueabihf-gcc hello.c -o hello_arm
file hello_arm
# Output: ELF 32-bit LSB executable, ARM
```

**Toolchain name breakdown:**

```
arm-linux-gnueabihf
│   │     │
│   │     └─ hf = Hard Float (hardware FPU support)
│   └─────── linux = Target OS is Linux
└─────────── arm = Target architecture is ARM
```

**Why pin version `=4:11.2.0-1ubuntu1`?**

- Ensures everyone uses the exact same compiler version
- Avoids "works on my machine" bugs
- Different gcc versions can produce different binaries

---

### binutils-arm-linux-gnueabihf

**Purpose:** Binary utilities for ARM architecture

**Includes:**

- `as` (assembler): assembly code → machine code
- `ld` (linker): link object files → executable
- `objdump`: inspect binary contents
- `objcopy`: convert binary formats
- `strip`: remove debug symbols (reduce size)
- `nm`: list symbols in object files
- `readelf`: display ELF file information

**Example usage:**

```bash
# Inspect kernel module symbols
arm-linux-gnueabihf-nm led-gpio.ko

# View kernel image sections
arm-linux-gnueabihf-objdump -h zImage

# Strip debug symbols to reduce size
arm-linux-gnueabihf-strip u-boot.img
```

---

### libssl-dev

**Purpose:** OpenSSL development headers and libraries

**Why kernel needs it:**

- Sign kernel modules (module signing)
- Generate certificates
- Cryptographic operations in kernel

**Example:**

```bash
# Kernel build uses OpenSSL to sign modules
scripts/sign-file sha256 signing_key.priv signing_key.x509 module.ko
```

**Without libssl-dev:**

```
make[1]: *** No rule to make target 'certs/signing_key.pem'
```

---

### libelf-dev

**Purpose:** ELF (Executable and Linkable Format) library

**Why kernel needs it:**

- Kernel modules are ELF files
- Parse and manipulate ELF headers
- Module loading infrastructure

**Example:**

```bash
# Check if file is valid ELF
readelf -h led-gpio.ko
# ELF Header:
#   Class:                             ELF32
#   Data:                              2's complement, little endian
#   Machine:                           ARM
```

**Without libelf-dev:**

```
*** Unable to find libelf. Install libelf-dev or elfutils-libelf-devel
```

---

## Layer 2: Kernel & Build Tools

```dockerfile
RUN apt-get update && apt-get install -y \
    make \
    bc \
    flex \
    bison \
    device-tree-compiler \
    u-boot-tools \
    gawk \
    diffstat \
    texinfo \
    chrpath \
    && rm -rf /var/lib/apt/lists/*
```

### make

**Purpose:** Build automation tool

**Why kernel needs it:**

- Kernel uses complex Makefile system
- Manages dependencies between thousands of source files
- Parallel builds: `make -j$(nproc)`

**Example:**

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
```

---

### bc (Basic Calculator)

**Purpose:** Command-line calculator for shell scripts

**Why kernel needs it:**

- Kernel Makefiles perform arithmetic calculations
- Compute memory addresses, offsets, sizes

**Example from kernel Makefile:**

```makefile
# Calculate load address
LOAD_ADDR := $(shell echo "0x80000000 + 0x8000" | bc)
```

**Without bc:**

```
/bin/sh: 1: bc: not found
make[1]: *** [arch/arm/boot/Makefile:94: arch/arm/boot/zImage] Error 127
```

---

### flex & bison

**Purpose:** Lexer and parser generators

**Why kernel needs it:**

- Parse kernel configuration files (`.config`)
- Parse device tree syntax
- Generate parsers from grammar files

**Kernel uses them for:**

```
scripts/kconfig/zconf.l  (flex)  → lexer for Kconfig
scripts/kconfig/zconf.y  (bison) → parser for Kconfig
scripts/dtc/dtc-lexer.l  (flex)  → lexer for device tree
scripts/dtc/dtc-parser.y (bison) → parser for device tree
```

**Without flex/bison:**

```
HOSTCC  scripts/kconfig/zconf.tab.o
/bin/sh: 1: flex: not found
```

---

### device-tree-compiler (dtc)

**Purpose:** Compile device tree source (.dts) to binary (.dtb)

**Why it's critical:**

ARM boards have thousands of variants with different hardware:

- Different GPIO pins
- Different I2C/SPI/UART addresses
- Different peripherals

**Device Tree describes hardware to kernel:**

```dts
// am335x-boneblack-custom.dts
&uart1 {
    status = "okay";
    pinctrl-0 = <&uart1_pins>;
};

&i2c1 {
    status = "okay";
    clock-frequency = <100000>;

    tmp102: sensor@48 {
        compatible = "ti,tmp102";
        reg = <0x48>;
    };
};
```

**Compilation:**

```bash
dtc -I dts -O dtb -o am335x-boneblack-custom.dtb am335x-boneblack-custom.dts
```

**Kernel reads .dtb at boot to discover hardware.**

---

### u-boot-tools

**Purpose:** U-Boot image creation tools

**Includes:**

- `mkimage`: Create U-Boot bootable images
- `mkenvimage`: Create U-Boot environment images

**Why needed:**

U-Boot expects images in specific format (with header):

```bash
# Wrap kernel image for U-Boot
mkimage -A arm -O linux -T kernel -C none \
  -a 0x80008000 -e 0x80008000 \
  -n "Linux Kernel" -d zImage uImage
```

**Without mkimage:**

```
U-Boot# bootm 0x82000000
Wrong Image Format for bootm command
```

---

### gawk, diffstat, texinfo, chrpath

**Purpose:** Supporting utilities for build system

- **gawk**: Text processing in Makefiles and scripts
- **diffstat**: Generate statistics from patches (used by Yocto)
- **texinfo**: Generate documentation
- **chrpath**: Modify RPATH in binaries (used by Yocto)

---

## Layer 3: Scripting, Fetch & Utilities

```dockerfile
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    rsync \
    minicom \
    shellcheck \
    cppcheck \
    python3 \
    python3-pip \
    xz-utils \
    cpio \
    socat \
    unzip \
    debianutils \
    iputils-ping \
    file \
    && rm -rf /var/lib/apt/lists/*
```

### wget & curl

**Purpose:** Download files from internet

**Used for:**

- Download kernel source tarballs
- Fetch patches from mailing lists
- Download firmware blobs

**Example:**

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.210.tar.xz
```

---

### git

**Purpose:** Version control system

**Used for:**

- Clone kernel source: `git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git`
- Clone U-Boot source
- Track BSP changes
- Apply patches: `git am 0001-fix.patch`

---

### rsync

**Purpose:** Efficient file synchronization

**Used for:**

- Deploy kernel to board: `rsync -avz zImage root@192.168.7.2:/boot/`
- Sync rootfs to SD card
- Faster than `scp` for large directories

**Example:**

```bash
rsync -avz --delete build/rootfs/ /mnt/sdcard/rootfs/
```

---

### minicom

**Purpose:** Serial terminal emulator

**Used for:**

- Connect to BeagleBone serial console
- View U-Boot output
- Debug kernel boot

**Example:**

```bash
minicom -D /dev/ttyUSB0 -b 115200
```

**Serial connection:**

```
PC USB ←→ FTDI cable ←→ BeagleBone UART0 (P9.1, P9.2, P9.4)
```

---

### shellcheck

**Purpose:** Static analysis for shell scripts

**Why it's important:**

Catches bugs before running:

```bash
# Bad script:
if [ $1 = "test" ]; then  # Bug: if $1 is empty → syntax error
    echo "test"
fi

# shellcheck output:
# Line 1: if [ $1 = "test" ]; then
#            ^-- SC2086: Quote to prevent word splitting
```

**Usage:**

```bash
shellcheck scripts/build.sh
shellcheck scripts/deploy.sh
shellcheck scripts/flash_sd.sh
```

---

### cppcheck

**Purpose:** Static analysis for C/C++ code

**Used for:**

- Find bugs in driver code
- Detect memory leaks
- Check null pointer dereferences

**Example:**

```c
// driver.c
void func(int *ptr) {
    *ptr = 10;  // Bug: no NULL check!
}

// cppcheck output:
// [driver.c:2]: (error) Possible null pointer dereference: ptr
```

**Usage:**

```bash
cppcheck --enable=all --suppress=missingIncludeSystem drivers/led-gpio/led-gpio.c
```

---

### python3 & python3-pip

**Purpose:** Python interpreter and package manager

**Used for:**

- Kernel build scripts (many are Python)
- Yocto build system (written in Python)
- Custom automation scripts

**Example kernel scripts:**

```
scripts/checkpatch.pl  (Perl, but some use Python)
scripts/decode_stacktrace.sh (calls Python scripts)
```

---

### xz-utils

**Purpose:** Compress/decompress .xz files

**Why needed:**

Kernel source is distributed as `.tar.xz`:

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.210.tar.xz
tar -xf linux-5.10.210.tar.xz  # Needs xz-utils
```

**Without xz-utils:**

```
tar: Cannot use multi-volume compressed archives
tar: Error is not recoverable: exiting now
```

---

### cpio

**Purpose:** Create/extract cpio archives

**Why kernel needs it:**

Kernel uses cpio for initramfs (initial RAM filesystem):

```bash
# Create initramfs
find . | cpio -o -H newc | gzip > initramfs.cpio.gz
```

**Initramfs is embedded in kernel image for early boot.**

---

### socat

**Purpose:** Multipurpose relay tool (SOcket CAT)

**Used for:**

- Serial port forwarding
- Network debugging
- UART over network

**Example:**

```bash
# Forward serial port over network
socat TCP-LISTEN:3333,reuseaddr,fork FILE:/dev/ttyUSB0,raw,echo=0
```

---

### file

**Purpose:** Determine file type

**Used for:**

- Verify compiled binaries are ARM
- Check image formats

**Example:**

```bash
file zImage
# zImage: Linux kernel ARM boot executable zImage (little-endian)

file u-boot.img
# u-boot.img: u-boot legacy uImage, U-Boot 2022.07, Linux/ARM
```

---

### iputils-ping

**Purpose:** Network connectivity testing

**Used for:**

- Check if BeagleBone is reachable: `ping 192.168.7.2`
- Verify network before deploy

---

## Layer 4: Locale

```dockerfile
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
```

### locales

**Purpose:** Language and character encoding support

**Why needed:**

Yocto build system requires UTF-8 locale:

```bash
bitbake core-image-minimal
# ERROR: Your system needs to support the en_US.UTF-8 locale.
```

**Sets:**

- Language: English (US)
- Encoding: UTF-8 (supports international characters)

---

## Environment Variables

```dockerfile
ENV CROSS_COMPILE=arm-linux-gnueabihf- \
    ARCH=arm \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
```

### CROSS_COMPILE

**Purpose:** Prefix for cross-compiler tools

**How kernel uses it:**

```makefile
# In kernel Makefile:
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
AS = $(CROSS_COMPILE)as
```

**Expands to:**

```
$(CROSS_COMPILE)gcc → arm-linux-gnueabihf-gcc
$(CROSS_COMPILE)ld  → arm-linux-gnueabihf-ld
$(CROSS_COMPILE)as  → arm-linux-gnueabihf-as
```

---

### ARCH

**Purpose:** Target architecture for kernel build

**How kernel uses it:**

```
linux/arch/
├── arm/       ← ARCH=arm uses this directory
├── arm64/
├── x86/
├── mips/
└── ...
```

**Selects:**

- Architecture-specific code
- Correct defconfig files
- Proper boot code

---

### LANG & LC_ALL

**Purpose:** Set locale for all processes in container

**Ensures:**

- UTF-8 encoding for all tools
- Consistent text processing
- Yocto sanity checks pass

---

## User & Workdir

```dockerfile
RUN useradd -m -u 1000 builder
USER builder
WORKDIR /workspace
```

### Why create user `builder`?

**Problem with running as root:**

```bash
# Inside container (as root):
docker run --rm -v $(pwd):/workspace ubuntu touch /workspace/file.txt

# On host:
ls -l file.txt
# -rw-r--r-- 1 root root 0 Apr 20 10:00 file.txt
# ← File owned by root! You can't delete it!
```

**Solution: UID 1000 (matches host user):**

```bash
# On host:
id
# uid=1000(nhat) gid=1000(nhat)

# Container also uses UID 1000:
docker run --rm -v $(pwd):/workspace -u 1000 ubuntu touch /workspace/file.txt

# On host:
ls -l file.txt
# -rw-r--r-- 1 nhat nhat 0 Apr 20 10:00 file.txt
# ← File owned by you! OK!
```

---

### USER builder

**Purpose:** Run all subsequent commands as non-root user

**Benefits:**

- Security: Can't accidentally damage system files
- Matches host permissions (UID 1000)
- Best practice for Docker

---

### WORKDIR /workspace

**Purpose:** Set default working directory

**Usage:**

```bash
docker run --rm -v $(pwd):/workspace beaglebone-bsp-builder:1.0 pwd
# Output: /workspace
```

**All commands run from this directory by default.**

---

## Why `rm -rf /var/lib/apt/lists/*`?

**Purpose:** Reduce Docker image size

**How it works:**

```dockerfile
# Without cleanup:
RUN apt-get update          # Download package lists (50 MB)
RUN apt-get install gcc     # Install gcc (200 MB)
# Layer size: 50 MB + 200 MB = 250 MB

# With cleanup:
RUN apt-get update && apt-get install gcc && rm -rf /var/lib/apt/lists/*
# Layer size: 200 MB (package lists deleted)
# Saves 50 MB per layer!
```

**Package lists are only needed during `apt-get install`, not after.**

---

## Summary

**Total packages installed:** ~50

**Categories:**

1. **Cross-compilation:** gcc-arm-linux-gnueabihf, binutils
2. **Kernel build:** make, bc, flex, bison, dtc, libssl-dev, libelf-dev
3. **U-Boot:** u-boot-tools
4. **Development:** git, rsync, python3
5. **Debugging:** minicom, gdb
6. **Static analysis:** shellcheck, cppcheck
7. **Utilities:** wget, curl, xz-utils, cpio, file

**Image size:** ~1.04 GB (optimized with layer cleanup)

**Build time:** ~5 minutes (first build), ~30 seconds (cached)

---

## References

- Ubuntu 22.04 package list: https://packages.ubuntu.com/jammy/
- Yocto system requirements: https://docs.yoctoproject.org/ref-manual/system-requirements.html
- Docker best practices: https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- Kernel build requirements: https://www.kernel.org/doc/html/latest/process/changes.html
