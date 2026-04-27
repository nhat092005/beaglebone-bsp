#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LINUX_DIR="${REPO_ROOT}/linux"
OBJ_DIR="${REPO_ROOT}/build/linux/dev"
KERNEL_OUT="${REPO_ROOT}/build/kernel"
ARCH="${ARCH:-arm}"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
EXPECTED_DTB="am335x-boneblack-custom.dtb"
readonly SCRIPT_DIR REPO_ROOT LINUX_DIR OBJ_DIR KERNEL_OUT ARCH CROSS_COMPILE EXPECTED_DTB

DTBS_LOG=""
W1_LOG=""

fail() {
    echo "[kernel-verify] ERROR: $*" >&2
    exit 1
}

cleanup() {
    rm -f "${DTBS_LOG}" "${W1_LOG}"
}

trap cleanup EXIT

note() {
    echo "[kernel-verify] $*"
}

kernel_make() {
    make -C "${LINUX_DIR}" O="${OBJ_DIR}" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "$@"
}

require_file() {
    local path="$1"

    [[ -f "${path}" ]] || fail "missing ${path}"
}

require_config_line() {
    local pattern="$1"
    local message="$2"

    grep -qx "${pattern}" "${OBJ_DIR}/.config" || fail "${message}"
}

read_make_var() {
    local name="$1"

    sed -n "s/^${name} = //p" "${LINUX_DIR}/Makefile"
}

check_kernel_version() {
    local version patchlevel sublevel extraversion kernel_version

    version="$(read_make_var VERSION)"
    patchlevel="$(read_make_var PATCHLEVEL)"
    sublevel="$(read_make_var SUBLEVEL)"
    extraversion="$(read_make_var EXTRAVERSION)"
    kernel_version="${version}.${patchlevel}.${sublevel}${extraversion}"

    note "kernel version: ${kernel_version}"
    [[ "${kernel_version}" =~ ^5\.10\.[0-9]+.*$ ]] || \
        fail "expected linux/Makefile version 5.10.<N>, got ${kernel_version}"
    [[ "${sublevel}" != "0" ]] || fail "SUBLEVEL must not be 0"
}

check_kernel_tag() {
    local tag

    if ! git -C "${LINUX_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return
    fi

    tag="$(git -C "${LINUX_DIR}" describe --tags --exact-match HEAD 2>/dev/null || true)"
    if [[ -n "${tag}" ]]; then
        note "kernel tag: ${tag}"
        return
    fi

    note "WARN: kernel HEAD is not exactly on a tag" >&2
}

check_config() {
    require_file "${OBJ_DIR}/.config"
    require_config_line 'CONFIG_LOCALVERSION="-bbb-custom"' \
        "${OBJ_DIR}/.config missing CONFIG_LOCALVERSION=\"-bbb-custom\"; rebuild with KERNEL_RECONFIGURE=1"
    require_config_line '# CONFIG_LOCALVERSION_AUTO is not set' \
        "${OBJ_DIR}/.config must disable CONFIG_LOCALVERSION_AUTO for stable uname -r"
}

check_kernel_release() {
    local kernel_release

    kernel_release="$(kernel_make -s kernelrelease)"
    note "kernel release: ${kernel_release}"
    [[ "${kernel_release}" =~ ^5\.10\.[0-9]+-bbb-custom\+$ ]] || \
        fail "expected kernel release 5.10.<N>-bbb-custom+, got ${kernel_release}"
}

check_artifacts() {
    local zimage_size dtb_size

    require_file "${KERNEL_OUT}/zImage"
    require_file "${KERNEL_OUT}/${EXPECTED_DTB}"

    zimage_size="$(stat -c '%s' "${KERNEL_OUT}/zImage")"
    dtb_size="$(stat -c '%s' "${KERNEL_OUT}/${EXPECTED_DTB}")"

    note "zImage size: ${zimage_size}"
    note "${EXPECTED_DTB} size: ${dtb_size}"

    (( zimage_size >= 4194304 )) || fail "zImage too small: ${zimage_size}"
    (( dtb_size > 0 )) || fail "DTB is empty"
}

check_dtbs_schema() {
    note "running dtbs_check for ${EXPECTED_DTB}"
    DTBS_LOG="$(mktemp)"

    kernel_make CHECK_DTBS=y \
        DT_SCHEMA_FILES=Documentation/devicetree/bindings/ \
        "${EXPECTED_DTB}" >"${DTBS_LOG}" 2>&1

    if grep -E 'am335x-boneblack-custom.*(error|warning)' "${DTBS_LOG}"; then
        fail "dtbs_check reported errors/warnings for custom DTS"
    fi

    note "dtbs_check custom errors/warnings: 0"
}

check_w1_dtbs() {
    local custom_warning_count

    note "running W=1 dtbs"
    W1_LOG="$(mktemp)"

    kernel_make W=1 dtbs >"${W1_LOG}" 2>&1
    custom_warning_count="$(grep -c 'am335x-boneblack-custom.*warning' "${W1_LOG}" || true)"

    note "custom W=1 warning count: ${custom_warning_count}"
    [[ "${custom_warning_count}" == "0" ]] || fail "custom DTS introduced W=1 warnings"
}

main() {
    check_kernel_version
    check_kernel_tag
    check_config
    check_kernel_release
    check_artifacts
    check_dtbs_schema
    check_w1_dtbs

    note "PASS: host-side Phase 3 kernel/DTS gates passed"
    note "NOTE: bootz, dmesg, and target uname -r still require BBB hardware"
}

main "$@"
