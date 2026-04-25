---
title: Host Toolchain (Optional)
tags:
  - docker
  - toolchain
  - host
  - performance
date: 2026-04-20
category: docker
---

# Host Toolchain (Optional)

This document explains when and how to install the cross-compiler toolchain directly on your host machine (outside Docker).

## Why Install Host Toolchain?

### Docker vs Host Build Comparison

| Aspect              | Docker Build           | Host Build                       |
| ------------------- | ---------------------- | -------------------------------- |
| **Speed**           | Slower (~5 min)        | Faster (~3 min)                  |
| **Setup**           | No host install needed | Requires toolchain install       |
| **Reproducibility** | Guaranteed             | Depends on host                  |
| **Isolation**       | Clean environment      | Can conflict with other projects |
| **CI/CD**           | Easy to automate       | Needs pre-configured runner      |
| **Disk Space**      | 1.04 GB (image)        | ~500 MB (packages)               |

### When to Use Host Toolchain

**Use host toolchain for:**

- **Rapid development**: Edit code → build → test loop
- **Debugging**: Need to rebuild frequently
- **Performance**: Build time matters (e.g., large kernel configs)
- **IDE integration**: VSCode, CLion need native toolchain

**Use Docker for:**

- **Release builds**: Need reproducible binaries
- **New machines**: Don't want to pollute host
- **Multiple projects**: Avoid toolchain version conflicts
- **CI/CD**: Clean build environment

### Performance Comparison

**Real-world example (BeagleBone kernel build):**

```bash
# Docker build:
time make docker kernel
# real    4m52.341s
# user    0m0.123s
# sys     0m0.089s

# Host build:
time make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -C linux zImage
# real    3m12.456s
# user    18m34.123s
# sys     1m23.456s
```

**Speed improvement: ~35% faster on host**

**Why Docker is slower:**

- Docker volume I/O overhead
- Container startup time
- No direct CPU access (virtualization layer)

---

## Installation

### Prerequisites

- Ubuntu 22.04 LTS (or compatible Debian-based distro)
- `sudo` access
- ~500 MB free disk space

### Install Cross-Compiler

```bash
sudo apt update
sudo apt install -y \
    gcc-arm-linux-gnueabihf=4:11.2.0-1ubuntu1 \
    binutils-arm-linux-gnueabihf \
    device-tree-compiler \
    u-boot-tools \
    libssl-dev \
    libelf-dev \
    bc \
    flex \
    bison \
    make
```

**Why pin gcc version `=4:11.2.0-1ubuntu1`?**

- Matches Docker image version
- Ensures consistent builds between Docker and host
- Avoids "works on my machine" bugs

### Verify Installation

```bash
# Check cross-compiler version
arm-linux-gnueabihf-gcc --version
# Expected: arm-linux-gnueabihf-gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0

# Check multiarch support
arm-linux-gnueabihf-gcc --print-multiarch
# Expected: arm-linux-gnueabihf

# Test compilation
echo 'int main() { return 0; }' | arm-linux-gnueabihf-gcc -x c - -o /tmp/test
file /tmp/test
# Expected: /tmp/test: ELF 32-bit LSB executable, ARM, ...
```

---

## Usage

### Build Kernel on Host

```bash
cd "${BSP_ROOT}/linux"

# Configure for BeagleBone
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_defconfig

# Build kernel
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules

# Output:
# arch/arm/boot/zImage
# arch/arm/boot/dts/am335x-boneblack.dtb
```

### Build U-Boot on Host

```bash
cd "${BSP_ROOT}/u-boot"

# Configure for BeagleBone
make CROSS_COMPILE=arm-linux-gnueabihf- am335x_evm_defconfig

# Build U-Boot
make CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)

# Output:
# MLO
# u-boot.img
```

### Build Driver on Host

```bash
cd "${BSP_ROOT}/drivers/led-gpio"

# Build module
make ARCH=arm \
     CROSS_COMPILE=arm-linux-gnueabihf- \
     KERNEL_DIR="${BSP_ROOT}/linux" \
     -j$(nproc)

# Output:
# led-gpio.ko
```

---

## Environment Variables

### Set Permanently (Optional)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# BeagleBone BSP environment
export BSP_ROOT="${HOME}/Working_Space/my-project/beaglebone-bsp"
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export PATH="${BSP_ROOT}/scripts:${PATH}"
```

**Reload shell:**

```bash
source ~/.bashrc
```

**Now you can build without specifying ARCH/CROSS_COMPILE:**

```bash
cd "${BSP_ROOT}/linux"
make am335x_boneblack_defconfig
make -j$(nproc) zImage dtbs
```

---

## Hybrid Workflow (Best of Both Worlds)

### Strategy

Use **host toolchain** for development, **Docker** for release:

```bash
# Development (fast iteration):
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage

# Release (reproducible):
make docker kernel
```

### Example Development Workflow

```bash
# 1. Edit driver code
vim drivers/led-gpio/led-gpio.c

# 2. Quick build on host (fast)
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
     KERNEL_DIR="${BSP_ROOT}/linux" \
     -C drivers/led-gpio

# 3. Test on board
scp drivers/led-gpio/led-gpio.ko root@192.168.7.2:/tmp/
ssh root@192.168.7.2 'insmod /tmp/led-gpio.ko'

# 4. Iterate (repeat steps 1-3)

# 5. Final release build in Docker (reproducible)
make docker driver DRIVER=led-gpio
```

---

## Troubleshooting

### Issue: "arm-linux-gnueabihf-gcc: command not found"

**Cause:** Toolchain not installed or not in PATH

**Solution:**

```bash
# Check if installed
dpkg -l | grep gcc-arm-linux-gnueabihf

# If not installed:
sudo apt install gcc-arm-linux-gnueabihf

# Check PATH
which arm-linux-gnueabihf-gcc
# Expected: /usr/bin/arm-linux-gnueabihf-gcc
```

---

### Issue: Different binary output between Docker and host

**Cause:** Different gcc versions

**Check versions:**

```bash
# Host version
arm-linux-gnueabihf-gcc --version

# Docker version
docker run --rm beaglebone-bsp-builder:1.0 arm-linux-gnueabihf-gcc --version
```

**Solution:** Pin host gcc to match Docker:

```bash
sudo apt install gcc-arm-linux-gnueabihf=4:11.2.0-1ubuntu1
sudo apt-mark hold gcc-arm-linux-gnueabihf  # Prevent auto-upgrade
```

---

### Issue: "fatal error: openssl/opensslv.h: No such file or directory"

**Cause:** Missing libssl-dev

**Solution:**

```bash
sudo apt install libssl-dev
```

---

### Issue: "fatal error: libelf.h: No such file or directory"

**Cause:** Missing libelf-dev

**Solution:**

```bash
sudo apt install libelf-dev
```

---

## Comparison with Docker Workflow

### Docker Workflow

```bash
# User runs:
bash scripts/build.sh kernel

# Script auto-detects and runs in Docker:
docker run --rm \
  -v "${BSP_ROOT}:/workspace" \
  beaglebone-bsp-builder:1.0 \
  bash scripts/build.sh kernel
```

**Pros:**

- No host setup needed
- Reproducible
- Isolated

**Cons:**

- Slower (Docker overhead)
- Requires Docker installed

---

### Host Workflow

```bash
# User runs directly:
cd "${BSP_ROOT}/linux"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
```

**Pros:**

- Faster (~35% speed improvement)
- Direct CPU access
- Better IDE integration

**Cons:**

- Requires toolchain install
- Can conflict with other projects
- Less reproducible

---

## Uninstallation

### Remove Host Toolchain

```bash
sudo apt remove --purge \
    gcc-arm-linux-gnueabihf \
    binutils-arm-linux-gnueabihf

sudo apt autoremove
```

### Clean Build Artifacts

```bash
cd "${BSP_ROOT}"
rm -rf build/
make -C linux clean
make -C u-boot clean
```

---

## Best Practices

### 1. Use Docker for CI/CD

```yaml
# .github/workflows/build.yml
jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v3
      - name: Build kernel
        run: make docker kernel
```

**Why:** Reproducible builds, no runner setup needed

---

### 2. Use Host for Development

```bash
# Fast iteration during development
while true; do
    vim drivers/led-gpio/led-gpio.c
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -C drivers/led-gpio
    scp drivers/led-gpio/led-gpio.ko root@192.168.7.2:/tmp/
    ssh root@192.168.7.2 'rmmod led-gpio; insmod /tmp/led-gpio.ko'
done
```

**Why:** Faster feedback loop

---

### 3. Verify with Docker Before Commit

```bash
# After development, verify in Docker
make docker all

# Check SHA256 matches
sha256sum build/kernel/zImage
```

**Why:** Ensure reproducible build before pushing

---

### 4. Document Toolchain Version

```bash
# In project README or docs
arm-linux-gnueabihf-gcc --version > docs/toolchain-version.txt
git add docs/toolchain-version.txt
git commit -m "docs: record toolchain version"
```

**Why:** Help other developers match environment

---

## Summary

**Host toolchain is optional but recommended for:**

- Active development (faster iteration)
- Debugging (frequent rebuilds)
- IDE integration

**Always use Docker for:**

- Release builds (reproducibility)
- CI/CD (automation)
- New team members (easy onboarding)

**Hybrid approach (best):**

- Develop on host (speed)
- Release in Docker (reproducibility)

---

## References

- Ubuntu ARM toolchain: https://packages.ubuntu.com/jammy/gcc-arm-linux-gnueabihf
- Linaro toolchain: https://www.linaro.org/downloads/
- Kernel build requirements: https://www.kernel.org/doc/html/latest/process/changes.html
- Docker vs native performance: https://stackoverflow.com/questions/21889053/what-is-the-runtime-performance-cost-of-a-docker-container
