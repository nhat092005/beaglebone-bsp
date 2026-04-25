---
title: Clone Kernel at v5.10.253
tags:
  - linux
  - git
  - clone
date: 2026-04-19
category: kernel
---

# Clone Kernel at v5.10.253

## Why Shallow Clone?

The full stable history is ~1.5 GB. A depth-1 fetch produces ~500 MB working tree, sufficient for building.

## Step 1: Initialize and Fetch

The `linux/` directory contains project files (`configs/`, `dts/`, `patches/`), so use `git init` + `git fetch`:

```bash
cd "$BSP_ROOT/linux"

git init
git fetch --depth=1 \
    https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
    refs/tags/v5.10.253:refs/tags/v5.10.253

git checkout FETCH_HEAD
```

## Step 2: Verify

```bash
# Tag should match
git describe --tags HEAD
# expect: v5.10.253

# SHA should match VERSION-PIN
git log -1 --format=%H
# expect: 49e5d20074c20b20773c6dc0f8dce0635591093b
```

## Save Version Pin

```bash
echo "v5.10.253" > VERSION-PIN
echo "49e5d20074c20b20773c6dc0f8dce0635591093b" >> VERSION-PIN
```

## Deepen if Needed

If you need a commit not in shallow history:

```bash
git fetch --deepen=5000
```

## References

- Linux releases: https://kernel.org/category/releases.html
