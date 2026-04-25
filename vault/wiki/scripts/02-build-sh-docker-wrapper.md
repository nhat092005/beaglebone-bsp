---
title: build.sh Docker Auto-Wrapper
tags:
  - scripts
  - docker
  - bash
  - automation
date: 2026-04-20
category: scripts
---

# build.sh Docker Auto-Wrapper

This document explains the **most clever part** of `build.sh`: the automatic Docker wrapper that makes the script work seamlessly both inside and outside Docker.

## The Problem

**Without auto-wrapper, users need to remember two different commands:**

```bash
# On host (if toolchain installed):
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage

# In Docker (if no host toolchain):
docker run --rm -v $(pwd):/workspace beaglebone-bsp-builder:1.0 \
  bash scripts/build.sh kernel
```

**Problems:**

- Complex Docker command (hard to remember)
- User must know if they're in Docker or not
- Easy to make mistakes (wrong volume mount, wrong workdir)
- Different commands for different environments

---

## The Solution: Auto-Wrapper

**With auto-wrapper, user only needs:**

```bash
bash scripts/build.sh kernel
```

**Script automatically:**

1. Detects if running inside Docker
2. If **not** in Docker → re-exec inside Docker
3. If **already** in Docker → continue build

**User doesn't need to think about Docker at all!**

---

## How It Works

### Step 1: Bash Strict Mode

```bash
#!/usr/bin/env bash
set -euo pipefail
```

#### Shebang: `#!/usr/bin/env bash`

**Why not `#!/bin/bash`?**

```
Linux:   bash is at /bin/bash
macOS:   bash is at /usr/local/bin/bash
FreeBSD: bash is at /usr/pkg/bin/bash
```

**Solution:** `#!/usr/bin/env bash` searches PATH for bash (portable)

---

#### `set -euo pipefail` (Bash Strict Mode)

**This is critical for production scripts!**

##### `set -e` (exit on error)

**Without `-e`:**

```bash
#!/bin/bash
rm important_file.txt    # Error: file not found
echo "Continuing..."     # Still runs!
rm -rf /                 # Disaster!
```

**With `-e`:**

```bash
#!/bin/bash
set -e
rm important_file.txt    # Error: file not found
echo "Never reached"     # Script stops immediately!
```

---

##### `set -u` (error on undefined variable)

**Without `-u`:**

```bash
#!/bin/bash
echo "Deleting $DIRECTRY"  # Typo: should be DIRECTORY
rm -rf /$DIRECTRY          # $DIRECTRY is empty → rm -rf / !!!
```

**With `-u`:**

```bash
#!/bin/bash
set -u
echo "Deleting $DIRECTRY"  # Error: DIRECTRY: unbound variable
# Script stops, disaster avoided!
```

---

##### `set -o pipefail` (pipeline error detection)

**Without `pipefail`:**

```bash
#!/bin/bash
cat non_existent_file.txt | grep "pattern"
echo $?  # Output: 0 (success!)
# Why? Because grep exited with 0 (no match found)
# Pipeline only checks last command's exit code
```

**With `pipefail`:**

```bash
#!/bin/bash
set -o pipefail
cat non_existent_file.txt | grep "pattern"
echo $?  # Output: 1 (failure!)
# Pipeline fails if ANY command fails
```

**Real-world example:**

```bash
# Build kernel and filter output
make zImage 2>&1 | tee build.log

# Without pipefail:
# If make fails, script continues (because tee succeeded)

# With pipefail:
# If make fails, script stops immediately
```

---

### Step 2: Path Resolution

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
DOCKER_IMAGE="${DOCKER_IMAGE:-beaglebone-bsp-builder:1.0}"
```

#### `SCRIPT_DIR` - Find Script's Directory

**Problem:**

```bash
# User can run script from anywhere:
cd /tmp
bash /home/nhat/Working_Space/my-project/beaglebone-bsp/scripts/build.sh kernel

# Inside script, if we use relative paths:
cd ../linux  # Wrong! Goes to /tmp/../linux (doesn't exist)
```

**Solution: Calculate absolute path**

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**Step-by-step breakdown:**

```bash
# 1. ${BASH_SOURCE[0]} = full path to script
${BASH_SOURCE[0]}
# → /home/nhat/Working_Space/my-project/beaglebone-bsp/scripts/build.sh

# 2. dirname = get directory part
dirname "${BASH_SOURCE[0]}"
# → /home/nhat/Working_Space/my-project/beaglebone-bsp/scripts

# 3. cd to that directory and print absolute path
cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
# → /home/nhat/Working_Space/my-project/beaglebone-bsp/scripts

# 4. Capture in variable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**Now we can use absolute paths:**

```bash
cd "${SCRIPT_DIR}/../linux"  # Always correct!
```

---

#### `${BASH_SOURCE[0]}` vs `$0`

**Key difference:**

| Scenario                           | `$0`               | `${BASH_SOURCE[0]}` |
| ---------------------------------- | ------------------ | ------------------- |
| Direct run: `bash build.sh`        | `build.sh`         | `build.sh`          |
| With path: `bash scripts/build.sh` | `scripts/build.sh` | `scripts/build.sh`  |
| **Source: `source build.sh`**      | `bash`             | `build.sh`          |

**Example:**

```bash
# test.sh
echo "\$0 = $0"
echo "\${BASH_SOURCE[0]} = ${BASH_SOURCE[0]}"

# Run directly:
bash test.sh
# $0 = test.sh
# ${BASH_SOURCE[0]} = test.sh

# Source (load into current shell):
source test.sh
# $0 = bash  ← Wrong! Not the script name
# ${BASH_SOURCE[0]} = test.sh  ← Correct!
```

**Conclusion:** Always use `${BASH_SOURCE[0]}` for path resolution.

---

#### `REPO_ROOT` - Find Repository Root

```bash
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
```

**Logic:**

```
SCRIPT_DIR = /home/nhat/Working_Space/my-project/beaglebone-bsp/scripts
SCRIPT_DIR/.. = /home/nhat/Working_Space/my-project/beaglebone-bsp
REPO_ROOT = /home/nhat/Working_Space/my-project/beaglebone-bsp
```

**Now we can reference any file in repo:**

```bash
KERNEL_DIR="${REPO_ROOT}/linux"
UBOOT_DIR="${REPO_ROOT}/u-boot"
BUILD_DIR="${REPO_ROOT}/build"
```

---

#### `DOCKER_IMAGE` - Default with Override

```bash
DOCKER_IMAGE="${DOCKER_IMAGE:-beaglebone-bsp-builder:1.0}"
```

**Bash parameter expansion:**

```bash
${VAR:-default}
# If VAR is set → use VAR
# If VAR is unset → use "default"
```

**Examples:**

```bash
# Use default:
bash scripts/build.sh kernel
# DOCKER_IMAGE = beaglebone-bsp-builder:1.0

# Override:
DOCKER_IMAGE=my-custom:2.0 bash scripts/build.sh kernel
# DOCKER_IMAGE = my-custom:2.0
```

---

### Step 3: Docker Detection & Re-exec

**This is the magic!**

```bash
# If not inside a container, re-exec inside one.
if [[ ! -f /.dockerenv ]]; then
    exec docker run --rm \
        -v "${REPO_ROOT}:/workspace" \
        -w /workspace \
        "${DOCKER_IMAGE}" \
        bash scripts/build.sh "$@"
fi
```

#### How Docker Detection Works

**Docker creates a special file in every container:**

```bash
# On host:
ls -la /.dockerenv
# ls: cannot access '/.dockerenv': No such file or directory

# Inside Docker:
docker run --rm ubuntu ls -la /.dockerenv
# -rwxr-xr-x 1 root root 0 Apr 20 10:00 /.dockerenv
```

**Script checks this file:**

```bash
if [[ ! -f /.dockerenv ]]; then
    # File doesn't exist → we're on host → need to run in Docker
fi
```

---

#### `exec` vs Normal Command

**Without `exec` (creates subprocess):**

```bash
docker run ... bash scripts/build.sh kernel
# Process tree:
# bash (PID 1234) - original script
#   └─ docker (PID 1235)
#       └─ bash (PID 1236) - script inside container
```

**With `exec` (replaces current process):**

```bash
exec docker run ... bash scripts/build.sh kernel
# Process tree:
# docker (PID 1234) - replaces original bash
#   └─ bash (PID 1235) - script inside container
```

**Benefits of `exec`:**

- Cleaner process tree
- Signals (Ctrl+C) propagate correctly
- Exit code returned directly to user

---

#### Docker Run Arguments

```bash
exec docker run --rm \
    -v "${REPO_ROOT}:/workspace" \
    -w /workspace \
    "${DOCKER_IMAGE}" \
    bash scripts/build.sh "$@"
```

**Breakdown:**

##### `--rm`

**Remove container after exit**

```bash
# Without --rm:
docker run ubuntu echo "hello"
docker ps -a  # Container still exists (stopped)

# With --rm:
docker run --rm ubuntu echo "hello"
docker ps -a  # Container automatically deleted
```

**Why:** Avoid accumulating stopped containers.

---

##### `-v "${REPO_ROOT}:/workspace"`

**Mount host directory into container**

```bash
# Host:
/home/nhat/Working_Space/my-project/beaglebone-bsp/

# Container:
/workspace/

# They point to the same files!
```

**Example:**

```bash
# Inside container:
echo "test" > /workspace/test.txt

# On host:
cat /home/nhat/Working_Space/my-project/beaglebone-bsp/test.txt
# Output: test
```

**Why:** Build artifacts created in container appear on host.

---

##### `-w /workspace`

**Set working directory**

```bash
# Without -w:
docker run ubuntu pwd
# Output: /

# With -w /workspace:
docker run -w /workspace ubuntu pwd
# Output: /workspace
```

**Why:** Script starts in correct directory.

---

##### `"$@"` - Forward All Arguments

**Preserves all arguments exactly:**

```bash
# User runs:
bash scripts/build.sh driver led-gpio

# Inside script:
# $1 = "driver"
# $2 = "led-gpio"
# "$@" = "driver" "led-gpio"

# Re-exec with "$@":
exec docker run ... bash scripts/build.sh "$@"
# Becomes:
exec docker run ... bash scripts/build.sh driver led-gpio
```

**Why quotes matter:**

```bash
# Without quotes:
"$@"  → "driver" "led-gpio" (2 arguments)
$@    → driver led-gpio (2 arguments, but breaks with spaces)

# Example with spaces:
bash scripts/build.sh "my driver"

"$@"  → "my driver" (1 argument)
$@    → my driver (2 arguments)
```

---

### Step 4: Inside Container

```bash
# --- Inside container from here ---
REPO_ROOT=/workspace
BUILD_DIR="${REPO_ROOT}/build"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
ARCH="${ARCH:-arm}"
KERNEL_DIR="${REPO_ROOT}/linux"
UBOOT_DIR="${REPO_ROOT}/u-boot"
```

**When script runs inside Docker:**

- `/.dockerenv` exists → skip re-exec
- Continue with build
- Use `/workspace` as repo root (mounted from host)

---

## Complete Flow Diagram

```
User runs: bash scripts/build.sh kernel
    ↓
Script starts on host
    ↓
Check: Does /.dockerenv exist?
    ↓
NO (we're on host)
    ↓
exec docker run --rm \
  -v /home/nhat/.../beaglebone-bsp:/workspace \
  -w /workspace \
  beaglebone-bsp-builder:1.0 \
  bash scripts/build.sh kernel
    ↓
Docker starts container
    ↓
Script runs AGAIN inside container
    ↓
Check: Does /.dockerenv exist?
    ↓
YES (we're in Docker)
    ↓
Skip re-exec, continue to build
    ↓
build_kernel() function runs
    ↓
Artifacts written to /workspace/build/
    ↓
Container exits
    ↓
Artifacts visible on host at beaglebone-bsp/build/
    ↓
Done!
```

---

## Real-World Example

### Scenario 1: User on Host (No Docker Running)

```bash
$ pwd
/home/nhat/Working_Space/my-project/beaglebone-bsp

$ bash scripts/build.sh kernel
# Script detects: not in Docker
# Script runs: docker run ... bash scripts/build.sh kernel
# Docker starts container
# Script runs again inside container
# Build happens
# Artifacts appear in build/kernel/
```

---

### Scenario 2: User Already in Docker

```bash
$ docker run -it --rm -v $(pwd):/workspace beaglebone-bsp-builder:1.0 bash
builder@container:/workspace$ bash scripts/build.sh kernel
# Script detects: already in Docker (/.dockerenv exists)
# Script continues directly to build
# No re-exec needed
```

---

### Scenario 3: User with Host Toolchain

```bash
$ cd linux
$ make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
# Builds directly on host (faster)
# No Docker involved
```

---

## Benefits of This Design

### 1. Transparent to User

**User doesn't need to know:**

- If Docker is being used
- How to run Docker commands
- Volume mount syntax
- Working directory setup

**User only needs:**

```bash
bash scripts/build.sh kernel
```

---

### 2. Works Everywhere

**Same command works:**

- On host (auto-wraps in Docker)
- Inside Docker (detects and continues)
- In CI/CD (no special handling)
- On any machine (as long as Docker installed)

---

### 3. Fail-Safe

**If Docker not installed:**

```bash
bash scripts/build.sh kernel
# bash: docker: command not found
# Clear error message
```

**User can then:**

- Install Docker, or
- Use host toolchain directly

---

### 4. Easy to Debug

**Enable tracing:**

```bash
bash -x scripts/build.sh kernel
```

**Output shows exactly what happens:**

```
+ [[ ! -f /.dockerenv ]]
+ exec docker run --rm -v /home/nhat/.../beaglebone-bsp:/workspace -w /workspace beaglebone-bsp-builder:1.0 bash scripts/build.sh kernel
```

---

## Advanced: Nested Docker Detection

**What if user runs Docker inside Docker?**

```bash
# Host
docker run -it ubuntu bash
  # Container 1
  docker run -it ubuntu bash
    # Container 2
    ls /.dockerenv  # Exists!
```

**Script handles this correctly:**

- Checks `/.dockerenv` in current environment
- If exists → assumes we're in build container
- If not → wraps in Docker

**Edge case:** User manually enters wrong container:

```bash
docker run -it --rm ubuntu bash
bash scripts/build.sh kernel
# /.dockerenv exists, but no toolchain installed
# Build will fail with clear error
```

---

## Testing the Auto-Wrapper

### Test 1: On Host

```bash
# Remove /.dockerenv if it exists (shouldn't on host)
ls /.dockerenv
# ls: cannot access '/.dockerenv': No such file or directory

# Run script
bash -x scripts/build.sh kernel 2>&1 | head -20
# Should see: exec docker run ...
```

---

### Test 2: Inside Docker

```bash
# Enter container
docker run -it --rm -v $(pwd):/workspace beaglebone-bsp-builder:1.0 bash

# Check /.dockerenv exists
ls -la /.dockerenv
# -rwxr-xr-x 1 root root 0 Apr 20 10:00 /.dockerenv

# Run script
bash -x scripts/build.sh kernel 2>&1 | head -20
# Should NOT see: exec docker run ...
# Should see: build_kernel function running
```

---

### Test 3: Override Docker Image

```bash
DOCKER_IMAGE=ubuntu:22.04 bash scripts/build.sh kernel
# Should fail (ubuntu:22.04 doesn't have toolchain)
# But proves override works
```

---

## Common Issues

### Issue: "docker: command not found"

**Cause:** Docker not installed

**Solution:**

```bash
# Install Docker
sudo apt install docker.io

# Or use host toolchain
cd linux
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
```

---

### Issue: "permission denied while trying to connect to Docker daemon"

**Cause:** User not in `docker` group

**Solution:**

```bash
sudo usermod -aG docker $USER
newgrp docker  # Or logout/login
```

---

### Issue: Script runs in Docker but toolchain missing

**Cause:** Wrong Docker image

**Check:**

```bash
docker run --rm beaglebone-bsp-builder:1.0 arm-linux-gnueabihf-gcc --version
# Should print gcc version
```

**If fails:**

```bash
# Rebuild Docker image
make docker
```

---

## Summary

**The auto-wrapper pattern:**

1.  **Detects environment** (host vs Docker)
2.  **Re-execs in Docker** if needed
3.  **Transparent to user** (one command works everywhere)
4.  **Preserves arguments** (`"$@"`)
5.  **Handles errors** (strict mode)
6.  **Portable** (works from any directory)

**Key techniques:**

- `set -euo pipefail` (strict mode)
- `${BASH_SOURCE[0]}` (path resolution)
- `/.dockerenv` (Docker detection)
- `exec` (process replacement)
- `"$@"` (argument forwarding)

---

## References

- Bash Strict Mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
- Google Shell Style Guide: https://google.github.io/styleguide/shellguide.html
- Docker Run Reference: https://docs.docker.com/engine/reference/run/
- Bash Parameter Expansion: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
