---
title: Scripts
last_updated: 2026-04-20
category: scripts
---

# Scripts

Build, deployment, and SD card flashing automation scripts for BeagleBone BSP.

## Overview

The `scripts/` directory contains shell scripts that automate the entire BSP workflow:

- **Build**: Compile kernel, U-Boot, and drivers
- **Deploy**: Push artifacts to board over network
- **Flash**: Write bootable SD card image

## Workflow

| #   | Topic               | File                              |
| --- | ------------------- | --------------------------------- |
| 01  | build.sh Overview   | [[01-build-sh-overview.md]]       |
| 02  | Docker Auto-Wrapper | [[02-build-sh-docker-wrapper.md]] |
| 03  | Build Functions     | [[03-build-sh-functions.md]]      |
| 04  | deploy.sh           | [[04-deploy-sh.md]]               |
| 05  | flash_sd.sh         | [[05-flash-sd-sh.md]]             |

## Quick Reference

### Build Commands

```bash
# Build everything
bash scripts/build.sh all

# Fast development kernel build
bash scripts/build.sh kernel dev

# Reproducible kernel build
bash scripts/build.sh kernel reproducible

# Build U-Boot only
bash scripts/build.sh uboot

# Build specific driver
bash scripts/build.sh driver led-gpio
```

### Deploy Commands

```bash
# Deploy kernel + dtb via TFTP
bash scripts/deploy.sh

# Dry-run (test without deploying)
bash scripts/deploy.sh --dry-run

# Override TFTP server
TFTP_SERVER=10.0.0.5 bash scripts/deploy.sh
```

### Flash SD Card

```bash
# Flash SD card (requires root)
sudo bash scripts/flash_sd.sh /dev/sdb
```

## Key Features

### Auto Docker Wrapper

Scripts automatically detect if running inside Docker:

- If **outside Docker** → re-exec inside container
- If **inside Docker** → continue build

**User only needs:**

```bash
bash scripts/build.sh kernel
```

**Script handles Docker automatically!**

### Strict Error Handling

All scripts use `set -euo pipefail`:

- Exit on any error
- Catch undefined variables
- Detect pipeline failures

### Absolute Path Resolution

Scripts work from any directory:

```bash
cd /tmp
bash /path/to/beaglebone-bsp/scripts/build.sh kernel
# Works correctly!
```

## Script Locations

```
beaglebone-bsp/
└── scripts/
    ├── build.sh       # Main build orchestration
    ├── deploy.sh      # Network deployment
    └── flash_sd.sh    # SD card flashing
```

## References

- Google Shell Style Guide: https://google.github.io/styleguide/shellguide.html
- Bash Strict Mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
- ShellCheck: https://www.shellcheck.net/
