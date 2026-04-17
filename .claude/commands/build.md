---
description: Detect the BSP build target from context and run the appropriate build command (kernel, U-Boot, Yocto, or out-of-tree driver). Invokes build-resolver agent on failure.
argument-hint: [kernel | uboot | yocto | driver <name> | app <name>]
---

# Build

Detect and run the correct BSP build command based on the argument or changed files.

**Input**: $ARGUMENTS

## Phase 1 -- Detect Target

If $ARGUMENTS specifies a target (kernel, uboot, yocto, driver, app), use it directly.

Otherwise, detect from recently changed files:

```bash
git diff --name-only HEAD -- | head -20
```

| Changed Path               | Build Target |
| -------------------------- | ------------ |
| `linux/` or `drivers/`     | kernel       |
| `u-boot/`                  | uboot        |
| `meta-bbb/` or `freertos/` | yocto        |
| `apps/`                    | app          |

If the target cannot be determined, ask the user: "Which target do you want to build: kernel, uboot, yocto, driver, or app?"

---

## Kernel Build

```bash
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules 2>&1
```

Success indicator: line containing `Kernel: arch/arm/boot/zImage is ready`

---

## U-Boot Build

```bash
cd u-boot
make CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) 2>&1
```

Success indicator: `u-boot.img` exists and size is greater than zero.

---

## Yocto Build

First check that the Yocto environment is sourced:

```bash
if [ -z "$BUILDDIR" ]; then
  echo "ERROR: Yocto environment not sourced."
  echo "Run: source poky/oe-init-build-env build"
  exit 1
fi
```

Ask the user to confirm before running BitBake (builds can take over an hour):

```
About to run: bitbake core-image-minimal
This may take a long time. Continue? [yes/no]
```

If confirmed:

```bash
bitbake core-image-minimal 2>&1 | tail -80
```

Success indicator: `Build successful` in the last 10 lines of output.

---

## Out-of-Tree Driver Build

```bash
make ARCH=arm \
     CROSS_COMPILE=arm-linux-gnueabihf- \
     KERNEL_DIR=$(pwd)/linux \
     -C drivers/<NAME> 2>&1
```

Success indicator: exit code 0 and `<name>.ko` file exists.

---

## Out-of-Tree App Build

```bash
make CROSS_COMPILE=arm-linux-gnueabihf- -C apps/<NAME> 2>&1
```

---

## Phase 2 -- Handle Build Failure

If the build fails:

1. Parse the first error message (file, line, description)
2. If it is a simple fix (missing include, typo, wrong path): apply minimal fix and rebuild once
3. If the error persists or is complex: invoke `build-resolver` agent and stop

Stop conditions for the fix loop:

- Same error appears after 2 fix attempts
- Fix would require architectural changes
- Error is in upstream kernel or U-Boot source (report to user, suggest workaround)

## Phase 3 -- Report

```
Build Report
Target:  kernel
Command: make ARCH=arm ...

Result: SUCCESS
Artifact: linux/arch/arm/boot/zImage (3.1 MB)

-- or --

Result: FAILED
Error: drivers/foo/foo.c:42: undeclared identifier 'bar'
Action: Invoked build-resolver agent
```

## Stop Conditions

- Do not run Yocto without user confirmation
- Do not run `/build all` if disk space is under 60 GB (Yocto requires significant disk)
- Do not modify kernel Makefile or defconfig unless directly fixing the reported error

## Success Criteria

- Exit code is 0
- Build artifact exists: `zImage`, `u-boot.img`, `*.ko`, or Yocto `Build successful`

## Related

- Agent: `agents/build-resolver.md`
- Command: `/check` -- run static analysis before building
