#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
TFTP_DIR="${TFTP_DIR:-/srv/tftp}"
DRY_RUN=0
readonly SCRIPT_DIR REPO_ROOT BUILD_DIR TFTP_DIR

note() {
    echo "[deploy] $*"
}

die() {
    echo "[deploy] ERROR: $*" >&2
    exit 1
}

usage() {
    echo "Usage: [TFTP_DIR=<path>] $0 [--dry-run]"
    echo ""
    echo "  --dry-run   Print copy commands without executing"
    echo ""
    echo "Copies zImage and am335x-boneblack-custom.dtb to TFTP_DIR (default: /srv/tftp)."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        *) usage ;;
    esac
done

tftp_deploy() {
    local src="$1"
    local dest

    dest="${TFTP_DIR}/$(basename "${src}")"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "cp ${src} ${dest}"
        return
    fi

    [[ -f "${src}" ]] || die "${src} not found"
    cp "${src}" "${dest}"
    note "copied $(basename "${src}")"
}

main() {
    tftp_deploy "${BUILD_DIR}/kernel/zImage"
    tftp_deploy "${BUILD_DIR}/kernel/am335x-boneblack-custom.dtb"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
        note "done — TFTP_DIR: ${TFTP_DIR}"
    fi
}

main "$@"
