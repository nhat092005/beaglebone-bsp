#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
DOCKER_IMAGE="${DOCKER_IMAGE:-beaglebone-bsp-builder:1.0}"

# If not inside a container, re-exec inside one.
if [[ ! -f /.dockerenv ]]; then
    exec docker run --rm \
        -v "${REPO_ROOT}:/workspace" \
        -w /workspace \
        "${DOCKER_IMAGE}" \
        bash scripts/build.sh "$@"
fi

# Inside container from here
REPO_ROOT=/workspace
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
    local out="${BUILD_DIR}/kernel"
    mkdir -p "${out}"
    echo "[build] kernel"
    cd "${KERNEL_DIR}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_defconfig
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" zImage dtbs modules
    cp arch/arm/boot/zImage "${out}/"
    cp arch/arm/boot/dts/am335x-boneblack-custom.dtb "${out}/"
    echo "[build] kernel done → ${out}/"
}

build_uboot() {
    local out="${BUILD_DIR}/uboot"
    mkdir -p "${out}"
    echo "[build] uboot"
    cd "${UBOOT_DIR}"
    make CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_custom_defconfig
    make CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)"
    if [[ ! -f MLO || ! -f u-boot.img ]]; then
        echo "[build] ERROR: MLO or u-boot.img not produced" >&2
        exit 1
    fi
    cp MLO u-boot.img "${out}/"
    echo "[build] uboot done → ${out}/"
}

build_driver() {
    local name="${1:?driver name required}"
    local driver_dir="${REPO_ROOT}/drivers/${name}"
    if [[ ! -d "${driver_dir}" ]]; then
        echo "[build] ERROR: drivers/${name}/ not found" >&2
        exit 1
    fi
    local out="${BUILD_DIR}/drivers/${name}"
    mkdir -p "${out}"
    echo "[build] driver ${name}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KERNEL_DIR="${KERNEL_DIR}" -C "${driver_dir}"
    find "${driver_dir}" -name "*.ko" -exec cp {} "${out}/" \;
    echo "[build] driver ${name} done → ${out}/"
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
