---
title: Clone Kernel (First Time)
tags:
  - linux
  - git
  - clone
last_updated: 2026-04-26
category: kernel
---

# Clone Kernel (First Time)

This guide is for a beginner starting from zero and setting up the kernel tree used by this project.

Assumption: you already cloned this BSP repository first:

```bash
git clone https://github.com/nhat092005/beaglebone-bsp.git beaglebone-bsp
cd beaglebone-bsp
```

Project target for Phase 3 is pinned to:

- tag: `v5.10.253`
- sha: `49e5d20074c20b20773c6dc0f8dce0635591093b`
- source: `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git`

## Prerequisite

Set project root once:

```bash
export BSP_ROOT="${HOME}/Working_Space/my-project/beaglebone-bsp"
```

Verify:

```bash
ls -la "${BSP_ROOT}"
```

## Prepare `linux/` directory

This repository keeps project-owned files inside `linux/` (`configs/`, `dts/`, `patches/`, `VERSION-PIN`).
So do not clone into a different folder name. Initialize/fetch directly in `linux/`.

Important: do not delete `linux/configs/`, `linux/dts/`, or `linux/patches/` because they are project-owned custom files.

```bash
mkdir -p "${BSP_ROOT}/linux"
cd "${BSP_ROOT}/linux"
git init
```

## Fetch pinned kernel tag

```bash
cd "${BSP_ROOT}/linux"
git fetch --depth=1 \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
  refs/tags/v5.10.253:refs/tags/v5.10.253
git checkout --detach refs/tags/v5.10.253
```

Why `--depth=1`: faster and smaller download, enough for build/verification.

## Verify exact version

```bash
cd "${BSP_ROOT}/linux"
git describe --tags HEAD
git rev-parse HEAD
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL) =' Makefile
```

Expected:

- `git describe --tags HEAD` -> `v5.10.253`
- `git rev-parse HEAD` -> `49e5d20074c20b20773c6dc0f8dce0635591093b`
- `Makefile` lines include:
  - `VERSION = 5`
  - `PATCHLEVEL = 10`
  - `SUBLEVEL = 253`

## Write version pin file

```bash
printf 'LINUX_TAG=v5.10.253\n' > "${BSP_ROOT}/linux/VERSION-PIN"
cat "${BSP_ROOT}/linux/VERSION-PIN"
```

Expected:

```text
LINUX_TAG=v5.10.253
```

## If you already cloned before

If `linux/` already exists, do not reclone immediately. First verify current state:

```bash
cd "${BSP_ROOT}/linux"
git describe --tags HEAD
git rev-parse HEAD
```

If both already match the pinned values above, no action is needed.

## Troubleshooting

- `fatal: not a git repository`: run `git init` inside `${BSP_ROOT}/linux` first.
- `pathspec ... did not match`: use exact ref `refs/tags/v5.10.253`.
- network timeout: retry fetch; if needed, run without `--depth=1`.

## References

- Linux stable releases: https://kernel.org/category/releases.html
