---
title: Docker
last_updated: 2026-04-18
category: docker
---

# Docker

Docker container setup for reproducible BeagleBone Black BSP builds.

## Workflow

| #   | Topic                     | File                                    |
| --- | ------------------------- | --------------------------------------- |
| 00  | Overview                  | [[00-docker-overview.md]]               |
| 01  | Installation              | [[01-docker-install.md]]                |
| 02  | Build BSP Image           | [[02-docker-build-image.md]]            |
| 03  | Run Commands              | [[03-docker-run-commands.md]]           |
| 04  | Verify Artifacts          | [[04-docker-verify.md]]                 |
| 05  | Troubleshooting           | [[05-docker-troubleshooting.md]]        |
| 06  | Dockerfile Packages       | [[06-dockerfile-packages-explained.md]] |
| 07  | Host Toolchain (Optional) | [[07-host-toolchain-optional.md]]       |

## Quick Reference

```bash
# Build BSP Docker image
make docker

# Or manually
sudo docker build -t beaglebone-bsp-builder:1.0 docker/

# Verify toolchain inside container
docker run --rm beaglebone-bsp-builder:1.0 arm-linux-gnueabihf-gcc --version
```
