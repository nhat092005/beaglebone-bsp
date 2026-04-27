---
title: Verify Kernel Artifacts
tags:
  - linux
  - kernel
  - verify
last_updated: 2026-04-27
category: kernel
---

# Verify Kernel Artifacts

This project uses an out-of-tree kernel build layout:

- source tree: `linux/`
- active dev build dir: `build/linux/dev`
- exported artifacts: `build/kernel/`

Use the project entry points instead of running ad-hoc in-tree kernel commands.

---

## Recommended Flow

### 1. Rebuild the Docker image

```bash
make docker
```

This ensures the builder image includes the Device Tree schema dependencies needed by `dtbs_check`.

### 2. Rebuild the dev kernel configuration and artifacts

```bash
make kernel-dev KERNEL_JOBS=4 KERNEL_RECONFIGURE=1
```

This does three things:

- regenerates `.config` under `build/linux/dev/`
- re-merges `linux/configs/boneblack-custom.config`
- rebuilds `zImage dtbs modules`

### 3. Run the host-side verification gates

```bash
make kernel-verify
```

This is the canonical host-side verification entry point for Phase 3.

---

## What `make kernel-verify` Checks

`make kernel-verify` runs `scripts/kernel_verify.sh` inside the Docker builder and validates:

1. `linux/Makefile` resolves to a `5.10.<N>` kernel
2. `build/linux/dev/.config` contains:
   - `CONFIG_LOCALVERSION="-bbb-custom"`
   - `# CONFIG_LOCALVERSION_AUTO is not set`
3. `make O=build/linux/dev ... kernelrelease` returns:
   - `5.10.<N>-bbb-custom+`
4. `build/kernel/zImage` exists and has a sane size
5. `build/kernel/am335x-boneblack-custom.dtb` exists
6. `dtbs_check` on the custom DTB reports no custom DTS errors or warnings
7. `W=1 dtbs` introduces no warnings for `am335x-boneblack-custom`

Expected final line:

```text
[kernel-verify] PASS: host-side Phase 3 kernel/DTS gates passed
```

---

## Verify Version Information

```bash
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION) =' linux/Makefile
```

Expected current values:

```text
VERSION = 5
PATCHLEVEL = 10
SUBLEVEL = 253
EXTRAVERSION =
```

The effective kernel version is therefore `5.10.253`.

---

## Verify Kernel Release String

```bash
docker run --rm \
  -v "$(pwd):/workspace" \
  bbb-builder \
  bash -c 'cd /workspace/linux && make O=/workspace/build/linux/dev ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- kernelrelease'
```

Expected:

```text
5.10.253-bbb-custom+
```

This is the string that should later appear in `uname -r` on the board.

---

## Verify Exported Artifacts

### Check zImage

```bash
ls -lh build/kernel/zImage
stat -c '%s' build/kernel/zImage
```

Expected:

- file exists
- size is comfortably above a trivial build sanity threshold

### Check DTB

```bash
ls -lh build/kernel/am335x-boneblack-custom.dtb
```

Expected:

- file exists

---

## Verify Device Tree Schema

The project entry point is:

```bash
make dtbs-check
```

Expected:

```text
No errors/warnings for custom DTS
```

Notes:

- this target filters for messages related to `am335x-boneblack-custom`
- warnings from unrelated upstream ARM DTS files are not the acceptance target here

---

## Verify `W=1` Warning Cleanliness

`make kernel-verify` already checks this.

If you need to run it manually:

```bash
docker run --rm \
  -v "$(pwd):/workspace" \
  bbb-builder \
  bash -c 'cd /workspace/linux && make O=/workspace/build/linux/dev ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- W=1 dtbs >/tmp/w1.log 2>&1 && grep -c "am335x-boneblack-custom.*warning" /tmp/w1.log'
```

Expected:

```text
0
```

---

## Verify on Target (Requires Hardware)

Host-side checks are not enough to close the runtime gates. The following still require a real BBB.

### Boot using `bootz`

Example from U-Boot:

```bash
bootz ${loadaddr} - ${fdtaddr}
```

Expected hand-off:

```text
Starting kernel ...
```

### Check kernel version on the board

```bash
uname -r
```

Expected:

```text
5.10.253-bbb-custom+
```

### Check runtime warnings after idle

```bash
dmesg --level=err,warn -c >/dev/null
sleep 60
dmesg --level=err,warn
```

Acceptance goal:

- no lines attributable to the custom nodes added in Phase 3.4
- especially review messages involving:
  - `4819c000.i2c`
  - custom pinmux
  - UART / SPI / PWM / GPIO button setup

---

## Phase 3 Acceptance Mapping

### Host-side gates

```bash
make docker
make kernel-dev KERNEL_JOBS=4 KERNEL_RECONFIGURE=1
make kernel-verify
```

### Hardware-side gates

Requires BBB:

- `bootz`
- `uname -r`
- `dmesg --level=err,warn`

---

## Related Files

- `docker/Dockerfile`
- `linux/configs/boneblack-custom.config`
- `scripts/build.sh`
- `scripts/kernel_verify.sh`
- `Makefile`
- `build/linux/dev/`
- `build/kernel/`

## References

- Device Tree Specification: https://www.devicetree.org/specifications/
