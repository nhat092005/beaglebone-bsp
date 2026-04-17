---
description: Build repo targets using Makefile entrypoints and report generated artifacts.
argument-hint: [kernel | uboot | all | driver <name> | docker | bitbake <target>]
---

Build through repository entrypoints only.

1. Resolve target from `$ARGUMENTS`.
2. If no argument, infer from changed files:
   - `linux/` or `drivers/` -> `kernel`
   - `u-boot/` -> `uboot`
   - `meta-bbb/` -> `bitbake core-image-minimal`
   - fallback -> `all`
3. Run one command:
   - `kernel` -> `make kernel`
   - `uboot` -> `make uboot`
   - `all` -> `make all`
   - `docker` -> `make docker`
   - `driver <name>` -> `make driver DRIVER=<name>`
   - `bitbake <target>` -> `make bitbake BB=<target>`

After build, report artifact presence from `build/`:

- kernel: `build/zImage`, `build/am335x-boneblack.dtb`
- u-boot: `build/MLO`, `build/u-boot.img`
- driver: `build/*.ko`

If build fails, capture first actionable error and invoke `build-resolver`.

Do not switch to ad-hoc build commands unless diagnosing an error.
