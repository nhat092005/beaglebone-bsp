#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"

HOST="192.168.7.2"
DO_KERNEL=0
DO_DTB=0
DO_MODULES=0

usage() {
    echo "Usage: $0 [--host <ip>] [--kernel] [--dtb] [--modules]"
    echo ""
    echo "Options:"
    echo "  --host <ip>   Board IP address (default: 192.168.7.2)"
    echo "  --kernel      Copy zImage to /boot/ on board"
    echo "  --dtb         Copy am335x-boneblack.dtb to /boot/ on board"
    echo "  --modules     Copy kernel modules, run depmod -a on board"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)    HOST="${2:?missing IP}"; shift 2 ;;
        --kernel)  DO_KERNEL=1; shift ;;
        --dtb)     DO_DTB=1; shift ;;
        --modules) DO_MODULES=1; shift ;;
        *)         usage ;;
    esac
done

if [[ $((DO_KERNEL + DO_DTB + DO_MODULES)) -eq 0 ]]; then
    usage
fi

echo "[deploy] checking board at ${HOST}"
ping -c1 -W2 "${HOST}" > /dev/null 2>&1 || {
    echo "[deploy] ERROR: board unreachable at ${HOST}" >&2
    exit 1
}
echo "[deploy] board reachable"

if [[ "${DO_KERNEL}" -eq 1 ]]; then
    echo "[deploy] copying zImage"
    scp "${BUILD_DIR}/zImage" "root@${HOST}:/boot/"
fi

if [[ "${DO_DTB}" -eq 1 ]]; then
    echo "[deploy] copying am335x-boneblack.dtb"
    scp "${BUILD_DIR}/am335x-boneblack.dtb" "root@${HOST}:/boot/"
fi

if [[ "${DO_MODULES}" -eq 1 ]]; then
    echo "[deploy] copying modules"
    scp "${BUILD_DIR}"/*.ko "root@${HOST}:/lib/modules/"
    ssh "root@${HOST}" depmod -a
fi

echo "[deploy] done"
