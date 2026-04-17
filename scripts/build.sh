#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
ARCH="${ARCH:-arm}"
KERNEL_DIR="${REPO_ROOT}/linux"
UBOOT_DIR="${REPO_ROOT}/u-boot"

usage() {
    echo "Usage: $0 <target> [args]"
    echo ""
    echo "Targets:"
    echo "  kernel          Build Linux kernel (zImage + dtbs + modules)"
    echo "  uboot           Build U-Boot (MLO + u-boot.img)"
    echo "  driver <name>   Build out-of-tree driver from drivers/<name>/"
    echo "  all             Build kernel + uboot + all drivers"
    exit 1
}

build_kernel() {
    echo "[build] kernel"
    cd "${KERNEL_DIR}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_defconfig
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" zImage dtbs modules
    mkdir -p "${BUILD_DIR}"
    cp arch/arm/boot/zImage "${BUILD_DIR}/"
    cp arch/arm/boot/dts/am335x-boneblack.dtb "${BUILD_DIR}/"
    echo "[build] kernel done"
}

build_uboot() {
    echo "[build] uboot"
    cd "${UBOOT_DIR}"
    make CROSS_COMPILE="${CROSS_COMPILE}" am335x_evm_defconfig
    make CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)"
    if [[ ! -f MLO || ! -f u-boot.img ]]; then
        echo "[build] ERROR: MLO or u-boot.img not produced" >&2
        exit 1
    fi
    mkdir -p "${BUILD_DIR}"
    cp MLO u-boot.img "${BUILD_DIR}/"
    echo "[build] uboot done"
}

build_driver() {
    local name="${1:?driver name required}"
    local driver_dir="${REPO_ROOT}/drivers/${name}"
    if [[ ! -d "${driver_dir}" ]]; then
        echo "[build] ERROR: drivers/${name}/ not found" >&2
        exit 1
    fi
    echo "[build] driver ${name}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KERNEL_DIR="${KERNEL_DIR}" -C "${driver_dir}"
    mkdir -p "${BUILD_DIR}"
    find "${driver_dir}" -name "*.ko" -exec cp {} "${BUILD_DIR}/" \;
    echo "[build] driver ${name} done"
}

build_all() {
    build_kernel
    build_uboot
    for driver_dir in "${REPO_ROOT}"/drivers/*/; do
        [[ -d "${driver_dir}" ]] || continue
        build_driver "$(basename "${driver_dir}")"
    done
}

if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    kernel) build_kernel ;;
    uboot)  build_uboot ;;
    driver)
        [[ $# -ge 2 ]] || usage
        build_driver "$2"
        ;;
    all)    build_all ;;
    *)      usage ;;
esac
