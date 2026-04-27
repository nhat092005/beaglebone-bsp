# Reproducible Build Configuration

This document explains how reproducible builds are achieved for the BeagleBone BSP kernel.

## What is Reproducible Build?

A reproducible build ensures that building the same source code twice produces byte-for-byte identical binaries. This is critical for:

- Security auditing
- Supply chain verification
- Build system validation

## Implementation

### Root Cause Analysis

Using `diffoscope`, we identified two main sources of non-determinism:

1. **Debug Information** (`CONFIG_DEBUG_INFO=y`)
   - Embeds absolute build paths
   - Contains build timestamps
   - Creates `.dwo` (DWARF debug object) files with varying content

2. **Build Version Number** (auto-incrementing)
   - Kernel increments version on each build
   - Embedded in kernel binary

### Solution

#### 1. Config Fragment: `linux/configs/reproducible.config`

```
CONFIG_DEBUG_INFO=n
CONFIG_DEBUG_INFO_SPLIT=n
CONFIG_DEBUG_INFO_DWARF4=n
CONFIG_DEBUG_INFO_BTF=n
CONFIG_DEBUG_INFO_REDUCED=n
CONFIG_IKCONFIG=n
CONFIG_IKCONFIG_PROC=n
```

Applied via `scripts/kconfig/merge_config.sh` after `omap2plus_defconfig`.

#### 2. Build Environment Variables

Set by `scripts/build.sh` when running the reproducible kernel mode:

```bash
KBUILD_BUILD_TIMESTAMP="<UTC timestamp from kernel git commit>"
KBUILD_BUILD_USER="builder"
KBUILD_BUILD_HOST="bsp-build"
SOURCE_DATE_EPOCH="<kernel git commit timestamp>"
KBUILD_BUILD_VERSION="1"
KCONFIG_NOTIMESTAMP="1"
LC_ALL="C"
```

Run it explicitly:

```bash
bash scripts/build.sh kernel reproducible
```

## Verification

Run the reproducible build test:

```bash
bash tests/test-reproducible-build.sh
```

Expected output:

```
✓ PASS: Reproducible build verified (3/3 builds identical)
  SHA256: 02c56c81d11ca483a4362b0852f6971ffb329451c800066880853aab8c42bdda
```

## Manual Verification

```bash
# Build 1
bash scripts/build.sh kernel reproducible
sha256sum build/kernel/zImage

# Build 2
bash scripts/build.sh kernel reproducible
sha256sum build/kernel/zImage

# Compare - should be identical
```

## Trade-offs

### What We Disabled

- **Debug symbols**: No DWARF debug info in kernel binary
  - Impact: Cannot use `gdb` with full symbol information on kernel binary
  - Mitigation: Debug symbols can be re-enabled for development builds
  - Note: Kernel still has `CONFIG_KALLSYMS=y` for basic symbol resolution

- **IKCONFIG**: Kernel config not embedded in `/proc/config.gz`
  - Impact: Cannot extract build config from running kernel
  - Mitigation: Config is available in source tree and build artifacts

### What We Kept

- **KALLSYMS**: Kernel symbol table for stack traces and debugging
- **All functional features**: No impact on kernel functionality
- **Module support**: Out-of-tree modules still work

## References

- Reproducible Builds project: https://reproducible-builds.org/
- Linux kernel reproducible builds: https://www.kernel.org/doc/html/latest/kbuild/reproducible-builds.html
- Diffoscope tool: https://diffoscope.org/

## Verified Builds

- Kernel version: 5.10.253
- Defconfig: omap2plus_defconfig + reproducible.config
- Toolchain: gcc-arm-linux-gnueabihf 11.4.0
- Verified: 2026-04-21
- SHA256: `02c56c81d11ca483a4362b0852f6971ffb329451c800066880853aab8c42bdda`
