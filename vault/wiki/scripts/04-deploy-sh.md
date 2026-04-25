---
title: deploy.sh - Network Deployment
tags:
  - scripts
  - deploy
  - tftp
  - network
date: 2026-04-20
category: scripts
---

# deploy.sh - Network Deployment

`scripts/deploy.sh` deploys kernel and device tree from PC to BeagleBone Black over **USB network** using **TFTP protocol**.

## Purpose

**Fast development workflow:**

```
Edit code → Build → Deploy → Boot → Test
         ↓         ↓        ↓
    build.sh  deploy.sh  U-Boot TFTP boot
```

**Without deploy.sh (slow):**

```bash
# 1. Build
bash scripts/build.sh kernel

# 2. Copy to SD card
sudo mount /dev/sdb1 /mnt
sudo cp build/kernel/zImage /mnt/
sudo cp build/kernel/am335x-boneblack.dtb /mnt/
sudo umount /mnt

# 3. Eject SD, insert to BBB, power on
# 4. Wait for boot
# 5. Test

# Total: ~5 minutes per iteration
```

**With deploy.sh (fast):**

```bash
# 1. Build
bash scripts/build.sh kernel

# 2. Deploy
bash scripts/deploy.sh

# 3. U-Boot boots from TFTP (no SD write!)
# 4. Test

# Total: ~30 seconds per iteration
```

---

## Why TFTP Instead of SCP?

### Comparison

| Feature                 | TFTP                       | SCP                   |
| ----------------------- | -------------------------- | --------------------- |
| **Protocol complexity** | Very simple                | Complex (SSH)         |
| **Authentication**      | None                       | Username/password     |
| **U-Boot support**      | Built-in                   | No SSH client         |
| **Speed**               | Fast                       | Fast                  |
| **Security**            | None (local network only)  | Encrypted             |
| **Use case**            | Embedded boot, development | General file transfer |

### Key Reason: U-Boot Support

**U-Boot (bootloader) has:**

- TFTP client built-in
- No SSH client

**This means:**

```
U-Boot can:
   tftp 0x82000000 zImage        (download via TFTP)
   scp root@192.168.7.1:zImage   (no SCP support!)

Linux (after boot) can:
   Both TFTP and SCP
```

### Development Workflow

**TFTP workflow (recommended for development):**

```
1. Build kernel on PC
2. Deploy to TFTP server (deploy.sh)
3. U-Boot downloads kernel to RAM via TFTP
4. U-Boot boots kernel from RAM (no SD write!)
5. Test
6. Repeat (fast iteration!)
```

**SCP workflow (traditional):**

```
1. Build kernel on PC
2. SCP to board: scp zImage root@192.168.7.2:/boot/
3. SSH to board: ssh root@192.168.7.2
4. Reboot board
5. Test
6. Repeat (slower)
```

**TFTP is 3-5x faster for development!**

---

## USB Gadget Network

### Physical Connection

```
PC (USB Host)  ←──USB cable──→  BeagleBone (USB Device)
```

### Virtual Network Interface

When you plug USB cable into BeagleBone:

- PC sees BeagleBone as a **network card** (USB Ethernet Gadget)
- No Ethernet cable needed!
- Automatic network configuration

### IP Addresses

```
PC (Host):         192.168.7.1/24
BeagleBone (Device): 192.168.7.2/24

Subnet: 192.168.7.0/24
```

### Verify Connection

**On PC:**

```bash
# Check USB network interface
ip addr show | grep "192.168.7"
# inet 192.168.7.1/24 brd 192.168.7.255 scope global usb0

# Ping BeagleBone
ping 192.168.7.2
# 64 bytes from 192.168.7.2: icmp_seq=1 ttl=64 time=0.5 ms
```

**On BeagleBone (via serial console):**

```bash
# Check IP address
ip addr show usb0
# inet 192.168.7.2/24 brd 192.168.7.255 scope global usb0

# Ping PC
ping 192.168.7.1
# 64 bytes from 192.168.7.1: icmp_seq=1 ttl=64 time=0.5 ms
```

---

## TFTP Protocol

### What is TFTP?

**TFTP = Trivial File Transfer Protocol**

- RFC 1350 (1992)
- Very simple (no authentication, no encryption)
- Designed for embedded systems and network boot
- Uses UDP port 69

### TFTP vs FTP

| Feature            | TFTP             | FTP                        |
| ------------------ | ---------------- | -------------------------- |
| **Complexity**     | Trivial (simple) | Complex                    |
| **Authentication** | None             | Username/password          |
| **Commands**       | Read, Write only | Many (ls, cd, mkdir, etc.) |
| **Protocol**       | UDP              | TCP                        |
| **Use case**       | Boot, embedded   | General file transfer      |

### TFTP Workflow

```
1. PC runs TFTP server (port 69)
2. BeagleBone (U-Boot) sends request: "Give me zImage"
3. TFTP server sends file in chunks (512 bytes each)
4. U-Boot receives file into RAM
5. U-Boot boots kernel from RAM
```

---

## Script Analysis

### Source Code

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
# TFTP_SERVER: host-side IP of USB gadget network (host=192.168.7.1, device=192.168.7.2)
TFTP_SERVER="${TFTP_SERVER:-192.168.7.1}"
DRY_RUN=0

usage() {
    echo "Usage: [TFTP_SERVER=<ip>] $0 [--dry-run]"
    echo ""
    echo "  --dry-run   Print tftp put commands without executing"
    echo ""
    echo "Pushes zImage, am335x-boneblack-custom.dtb, rootfs.tar.gz"
    echo "to TFTP_SERVER (default: 192.168.7.1)."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        *) usage ;;
    esac
done

tftp_put() {
    local local_file="$1"
    local remote_name="$2"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "tftp put ${local_file} ${remote_name}"
    else
        [[ -f "${local_file}" ]] || { echo "[deploy] ERROR: ${local_file} not found" >&2; exit 1; }
        tftp "${TFTP_SERVER}" -c put "${local_file}" "${remote_name}"
        echo "[deploy] sent ${remote_name}"
    fi
}

tftp_put "${BUILD_DIR}/kernel/zImage"                       "zImage"
tftp_put "${BUILD_DIR}/kernel/am335x-boneblack-custom.dtb" "am335x-boneblack-custom.dtb"
tftp_put "${BUILD_DIR}/rootfs.tar.gz"                       "rootfs.tar.gz"

if [[ "${DRY_RUN}" -eq 0 ]]; then
    echo "[deploy] done — server: ${TFTP_SERVER}"
fi
```

### Key Components

#### 1. Environment Variables

```bash
TFTP_SERVER="${TFTP_SERVER:-192.168.7.1}"
```

**Default value with override:**

```bash
# Use default:
bash scripts/deploy.sh
# TFTP_SERVER = 192.168.7.1

# Override:
TFTP_SERVER=10.0.0.5 bash scripts/deploy.sh
# TFTP_SERVER = 10.0.0.5
```

---

#### 2. Dry-Run Mode

```bash
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        *) usage ;;
    esac
done
```

**What is dry-run?**

Dry-run = **simulate** execution without actually doing it.

**Use cases:**

1. **Test script before running:**

```bash
bash scripts/deploy.sh --dry-run
# Output:
# tftp put /workspace/build/kernel/zImage zImage
# tftp put /workspace/build/kernel/am335x-boneblack-custom.dtb am335x-boneblack-custom.dtb
# tftp put /workspace/build/rootfs.tar.gz rootfs.tar.gz

# → See what script will do, no actual deployment
```

2. **Debug script:**

```bash
# If script fails, use dry-run to see commands
bash scripts/deploy.sh --dry-run
# Ah! File path is wrong: /workspace/build/kernel/zImage (doesn't exist)
```

3. **Verify before production:**

```bash
# Before deploying to real board:
TFTP_SERVER=192.168.7.1 bash scripts/deploy.sh --dry-run
# Check: correct server, correct files → OK, run for real
```

4. **Documentation:**

```bash
# Show commands without executing
bash scripts/deploy.sh --dry-run > deploy-commands.txt
# Send to teammate
```

**Dry-run pattern in other tools:**

```bash
git commit --dry-run          # See what will be committed
rsync --dry-run src/ dst/     # See what will be synced
apt-get install --dry-run pkg # See what will be installed
make -n                       # See what commands will run
```

---

#### 3. tftp_put Function

```bash
tftp_put() {
    local local_file="$1"
    local remote_name="$2"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "tftp put ${local_file} ${remote_name}"
    else
        [[ -f "${local_file}" ]] || { echo "[deploy] ERROR: ${local_file} not found" >&2; exit 1; }
        tftp "${TFTP_SERVER}" -c put "${local_file}" "${remote_name}"
        echo "[deploy] sent ${remote_name}"
    fi
}
```

**Function parameters:**

```bash
tftp_put "/path/to/zImage" "zImage"
# $1 = local_file = "/path/to/zImage"
# $2 = remote_name = "zImage"
```

**Logic:**

```
If dry-run mode:
    → Print command (no execution)
Else:
    → Check file exists
    → Upload via TFTP
    → Print success message
```

**Error checking:**

```bash
[[ -f "${local_file}" ]] || { echo "[deploy] ERROR: ${local_file} not found" >&2; exit 1; }
```

**Breakdown:**

```bash
[[ -f "${local_file}" ]]  # Check if file exists
||                         # OR (if false, run next)
{                          # Command group
    echo "[deploy] ERROR: ${local_file} not found" >&2  # Print to stderr
    exit 1                 # Exit with error code
}
```

**TFTP command:**

```bash
tftp "${TFTP_SERVER}" -c put "${local_file}" "${remote_name}"
```

**Expands to:**

```bash
tftp 192.168.7.1 -c put /workspace/build/kernel/zImage zImage
│    │           │  │   │                                │
│    │           │  │   └─ Local file path               └─ Remote filename
│    │           │  └─ TFTP command (put = upload)
│    │           └─ Command mode (non-interactive)
│    └─ TFTP server IP
└─ TFTP client command
```

**TFTP modes:**

```bash
# Interactive mode (default):
tftp 192.168.7.1
tftp> put zImage
tftp> quit

# Command mode (-c):
tftp 192.168.7.1 -c put zImage
# One-liner, no interaction needed
```

---

#### 4. Deploy Files

```bash
tftp_put "${BUILD_DIR}/kernel/zImage"                       "zImage"
tftp_put "${BUILD_DIR}/kernel/am335x-boneblack-custom.dtb" "am335x-boneblack-custom.dtb"
tftp_put "${BUILD_DIR}/rootfs.tar.gz"                       "rootfs.tar.gz"
```

**Three files deployed:**

1. **zImage** - Compressed kernel image (~4 MB)
2. **am335x-boneblack-custom.dtb** - Device tree blob (~45 KB)
3. **rootfs.tar.gz** - Root filesystem tarball (optional, ~50 MB)

---

## Complete Workflow

### Step 1: Setup TFTP Server on PC

**Install TFTP server:**

```bash
sudo apt update
sudo apt install tftpd-hpa
```

**Configure:**

```bash
sudo vim /etc/default/tftpd-hpa
```

**Content:**

```bash
# /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS="192.168.7.1:69"
TFTP_OPTIONS="--secure"
```

**Create TFTP directory:**

```bash
sudo mkdir -p /srv/tftp
sudo chown tftp:tftp /srv/tftp
sudo chmod 755 /srv/tftp
```

**Start TFTP server:**

```bash
sudo systemctl restart tftpd-hpa
sudo systemctl enable tftpd-hpa
```

**Verify:**

```bash
sudo systemctl status tftpd-hpa
# ● tftpd-hpa.service - LSB: HPA's tftp server
#    Loaded: loaded (/etc/init.d/tftpd-hpa; generated)
#    Active: active (running) since ...
```

---

### Step 2: Build Kernel

```bash
cd "${BSP_ROOT}"
bash scripts/build.sh kernel
```

**Output:**

```
[build] kernel
  ...
  Kernel: arch/arm/boot/zImage is ready
  DTC     arch/arm/boot/dts/am335x-boneblack.dtb
[build] kernel done → /workspace/build/kernel/
```

**Artifacts:**

```bash
ls -lh build/kernel/
# -rw-r--r-- 1 nhat nhat 4.2M Apr 20 12:00 zImage
# -rw-r--r-- 1 nhat nhat  45K Apr 20 12:00 am335x-boneblack-custom.dtb
```

---

### Step 3: Deploy to TFTP Server

```bash
bash scripts/deploy.sh
```

**Output:**

```
[deploy] sent zImage
[deploy] sent am335x-boneblack-custom.dtb
[deploy] sent rootfs.tar.gz
[deploy] done — server: 192.168.7.1
```

**Verify files on TFTP server:**

```bash
ls -lh /srv/tftp/
# -rw-r--r-- 1 tftp tftp 4.2M Apr 20 12:00 zImage
# -rw-r--r-- 1 tftp tftp  45K Apr 20 12:00 am335x-boneblack-custom.dtb
# -rw-r--r-- 1 tftp tftp  50M Apr 20 12:00 rootfs.tar.gz
```

---

### Step 4: Boot BeagleBone from TFTP

**Connect serial console:**

```bash
minicom -D /dev/ttyUSB0 -b 115200
```

**Power on BeagleBone → U-Boot prompt:**

```
U-Boot 2022.07 (Apr 20 2026 - 12:00:00 +0000)

Hit any key to stop autoboot:  0
U-Boot#
```

**Set network configuration:**

```
U-Boot# setenv serverip 192.168.7.1
U-Boot# setenv ipaddr 192.168.7.2
U-Boot# saveenv
```

**Load kernel via TFTP:**

```
U-Boot# tftp 0x82000000 zImage
Using ethernet@4a100000 device
TFTP from server 192.168.7.1; our IP address is 192.168.7.2
Filename 'zImage'.
Load address: 0x82000000
Loading: #################################################################
         #################################################################
         4.2 MiB/s
done
Bytes transferred = 4456789 (440055 hex)
```

**Load device tree:**

```
U-Boot# tftp 0x88000000 am335x-boneblack-custom.dtb
Using ethernet@4a100000 device
TFTP from server 192.168.7.1; our IP address is 192.168.7.2
Filename 'am335x-boneblack-custom.dtb'.
Load address: 0x88000000
Loading: ##
         45 KiB/s
done
Bytes transferred = 45678 (b26e hex)
```

**Boot kernel:**

```
U-Boot# bootz 0x82000000 - 0x88000000
## Flattened Device Tree blob at 88000000
   Booting using the fdt blob at 0x88000000
   Loading Device Tree to 8fff4000, end 8ffffb6d ... OK

Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 5.10.210 ...
[    0.000000] CPU: ARMv7 Processor [413fc082] revision 2 (ARMv7), cr=10c5387d
...
```

---

## Usage Examples

### Basic Usage

```bash
bash scripts/deploy.sh
```

### Dry-Run (Test Without Deploying)

```bash
bash scripts/deploy.sh --dry-run
```

**Output:**

```
tftp put /workspace/build/kernel/zImage zImage
tftp put /workspace/build/kernel/am335x-boneblack-custom.dtb am335x-boneblack-custom.dtb
tftp put /workspace/build/rootfs.tar.gz rootfs.tar.gz
```

### Override TFTP Server

```bash
TFTP_SERVER=10.0.0.5 bash scripts/deploy.sh
```

### Deploy to Different Network

```bash
# If BeagleBone on Ethernet (not USB):
TFTP_SERVER=192.168.1.100 bash scripts/deploy.sh
```

---

## Troubleshooting

### Issue: "tftp: command not found"

**Cause:** TFTP client not installed

**Solution:**

```bash
sudo apt install tftp-hpa
```

---

### Issue: "Connection refused"

**Cause:** TFTP server not running

**Check:**

```bash
sudo systemctl status tftpd-hpa
```

**Fix:**

```bash
sudo systemctl start tftpd-hpa
sudo systemctl enable tftpd-hpa
```

---

### Issue: "Permission denied" writing to /srv/tftp

**Cause:** TFTP directory permissions

**Fix:**

```bash
sudo chown tftp:tftp /srv/tftp
sudo chmod 755 /srv/tftp
```

---

### Issue: "File not found" in deploy.sh

**Cause:** Kernel not built yet

**Fix:**

```bash
# Build kernel first
bash scripts/build.sh kernel

# Then deploy
bash scripts/deploy.sh
```

---

### Issue: U-Boot TFTP timeout

**Cause:** Network not configured or firewall blocking

**Check network:**

```bash
# On PC:
ping 192.168.7.2

# On BeagleBone (U-Boot):
U-Boot# ping 192.168.7.1
```

**Check firewall:**

```bash
# Allow TFTP (UDP port 69)
sudo ufw allow 69/udp
```

---

## Integration with Makefile

**Makefile provides shortcut:**

```makefile
# Makefile
deploy:
	bash scripts/deploy.sh --host $(HOST) --kernel --dtb
```

**Usage:**

```bash
# Using Makefile:
make deploy HOST=192.168.7.2

# Or direct script:
bash scripts/deploy.sh
```

---

## Best Practices

### 1. Always Build Before Deploy

```bash
# Good:
bash scripts/build.sh kernel
bash scripts/deploy.sh

# Bad:
bash scripts/deploy.sh  # Deploys old kernel!
```

---

### 2. Use Dry-Run for Testing

```bash
# Test script first:
bash scripts/deploy.sh --dry-run

# If OK, run for real:
bash scripts/deploy.sh
```

---

### 3. Verify TFTP Server Before Deploy

```bash
# Check TFTP server is running:
sudo systemctl status tftpd-hpa

# Check network connectivity:
ping 192.168.7.2
```

---

### 4. Use TFTP for Development, SD Card for Production

**Development (fast iteration):**

```bash
# Edit → Build → Deploy → Boot from TFTP → Test
bash scripts/build.sh kernel
bash scripts/deploy.sh
# U-Boot boots from TFTP (no SD write)
```

**Production (permanent):**

```bash
# Build → Flash SD card → Deploy to field
bash scripts/build.sh all
sudo bash scripts/flash_sd.sh /dev/sdb
# SD card has permanent image
```

---

## Performance Comparison

### TFTP Boot (Development)

```
Time breakdown:
  Build kernel:        3 minutes
  Deploy (TFTP):       5 seconds
  U-Boot TFTP load:    10 seconds
  Kernel boot:         15 seconds
  Total:               ~3.5 minutes

Iteration time:        30 seconds (after first build)
```

### SD Card Boot (Traditional)

```
Time breakdown:
  Build kernel:        3 minutes
  Write to SD:         30 seconds
  Eject/insert SD:     20 seconds
  Power on:            5 seconds
  U-Boot load:         5 seconds
  Kernel boot:         15 seconds
  Total:               ~4.5 minutes

Iteration time:        1 minute (after first build)
```

**TFTP is 2x faster for development!**

---

## Summary

**deploy.sh provides:**

- Fast deployment over USB network
- No SD card writes (faster iteration)
- TFTP protocol (U-Boot compatible)
- Dry-run mode (safe testing)
- Error checking (file existence)
- Configurable TFTP server

**Key concepts:**

- USB gadget network (192.168.7.1/192.168.7.2)
- TFTP protocol (simple, bootloader-friendly)
- Dry-run pattern (test before execute)
- Development workflow (build → deploy → boot → test)

## References

- TFTP RFC 1350: https://www.rfc-editor.org/rfc/rfc1350
- BeagleBone USB gadget: https://beagleboard.org/getting-started
- U-Boot TFTP: https://u-boot.readthedocs.io/en/latest/usage/cmd/tftp.html
- tftpd-hpa manual: https://linux.die.net/man/8/tftpd-hpa
