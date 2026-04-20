---
title: flash_sd.sh - SD Card Flashing
tags:
  - scripts
  - flash
  - sd-card
  - dangerous
date: 2026-04-20
category: scripts
---

# flash_sd.sh - SD Card Flashing

⚠️ **WARNING: This script is DESTRUCTIVE and will ERASE ALL DATA on the target device!**

`scripts/flash_sd.sh` creates a bootable SD card for BeagleBone Black with boot files and optional root filesystem.

## ⚠️ CRITICAL SAFETY WARNING

```
┌─────────────────────────────────────────────┐
│     DANGER - READ CAREFULLY BEFORE USE      │
├─────────────────────────────────────────────┤
│ This script will:                           │
│ • DELETE all partitions                     │
│ • FORMAT entire device                      │
│ • Data is NOT recoverable!                  │
│                                             │
│ If you specify wrong device:                │
│ • /dev/sda → Deletes main hard drive! 💀    │
│ • /dev/nvme0n1 → Deletes SSD! 💀            │
│ • /dev/mmcblk0 → Deletes eMMC! 💀           │
│                                             │
│ ALWAYS verify device name with lsblk first! │
└─────────────────────────────────────────────┘
```

## Purpose

Create a **permanent bootable SD card** for BeagleBone Black.

**When to use:**

- ✅ Production deployment
- ✅ First-time board setup
- ✅ Recovery (board won't boot)
- ✅ Creating backup SD cards

**When NOT to use:**

- ❌ Development (use TFTP instead - see [[04-deploy-sh]])
- ❌ Quick testing (TFTP is faster)
- ❌ Frequent kernel updates (TFTP avoids SD wear)

## SD Card vs TFTP Boot

| Aspect             | SD Card Boot             | TFTP Boot                |
| ------------------ | ------------------------ | ------------------------ |
| **Speed**          | Slow (SD write ~10 MB/s) | Fast (network ~100 MB/s) |
| **Iteration time** | ~5 minutes               | ~30 seconds              |
| **Permanence**     | Permanent                | Temporary (RAM only)     |
| **Use case**       | Production, recovery     | Development              |
| **SD card wear**   | High (frequent writes)   | None                     |

**Recommendation:** Use TFTP for development, SD card for production.

## BeagleBone Boot Sequence

### Boot from SD Card

```
Power on
    ↓
ROM Bootloader (in SoC, read-only)
    ↓
Search boot devices in order:
  1. MMC0 (SD card) - if BOOT button pressed
  2. MMC1 (eMMC)    - default
  3. UART0
  4. USB
    ↓
Load MLO from boot partition (FAT32)
    ↓
MLO runs (SPL - initialize DDR RAM)
    ↓
MLO loads U-Boot from boot partition
    ↓
U-Boot runs
    ↓
U-Boot reads uEnv.txt
    ↓
U-Boot loads kernel (zImage) + device tree (.dtb)
    ↓
Kernel boots
    ↓
Mount rootfs from partition 2 (ext4)
    ↓
Linux running!
```

### Boot Button

**To force SD card boot (override eMMC):**

1. Insert SD card
2. **Hold BOOT button** (near SD card slot)
3. Apply power
4. Wait 2 seconds
5. Release BOOT button
6. Board boots from SD card

**BOOT button location:** Near SD card slot, labeled "BOOT" or "S2"

## SD Card Layout

### Partition Structure

```
/dev/sdb (SD card - 8 GB example)
├── /dev/sdb1 (100 MB, FAT32, bootable)
│   ├── MLO                          (SPL - 103 KB)
│   ├── u-boot.img                   (U-Boot - 487 KB)
│   ├── zImage                       (Kernel - 4.2 MB)
│   ├── am335x-boneblack-custom.dtb  (Device tree - 63 KB)
│   └── uEnv.txt                     (U-Boot environment - 1 KB)
│
└── /dev/sdb2 (7.9 GB, ext4)
    └── (root filesystem)
        ├── bin/
        ├── boot/
        ├── dev/
        ├── etc/
        ├── home/
        ├── lib/
        ├── proc/
        ├── root/
        ├── sbin/
        ├── sys/
        ├── tmp/
        ├── usr/
        └── var/
```

### Why Partition 1 is FAT32?

**ROM bootloader requirements:**

- Only understands FAT12/FAT16/FAT32
- Cannot read ext4, NTFS, etc.
- Must have boot flag set

**U-Boot requirements:**

- Good FAT32 support
- Can also read ext4 (but ROM can't)

### Why Partition 2 is ext4?

**Linux requirements:**

- Native Linux filesystem
- Supports permissions (chmod, chown)
- Supports symbolic links
- Better performance than FAT32
- Journaling (crash recovery)

## Script Analysis

### Safety Checks (4 Layers)

The script has **4 safety checks** to prevent disasters:

#### 1. Device Name Check

```bash
if [[ "${DEV}" != /dev/sd* ]]; then
    echo "[flash] refusing: ${DEV} does not start with /dev/sd" >&2
    exit 1
fi
```

**Only allows `/dev/sd*` devices:**

```
✅ Allowed:
  /dev/sdb, /dev/sdc, /dev/sdd  (USB/SD card readers)

❌ Rejected:
  /dev/sda         (usually main hard drive)
  /dev/nvme0n1     (NVMe SSD)
  /dev/mmcblk0     (eMMC/SD card - could be system disk)
  /dev/null        (special device)
```

**Why this restriction?**

- `/dev/sda` is typically the main system disk
- `/dev/sdb`, `/dev/sdc` are typically removable drives
- Reduces (but doesn't eliminate) risk

**⚠️ Still dangerous:** `/dev/sdb` could be your backup drive!

#### 2. Mounted Filesystem Check

```bash
if grep -qE "^${DEV}[0-9]* +(/|/home) " /proc/mounts 2>/dev/null; then
    echo "[flash] refusing: ${DEV} is mounted at / or /home" >&2
    exit 1
fi
```

**Checks if device is mounted at `/` or `/home`:**

```bash
# /proc/mounts contains:
/dev/sda1 / ext4 rw,relatime 0 0
/dev/sda2 /home ext4 rw,relatime 0 0
/dev/sdb1 /mnt/usb vfat rw,relatime 0 0

# Try to flash /dev/sda:
grep -qE "^/dev/sda[0-9]* +(/|/home) " /proc/mounts
# Match found! → REFUSE
```

**Prevents:**

- Erasing system disk
- Erasing home directory

#### 3. Root Permission Check

```bash
if [[ "$(id -u)" -ne 0 ]]; then
    echo "[flash] ERROR: must run as root" >&2
    exit 1
fi
```

**Requires root (UID 0):**

```bash
# Normal user:
id -u  # Output: 1000
# Script refuses

# Root:
sudo id -u  # Output: 0
# Script continues
```

**Why root required?**

- Partition operations (`sfdisk`)
- Format operations (`mkfs.vfat`, `mkfs.ext4`)
- Mount operations
- Direct block device access

#### 4. User Confirmation

```bash
echo "[flash] WARNING: all data on ${DEV} will be erased"
read -r -p "[flash] type 'yes' to continue: " CONFIRM
[[ "${CONFIRM}" == "yes" ]] || { echo "[flash] aborted"; exit 1; }
```

**Must type exactly "yes":**

```
✅ Accepted:
  yes

❌ Rejected:
  y
  YES
  Yes
  yeah
  (anything else)
```

**Why so strict?**

- Prevents typos
- Forces user to read warning
- Best practice for destructive operations

### Partitioning with sfdisk

```bash
sfdisk "${DEV}" <<EOF
label: dos
,100M,c,*
,,83
EOF
```

**sfdisk = scriptable fdisk**

#### Partition Table Format

```
label: dos
```

- `dos` = MBR partition table (not GPT)
- Compatible with AM335x ROM bootloader

#### Partition 1 (Boot)

```
,100M,c,*
│ │   │ │
│ │   │ └─ * = bootable flag (REQUIRED for ROM bootloader)
│ │   └─ c = partition type (0x0c = FAT32 LBA)
│ └─ 100M = size (100 megabytes)
└─ (empty) = start at first available sector
```

**Partition type codes:**

```
0x0c (c)  = FAT32 LBA
0x83 (83) = Linux
0x82      = Linux swap
0x07      = NTFS
0x0b      = FAT32
```

**Why bootable flag is critical:**

- AM335x ROM bootloader searches for bootable partition
- Without boot flag → ROM can't find MLO → boot fails!

#### Partition 2 (Root)

```
,,83
││ │
││ └─ 83 = partition type (0x83 = Linux)
│└─ (empty) = use all remaining space
└─ (empty) = start after partition 1
```

**Uses all remaining space on SD card.**

### Formatting Partitions

```bash
mkfs.vfat -F 32 "${P1}"
mkfs.ext4 -F "${P2}"
```

**mkfs.vfat:**

- `-F 32` = FAT32 (not FAT16)
- Creates FAT32 filesystem on partition 1

**mkfs.ext4:**

- `-F` = force (don't ask for confirmation)
- Creates ext4 filesystem on partition 2

### Cleanup Trap

```bash
MNT_BOOT="$(mktemp -d)"
MNT_ROOT="$(mktemp -d)"

cleanup() {
    umount "${MNT_BOOT}" 2>/dev/null || true
    umount "${MNT_ROOT}" 2>/dev/null || true
    rmdir "${MNT_BOOT}" "${MNT_ROOT}" 2>/dev/null || true
}
trap cleanup EXIT
```

**mktemp -d:**

- Creates temporary directory
- Example: `/tmp/tmp.xYz123`

**trap cleanup EXIT:**

- Runs `cleanup()` when script exits
- Works even if script crashes
- Ensures partitions are unmounted

**Why this is important:**

```bash
# Without trap:
mount /dev/sdb1 /mnt/boot
# Script crashes
# /dev/sdb1 still mounted! ❌
# Can't eject SD card

# With trap:
trap cleanup EXIT
mount /dev/sdb1 /mnt/boot
# Script crashes
# cleanup() runs automatically
# /dev/sdb1 unmounted ✅
# Can safely eject SD card
```

### Boot Files

```bash
for f in MLO u-boot.img zImage am335x-boneblack-custom.dtb; do
    case "${f}" in
        MLO|u-boot.img) src="${BUILD_DIR}/uboot/${f}" ;;
        zImage|*.dtb)   src="${BUILD_DIR}/kernel/${f}" ;;
    esac
    cp "${src}" "${MNT_BOOT}/"
done
```

**4 required files:**

1. **MLO** (103 KB)
   - SPL (Secondary Program Loader)
   - First code executed after ROM
   - Initializes DDR RAM
   - Loads U-Boot

2. **u-boot.img** (487 KB)
   - Full U-Boot bootloader
   - Provides boot menu
   - Loads kernel

3. **zImage** (4.2 MB)
   - Compressed Linux kernel
   - Contains kernel code + built-in drivers

4. **am335x-boneblack-custom.dtb** (63 KB)
   - Device tree blob
   - Describes hardware to kernel (UART1/2, I2C1/2, PWM, GPIO)

### uEnv.txt Configuration

```bash
cat > "${MNT_BOOT}/uEnv.txt" <<'UENV'
bootargs=console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
uenvcmd=load mmc 0:1 ${loadaddr} zImage; load mmc 0:1 ${fdtaddr} am335x-boneblack-custom.dtb; bootz ${loadaddr} - ${fdtaddr}
UENV
```

#### Line 1: bootargs (Kernel Command Line)

```bash
bootargs=console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
```

**Parameter breakdown:**

```
console=ttyO0,115200n8
│       │     │      │
│       │     │      └─ 8N1 (8 data bits, no parity, 1 stop bit)
│       │     └─ Baud rate: 115200
│       └─ UART device: ttyO0 (OMAP UART0)
└─ Enable serial console output

root=/dev/mmcblk0p2
│    │
│    └─ Root filesystem device (partition 2 of SD card)
└─ Kernel parameter

rw
└─ Mount root as read-write (not read-only)

rootfstype=ext4
└─ Root filesystem type

rootwait
└─ Wait for root device to appear (important for SD card detection)
```

**Why `ttyO0` not `ttyS0`?**

- OMAP UARTs use `ttyO` prefix (not standard `ttyS`)
- BeagleBone Black uses OMAP UART0 → `ttyO0`

**Why `rootwait`?**

- SD card detection takes time
- Without `rootwait`, kernel might try to mount before SD is ready
- Causes "Kernel panic - not syncing: VFS: Unable to mount root fs"

#### Line 2: uenvcmd (U-Boot Commands)

```bash
uenvcmd=load mmc 0:1 ${loadaddr} zImage; load mmc 0:1 ${fdtaddr} am335x-boneblack-custom.dtb; bootz ${loadaddr} - ${fdtaddr}
```

**Three commands (separated by `;`):**

**Command 1: Load kernel**

```bash
load mmc 0:1 ${loadaddr} zImage
│    │   │ │  │          │
│    │   │ │  │          └─ Filename
│    │   │ │  └─ Destination address (0x82000000)
│    │   │ └─ Partition (device 0, partition 1)
│    │   └─ Device number
│    └─ Device type (mmc = SD/eMMC)
└─ U-Boot command
```

**Command 2: Load device tree**

```bash
load mmc 0:1 ${fdtaddr} am335x-boneblack-custom.dtb
# Load DTB to address 0x88000000
```

**Command 3: Boot kernel**

```bash
bootz ${loadaddr} - ${fdtaddr}
│     │           │ │
│     │           │ └─ Device tree address (0x88000000)
│     │           └─ No initramfs (-)
│     └─ Kernel address (0x82000000)
└─ Boot zImage (ARM compressed kernel)
```

**U-Boot memory addresses:**

```
${loadaddr} = 0x82000000  (kernel in DDR)
${fdtaddr}  = 0x88000000  (device tree in DDR)
```

**Why these addresses?**

- AM335x DDR starts at 0x80000000
- Kernel at 0x82000000 (32 MB offset)
- DTB at 0x88000000 (128 MB offset)
- Ensures no overlap

## Complete Workflow

### Step 1: Identify SD Card Device

**⚠️ CRITICAL: Verify device name before flashing!**

```bash
# Before inserting SD card:
lsblk
# NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda      8:0    0 238.5G  0 disk
# ├─sda1   8:1    0   512M  0 part /boot/efi
# └─sda2   8:2    0   238G  0 part /

# Insert SD card, then:
lsblk
# NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda      8:0    0 238.5G  0 disk
# ├─sda1   8:1    0   512M  0 part /boot/efi
# └─sda2   8:2    0   238G  0 part /
# sdb      8:16   1   7.4G  0 disk           ← SD card appeared!
# └─sdb1   8:17   1   7.4G  0 part /media/user/SD
```

**SD card is `/dev/sdb`** ✅

**Alternative method:**

```bash
sudo dmesg | tail -20
# [12345.678] sd 6:0:0:0: [sdb] 15523840 512-byte logical blocks
# [12345.679] sd 6:0:0:0: [sdb] Attached SCSI removable disk
```

**Check size to confirm:**

```bash
sudo fdisk -l /dev/sdb
# Disk /dev/sdb: 7.4 GiB, 7948206080 bytes, 15523840 sectors
```

### Step 2: Build Artifacts

```bash
cd "${BSP_ROOT}"

# Build U-Boot
bash scripts/build.sh uboot

# Build kernel
bash scripts/build.sh kernel
```

**Verify artifacts exist:**

```bash
ls -lh build/uboot/
# -rw-r--r-- 1 nhat nhat 103K Apr 20 12:00 MLO
# -rw-r--r-- 1 nhat nhat 487K Apr 20 12:00 u-boot.img

ls -lh build/kernel/
# -rw-r--r-- 1 nhat nhat 4.2M Apr 20 12:00 zImage
# -rw-r--r-- 1 nhat nhat  63K Apr 20 12:00 am335x-boneblack-custom.dtb
```

### Step 3: Flash SD Card

```bash
sudo bash scripts/flash_sd.sh /dev/sdb
```

**Output:**

```
[flash] target: /dev/sdb
[flash] WARNING: all data on /dev/sdb will be erased
[flash] type 'yes' to continue: yes
[flash] partitioning /dev/sdb
Checking that no-one is using this disk right now ... OK
[flash] formatting /dev/sdb1 as FAT32
mkfs.fat 4.2 (2021-01-31)
[flash] formatting /dev/sdb2 as ext4
mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 1888256 4k blocks and 472320 inodes
[flash] copying boot files
[flash] uEnv.txt written
[flash] done — safely remove /dev/sdb
```

### Step 4: Eject SD Card

```bash
sudo eject /dev/sdb
```

**Or use GUI:**

- Right-click SD card in file manager
- Select "Eject" or "Safely Remove"

### Step 5: Boot BeagleBone

1. **Insert SD card** into BeagleBone
2. **Hold BOOT button** (near SD card slot)
3. **Apply power** (USB or 5V barrel jack)
4. **Wait 2 seconds**
5. **Release BOOT button**
6. **Connect serial console:**
   ```bash
   minicom -D /dev/ttyUSB0 -b 115200
   ```

**Expected output:**

```
U-Boot SPL 2022.07 (Apr 20 2026 - 12:00:00 +0000)
Trying to boot from MMC1

U-Boot 2022.07 (Apr 20 2026 - 12:00:00 +0000)

CPU  : AM335X-GP rev 2.1
Model: TI AM335x BeagleBone Black
DRAM:  512 MiB
...
Loading Environment from FAT... OK
...
Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 5.10.210 ...
...
BeagleBone login:
```

## Usage Examples

### Basic Usage (Boot Partition Only)

```bash
sudo bash scripts/flash_sd.sh /dev/sdb
```

**Creates:**

- Partition 1: Boot files (MLO, U-Boot, kernel, dtb)
- Partition 2: Empty ext4 filesystem

### With Root Filesystem

```bash
sudo bash scripts/flash_sd.sh /dev/sdb rootfs.tar.gz
```

**Creates:**

- Partition 1: Boot files
- Partition 2: Extracted rootfs

**Where to get rootfs.tar.gz?**

- Build with Yocto (see [[../yocto/_index]])
- Download from BeagleBoard.org
- Build with Buildroot

### Dry-Run (Check Before Flashing)

**Script doesn't have dry-run mode, but you can check manually:**

```bash
# Check device:
lsblk /dev/sdb

# Check if mounted at / or /home:
grep "^/dev/sdb" /proc/mounts

# Check artifacts exist:
ls -lh build/uboot/MLO build/uboot/u-boot.img
ls -lh build/kernel/zImage build/kernel/am335x-boneblack-custom.dtb
```

## Troubleshooting

### Issue: "refusing: /dev/sdb does not start with /dev/sd"

**Cause:** Device name doesn't match allowed pattern

**Examples:**

```bash
sudo bash scripts/flash_sd.sh /dev/nvme0n1
# [flash] refusing: /dev/nvme0n1 does not start with /dev/sd

sudo bash scripts/flash_sd.sh /dev/mmcblk0
# [flash] refusing: /dev/mmcblk0 does not start with /dev/sd
```

**Solution:**

If you're sure the device is correct, you can:

**Option 1: Use SD card reader (recommended)**

- SD card readers appear as `/dev/sd*`
- Safer than modifying script

**Option 2: Modify script (advanced)**

```bash
# Edit scripts/flash_sd.sh
# Change line 24 from:
if [[ "${DEV}" != /dev/sd* ]]; then

# To (example for NVMe):
if [[ "${DEV}" != /dev/sd* && "${DEV}" != /dev/nvme* ]]; then
```

**⚠️ Warning:** Only do this if you understand the risks!

---

### Issue: "refusing: /dev/sda is mounted at / or /home"

**Cause:** Trying to flash system disk

**Example:**

```bash
sudo bash scripts/flash_sd.sh /dev/sda
# [flash] refusing: /dev/sda is mounted at / or /home
```

**Solution:**

**This is a safety feature!** Don't override it.

**Verify device:**

```bash
lsblk
# NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda      8:0    0 238.5G  0 disk
# ├─sda1   8:1    0   512M  0 part /boot/efi  ← System disk!
# └─sda2   8:2    0   238G  0 part /           ← System disk!
# sdb      8:16   1   7.4G  0 disk              ← SD card
```

**Use `/dev/sdb` instead.**

---

### Issue: "ERROR: must run as root"

**Cause:** Script requires root permissions

**Solution:**

```bash
# Wrong:
bash scripts/flash_sd.sh /dev/sdb
# [flash] ERROR: must run as root

# Correct:
sudo bash scripts/flash_sd.sh /dev/sdb
```

---

### Issue: "ERROR: /dev/sdb is not a block device"

**Cause:** Device doesn't exist or is not a block device

**Check:**

```bash
ls -l /dev/sdb
# ls: cannot access '/dev/sdb': No such file or directory
```

**Solution:**

1. **Verify SD card is inserted:**

   ```bash
   lsblk
   ```

2. **Check dmesg for detection:**

   ```bash
   sudo dmesg | tail -20
   ```

3. **Try different USB port**

4. **Check SD card reader is working:**
   ```bash
   lsusb
   # Should show USB card reader
   ```

---

### Issue: "ERROR: build/uboot/MLO not found"

**Cause:** Artifacts not built yet

**Solution:**

```bash
# Build U-Boot first:
bash scripts/build.sh uboot

# Build kernel:
bash scripts/build.sh kernel

# Then flash:
sudo bash scripts/flash_sd.sh /dev/sdb
```

---

### Issue: Board doesn't boot from SD card

**Symptoms:**

- Board boots from eMMC instead of SD card
- Serial console shows eMMC boot messages

**Causes & Solutions:**

#### 1. BOOT button not held

**Solution:**

1. Power off board
2. **Hold BOOT button** before applying power
3. Apply power while holding button
4. Wait 2 seconds
5. Release button

#### 2. SD card not detected

**Check:**

```bash
# In U-Boot prompt:
U-Boot# mmc list
# mmc@48060000: 0 (SD)
# mmc@481d8000: 1 (eMMC)

U-Boot# mmc dev 0
# switch to partitions #0, OK
# mmc0 is current device
```

**If SD not detected:**

- Try different SD card
- Check SD card is properly inserted
- Clean SD card contacts

#### 3. Boot flag not set

**Verify partition table:**

```bash
sudo fdisk -l /dev/sdb
# Device     Boot  Start      End  Sectors  Size Id Type
# /dev/sdb1  *      2048   206847   204800  100M  c W95 FAT32 (LBA)
#            ↑ Boot flag must be present!
# /dev/sdb2       206848 15523839 15316992  7.3G 83 Linux
```

**If boot flag missing:**

```bash
sudo fdisk /dev/sdb
# Command: a (toggle bootable flag)
# Partition: 1
# Command: w (write and exit)
```

#### 4. MLO not found or corrupted

**Verify MLO on SD card:**

```bash
sudo mount /dev/sdb1 /mnt
ls -lh /mnt/MLO
# -rw-r--r-- 1 root root 103K Apr 20 12:00 /mnt/MLO

# Check file is not empty:
file /mnt/MLO
# /mnt/MLO: data

sudo umount /mnt
```

**If MLO missing or wrong size:**

- Re-flash SD card
- Verify build artifacts before flashing

---

### Issue: Kernel panic - VFS: Unable to mount root fs

**Error message:**

```
[    1.234567] VFS: Cannot open root device "mmcblk0p2" or unknown-block(0,0)
[    1.234568] Please append a correct "root=" boot option
[    1.234569] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

**Causes & Solutions:**

#### 1. Wrong root device in uEnv.txt

**Check uEnv.txt:**

```bash
sudo mount /dev/sdb1 /mnt
cat /mnt/uEnv.txt
# bootargs=console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
#                                      ↑ Should be mmcblk0p2 (not sdb2!)
sudo umount /mnt
```

**Why `mmcblk0p2` not `sdb2`?**

- On PC: SD card is `/dev/sdb`
- On BeagleBone: SD card is `/dev/mmcblk0`
- Different device naming!

#### 2. Partition 2 not formatted

**Check partition 2:**

```bash
sudo mount /dev/sdb2 /mnt
ls /mnt/
# Should show rootfs contents (bin/, etc/, lib/, ...)
sudo umount /mnt
```

**If empty or mount fails:**

```bash
# Re-format partition 2:
sudo mkfs.ext4 -F /dev/sdb2

# Extract rootfs:
sudo mount /dev/sdb2 /mnt
sudo tar -xf rootfs.tar.gz -C /mnt
sudo umount /mnt
```

#### 3. Missing rootwait parameter

**uEnv.txt must have `rootwait`:**

```bash
bootargs=... rootwait
#            ↑ Required for SD card!
```

**Without `rootwait`:**

- Kernel tries to mount before SD card is ready
- Causes panic

---

### Issue: SD card write-protected

**Error:**

```bash
sudo bash scripts/flash_sd.sh /dev/sdb
# sfdisk: cannot open /dev/sdb: Read-only file system
```

**Solution:**

1. **Check physical write-protect switch on SD card**
   - Small switch on side of SD card
   - Move to "unlocked" position

2. **Check SD card adapter**
   - Some adapters have write-protect switch
   - Move to "unlocked" position

3. **Try different SD card**
   - Card might be damaged

---

### Issue: "Device or resource busy"

**Error:**

```bash
sudo bash scripts/flash_sd.sh /dev/sdb
# umount: /dev/sdb1: target is busy
```

**Cause:** SD card is being used by another process

**Solution:**

1. **Close all programs using SD card:**

   ```bash
   # Find processes using SD card:
   sudo lsof | grep /dev/sdb
   # Kill processes if needed
   ```

2. **Force unmount:**

   ```bash
   sudo umount -f /dev/sdb1
   sudo umount -f /dev/sdb2
   ```

3. **Eject and re-insert SD card**

4. **Reboot PC** (last resort)

## Best Practices

### 1. Always Verify Device Name

**Before flashing:**

```bash
# Check device name:
lsblk

# Check size matches SD card:
sudo fdisk -l /dev/sdb | head -1
# Disk /dev/sdb: 7.4 GiB

# Double-check it's not system disk:
grep "^/dev/sdb" /proc/mounts
# Should be empty or show /media/... (not / or /home)
```

**⚠️ One wrong letter = disaster!**

```
/dev/sdb → SD card ✅
/dev/sda → System disk 💀
```

---

### 2. Backup Important Data First

**If SD card has data you need:**

```bash
# Backup entire SD card:
sudo dd if=/dev/sdb of=sd_backup.img bs=4M status=progress

# Or backup specific files:
sudo mount /dev/sdb1 /mnt
cp -r /mnt/important_data ~/backup/
sudo umount /mnt
```

**Restore later:**

```bash
sudo dd if=sd_backup.img of=/dev/sdb bs=4M status=progress
```

---

### 3. Use TFTP for Development

**Don't flash SD card for every kernel change!**

**Development workflow:**

```bash
# Edit code
vim drivers/gpio/gpio-omap.c

# Build
bash scripts/build.sh kernel

# Deploy via TFTP (30 seconds)
bash scripts/deploy.sh

# Boot from TFTP
# (U-Boot loads from network, no SD write)

# Test
# Repeat...
```

**Flash SD card only for:**

- Production deployment
- Creating backup SD cards
- Recovery

---

### 4. Label SD Cards

**Physical labels:**

- Write on SD card with permanent marker
- Examples: "BBB Boot v1.0", "Production 2026-04", "Test Kernel"

**Filesystem labels:**

```bash
# Label boot partition:
sudo fatlabel /dev/sdb1 "BBB_BOOT"

# Label root partition:
sudo e2label /dev/sdb2 "BBB_ROOT"

# Verify:
lsblk -o NAME,LABEL
# NAME   LABEL
# sdb
# ├─sdb1 BBB_BOOT
# └─sdb2 BBB_ROOT
```

---

### 5. Keep Multiple SD Cards

**Recommended setup:**

- **SD card 1:** Stable production image
- **SD card 2:** Testing/development
- **SD card 3:** Recovery/backup

**Benefits:**

- Quick rollback if test fails
- Always have working board
- Can compare behavior

---

### 6. Verify After Flashing

**Check boot partition:**

```bash
sudo mount /dev/sdb1 /mnt
ls -lh /mnt/
# Should show: MLO, u-boot.img, zImage, am335x-boneblack-custom.dtb, uEnv.txt
cat /mnt/uEnv.txt
# Verify bootargs and uenvcmd
sudo umount /mnt
```

**Check root partition (if used):**

```bash
sudo mount /dev/sdb2 /mnt
ls /mnt/
# Should show: bin/, etc/, lib/, usr/, var/, ...
sudo umount /mnt
```

---

### 7. Safe Eject

**Always eject before removing:**

```bash
sudo eject /dev/sdb
```

**Or use GUI eject.**

**Why?**

- Flushes filesystem buffers
- Ensures all writes completed
- Prevents corruption

---

## Performance Tips

### 1. Use Fast SD Card

**SD card speed classes:**

```
Class 2:  2 MB/s   (slow)
Class 4:  4 MB/s   (slow)
Class 10: 10 MB/s  (OK)
UHS-I:    50 MB/s  (good)
UHS-II:   156 MB/s (fast)
```

**Recommendation:** Class 10 or better

**Check SD card speed:**

```bash
sudo hdparm -t /dev/sdb
# Timing buffered disk reads: 60 MB in 3.01 seconds = 19.93 MB/sec
```

---

### 2. Use Larger Block Size

**Script uses default block size, but you can optimize:**

```bash
# Default:
mkfs.ext4 -F /dev/sdb2

# Optimized for SD card:
mkfs.ext4 -F -b 4096 -E stride=2,stripe-width=1024 /dev/sdb2
```

**Explanation:**

- `-b 4096` = 4KB block size (matches SD card erase block)
- `-E stride=2` = 2 blocks per stripe
- `-E stripe-width=1024` = RAID stripe width

**⚠️ Advanced:** Only modify if you understand the parameters.

---

### 3. Disable Journal (Optional)

**For read-mostly SD cards:**

```bash
# Disable ext4 journal (faster, less wear):
sudo tune2fs -O ^has_journal /dev/sdb2

# Re-enable if needed:
sudo tune2fs -O has_journal /dev/sdb2
```

**Trade-off:**

- ✅ Faster writes
- ✅ Less SD card wear
- ❌ No crash recovery

---

## Integration with Makefile

**Makefile provides shortcut:**

```makefile
# Makefile
flash:
	sudo bash scripts/flash_sd.sh $(DEV)
```

**Usage:**

```bash
# Using Makefile:
make flash DEV=/dev/sdb

# Or direct script:
sudo bash scripts/flash_sd.sh /dev/sdb
```

---

## Security Considerations

### 1. Root Requirement

**Script requires root:**

- Can access any block device
- Can destroy any disk
- **Be extremely careful!**

**Alternatives:**

- Use `sudo` (requires password each time)
- Add user to `disk` group (dangerous!)
- Use udev rules (advanced)

---

### 2. No Undo

**Once script starts:**

- Partition table is overwritten
- Data is lost forever
- **No recovery possible!**

**Mitigation:**

- Always backup first
- Verify device name twice
- Use dry-run checks

---

### 3. Physical Security

**SD card contains:**

- Bootloader (can be modified)
- Kernel (can be modified)
- Root filesystem (can contain secrets)

**Recommendations:**

- Don't leave SD cards unattended
- Encrypt sensitive data
- Use secure boot (advanced)

---

## Summary

**flash_sd.sh provides:**

- ✅ Bootable SD card creation
- ✅ 4 layers of safety checks
- ✅ Automatic partitioning (FAT32 + ext4)
- ✅ Boot files installation
- ✅ Optional rootfs extraction
- ✅ Cleanup on exit (trap)

**Safety features:**

1. Device name check (`/dev/sd*` only)
2. Mounted filesystem check (refuse `/` or `/home`)
3. Root permission check
4. User confirmation (must type "yes")

**Key concepts:**

- MBR partition table (DOS label)
- FAT32 boot partition (100 MB, bootable)
- ext4 root partition (remaining space)
- uEnv.txt configuration
- AM335x boot sequence (ROM → MLO → U-Boot → kernel)

**Best practices:**

- Always verify device name with `lsblk`
- Backup important data first
- Use TFTP for development (not SD card)
- Label SD cards physically
- Keep multiple SD cards
- Safe eject before removing

---

## Next Steps

- **Build kernel:** [[03-build-sh-functions]]
- **Deploy via TFTP:** [[04-deploy-sh]]
- **U-Boot configuration:** [[../bootloader/05-uboot-build-verify]]
- **First boot:** [[../../docs/bringup-notes]] (TODO)

---

## References

- BeagleBone Black SRM Rev C: https://github.com/beagleboard/beaglebone-black/wiki/System-Reference-Manual
- AM335x TRM (SPRUH73Q): https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
- U-Boot documentation: https://u-boot.readthedocs.io/
- sfdisk manual: https://man7.org/linux/man-pages/man8/sfdisk.8.html
- mkfs.vfat manual: https://linux.die.net/man/8/mkfs.vfat
- mkfs.ext4 manual: https://linux.die.net/man/8/mkfs.ext4
