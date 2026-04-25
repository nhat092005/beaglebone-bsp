---
title: Build BSP Docker Image
tags:
  - docker
  - build
  - image
date: 2026-04-18
category: docker
---

# Build BSP Docker Image

## Dockerfile Location

`${BSP_ROOT}/docker/Dockerfile`

## Build Command

```bash
cd "${BSP_ROOT}"
sudo docker build -t beaglebone-bsp-builder:1.0 docker/
```

## Build Output Example

```
[+] Building 1.2s (2/2) FINISHED
 => [internal] load build definition from Dockerfile
 => [internal] load metadata for docker.io/library/ubuntu@sha256:...
 => CACHED docker-image://sha256:...
 => => naming to docker.io/library/beaglebone-bsp-builder:1.0
```

## Verify Image

### Check image exists

```bash
docker images beaglebone-bsp-builder:1.0
```

### Verify cross-compiler version

```bash
docker run --rm beaglebone-bsp-builder:1.0 arm-linux-gnueabihf-gcc --version
# expect: arm-linux-gnueabihf-gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0
```

### Check image size

```bash
docker images beaglebone-bsp-builder:1.0 --format "{{.Size}}"
# expect: ~1.04 GB (must be < 2.5 GiB)
```

### Verify image digest is pinned

```bash
grep -E '^FROM ubuntu@sha256:[0-9a-f]{64}' docker/Dockerfile
# expect: one line matching pattern
```

## How to Get Base Image SHA256 Digest

### Why use SHA256 digest instead of tags?

Docker tags like `ubuntu:22.04` are **mutable** (can change over time):

```
Day 1: ubuntu:22.04 → SHA256:abc123 (gcc 11.2)
Day 180: ubuntu:22.04 → SHA256:def456 (gcc 11.4) ← Ubuntu updated!
```

Using SHA256 digest ensures **reproducible builds** - everyone gets the exact same base image.

### Steps to get SHA256 digest

#### 1. Pull the latest image

```bash
docker pull ubuntu:22.04
```

#### 2. Extract the digest

```bash
docker inspect ubuntu:22.04 --format='{{index .RepoDigests 0}}'
```

**Output example:**

```
ubuntu@sha256:962f6cadeae0ea6284001009daa4cc9a8c37e75d1f5191cf0eb83fe565b63dd7
```

#### 3. Update Dockerfile

Replace the `FROM` line in `docker/Dockerfile`:

```dockerfile
# Before (mutable tag):
FROM ubuntu:22.04

# After (immutable digest):
FROM ubuntu@sha256:962f6cadeae0ea6284001009daa4cc9a8c37e75d1f5191cf0eb83fe565b63dd7
```

#### 4. Add comment with date

Document when the digest was pinned:

```dockerfile
# ubuntu:22.04 digest pinned 2026-04-20 — update with: docker pull ubuntu:22.04 && docker inspect ubuntu:22.04 --format='{{index .RepoDigests 0}}'
FROM ubuntu@sha256:962f6cadeae0ea6284001009daa4cc9a8c37e75d1f5191cf0eb83fe565b63dd7
```

### When to update the digest

- **Security updates**: When Ubuntu releases critical security patches
- **Toolchain updates**: When you need a newer gcc version
- **Quarterly review**: Check for updates every 3 months

### Verify digest hasn't changed

```bash
# Check current digest in Dockerfile
grep '^FROM ubuntu@sha256:' docker/Dockerfile

# Compare with latest available
docker pull ubuntu:22.04
docker inspect ubuntu:22.04 --format='{{index .RepoDigests 0}}'
```

If they differ, decide whether to update based on changelog.
