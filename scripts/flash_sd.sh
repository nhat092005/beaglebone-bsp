#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"

usage() {
    echo "Usage: $0 <device> [rootfs.tar.gz]"
    echo ""
    echo "  device        Block device to flash (must start with /dev/sd, e.g. /dev/sdb)"
    echo "  rootfs.tar.gz Optional rootfs tarball to write to partition 2"
    echo ""
    echo "WARNING: All data on <device> will be erased."
    exit 1
}

[[ $# -ge 1 ]] || usage

DEV="$1"
ROOTFS="${2:-}"

# Must start with /dev/sd — reject everything else (nvme, mmcblk, null, etc.)
if [[ "${DEV}" != /dev/sd* ]]; then
    echo "[flash] refusing: ${DEV} does not start with /dev/sd" >&2
    exit 1
fi

# Refuse if device backs / or /home (check all partitions of DEV)
if grep -qE "^${DEV}[0-9]* +(/|/home) " /proc/mounts 2>/dev/null; then
    echo "[flash] refusing: ${DEV} is mounted at / or /home" >&2
    exit 1
fi

# Require root
if [[ "$(id -u)" -ne 0 ]]; then
    echo "[flash] ERROR: must run as root" >&2
    exit 1
fi

# Require block device
if [[ ! -b "${DEV}" ]]; then
    echo "[flash] ERROR: ${DEV} is not a block device" >&2
    exit 1
fi

echo "[flash] target: ${DEV}"
echo "[flash] WARNING: all data on ${DEV} will be erased"
read -r -p "[flash] type 'yes' to continue: " CONFIRM
[[ "${CONFIRM}" == "yes" ]] || { echo "[flash] aborted"; exit 1; }

# Unmount any existing partitions
for part in "${DEV}"?*; do
    umount "${part}" 2>/dev/null || true
done

# Partition: p1 FAT32 100 MiB with boot flag, p2 ext4 remainder
echo "[flash] partitioning ${DEV}"
sfdisk "${DEV}" <<EOF
label: dos
,100M,c,*
,,83
EOF

partprobe "${DEV}" 2>/dev/null || true
sleep 1

P1="${DEV}1"
P2="${DEV}2"

# Handle mmcblk-style names (should not reach here given /dev/sd check, but safe)
if [[ ! -b "${P1}" ]]; then
    P1="${DEV}p1"
    P2="${DEV}p2"
fi

echo "[flash] formatting ${P1} as FAT32"
mkfs.vfat -F 32 "${P1}"

echo "[flash] formatting ${P2} as ext4"
mkfs.ext4 -F "${P2}"

MNT_BOOT="$(mktemp -d)"
MNT_ROOT="$(mktemp -d)"

cleanup() {
    umount "${MNT_BOOT}" 2>/dev/null || true
    umount "${MNT_ROOT}" 2>/dev/null || true
    rmdir "${MNT_BOOT}" "${MNT_ROOT}" 2>/dev/null || true
}
trap cleanup EXIT

mount "${P1}" "${MNT_BOOT}"
mount "${P2}" "${MNT_ROOT}"

echo "[flash] copying boot files"
for f in MLO u-boot.img zImage am335x-boneblack-custom.dtb; do
    src="${BUILD_DIR}/kernel/${f}"
    # MLO and u-boot.img come from uboot subdir
    case "${f}" in
        MLO|u-boot.img) src="${BUILD_DIR}/uboot/${f}" ;;
        zImage|*.dtb)   src="${BUILD_DIR}/kernel/${f}" ;;
    esac
    [[ -f "${src}" ]] || { echo "[flash] ERROR: ${src} not found" >&2; exit 1; }
    cp "${src}" "${MNT_BOOT}/"
done

cat > "${MNT_BOOT}/uEnv.txt" <<'UENV'
bootargs=console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
uenvcmd=load mmc 0:1 ${loadaddr} zImage; load mmc 0:1 ${fdtaddr} am335x-boneblack-custom.dtb; bootz ${loadaddr} - ${fdtaddr}
UENV

echo "[flash] uEnv.txt written"

if [[ -n "${ROOTFS}" ]]; then
    [[ -f "${ROOTFS}" ]] || { echo "[flash] ERROR: rootfs ${ROOTFS} not found" >&2; exit 1; }
    echo "[flash] extracting rootfs"
    tar -xf "${ROOTFS}" -C "${MNT_ROOT}"
fi

sync
echo "[flash] done — safely remove ${DEV}"
