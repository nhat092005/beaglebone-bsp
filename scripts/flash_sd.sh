#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"

note() {
    echo "[flash] $*"
}

die() {
    echo "[flash] ERROR: $*" >&2
    exit 1
}

refuse() {
    echo "[flash] refusing: $*" >&2
    exit 1
}

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
readonly SCRIPT_DIR REPO_ROOT BUILD_DIR DEV ROOTFS

require_file() {
    local path="$1"

    [[ -f "${path}" ]] || die "${path} not found"
}

boot_artifact_path() {
    local name="$1"

    case "${name}" in
        MLO|u-boot.img) echo "${BUILD_DIR}/uboot/${name}" ;;
        zImage|*.dtb) echo "${BUILD_DIR}/kernel/${name}" ;;
        *) die "unknown boot artifact: ${name}" ;;
    esac
}

# Must start with /dev/sd — reject everything else (nvme, mmcblk, null, etc.)
if [[ "${DEV}" != /dev/sd* ]]; then
    refuse "${DEV} does not start with /dev/sd"
fi

# Refuse if device backs / or /home (check all partitions of DEV)
if grep -qE "^${DEV}[0-9]* +(/|/home) " /proc/mounts 2>/dev/null; then
    refuse "${DEV} is mounted at / or /home"
fi

# Require root
if [[ "$(id -u)" -ne 0 ]]; then
    die "must run as root"
fi

# Require block device
if [[ ! -b "${DEV}" ]]; then
    die "${DEV} is not a block device"
fi

note "target: ${DEV}"
note "WARNING: all data on ${DEV} will be erased"
read -r -p "[flash] type 'yes' to continue: " CONFIRM
[[ "${CONFIRM}" == "yes" ]] || { echo "[flash] aborted"; exit 1; }

# Unmount any existing partitions
for part in "${DEV}"?*; do
    umount "${part}" 2>/dev/null || true
done

# Partition: p1 FAT32 100 MiB with boot flag, p2 ext4 remainder
note "partitioning ${DEV}"
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

note "formatting ${P1} as FAT32"
mkfs.vfat -F 32 "${P1}"

note "formatting ${P2} as ext4"
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

copy_boot_files() {
    local name src

    note "copying boot files"
    for name in MLO u-boot.img zImage am335x-boneblack-custom.dtb; do
        src="$(boot_artifact_path "${name}")"
        require_file "${src}"
        cp "${src}" "${MNT_BOOT}/"
    done
}

write_uenv() {
    cat > "${MNT_BOOT}/uEnv.txt" <<'UENV'
bootargs=console=ttyO0,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
serverip=192.168.7.1
ipaddr=192.168.7.2
uenvcmd=run tftp_boot
UENV

    note "uEnv.txt written"
}

copy_rootfs() {
    if [[ -z "${ROOTFS}" ]]; then
        return
    fi

    require_file "${ROOTFS}"
    note "extracting rootfs"
    tar -xf "${ROOTFS}" -C "${MNT_ROOT}"
}

copy_boot_files

write_uenv

copy_rootfs

sync
note "done — safely remove ${DEV}"
