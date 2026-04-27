#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"

DOCKER_IMAGE="${DOCKER_IMAGE:-${IMAGE:-bbb-builder}}"
REPRODUCIBLE_BUILD="${REPRODUCIBLE_BUILD:-0}"
KERNEL_BUILD_MODE="${KERNEL_BUILD_MODE:-dev}"
KERNEL_JOBS="${KERNEL_JOBS:-$(nproc)}"
KERNEL_DTB="am335x-boneblack-custom.dtb"

note() {
    echo "[build] $*"
}

warn() {
    echo "[build] WARN: $*" >&2
}

die() {
    echo "[build] ERROR: $*" >&2
    exit 1
}

run_in_container() {
    exec docker run --rm \
        -v "${REPO_ROOT}:/workspace" \
        -w /workspace \
        -e "ARCH=${ARCH:-arm}" \
        -e "CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabihf-}" \
        -e "KERNEL_BUILD_MODE=${KERNEL_BUILD_MODE}" \
        -e "KERNEL_DEV_DEBUG=${KERNEL_DEV_DEBUG:-1}" \
        -e "KERNEL_JOBS=${KERNEL_JOBS}" \
        -e "KERNEL_RECONFIGURE=${KERNEL_RECONFIGURE:-0}" \
        -e "REPRODUCIBLE_BUILD=${REPRODUCIBLE_BUILD}" \
        "${DOCKER_IMAGE}" \
        bash scripts/build.sh "$@"
}

# If not inside a container, re-exec inside one.
if [[ ! -f /.dockerenv ]]; then
    run_in_container "$@"
fi

# Inside container from here
REPO_ROOT=/workspace
BUILD_DIR="${REPO_ROOT}/build"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
ARCH="${ARCH:-arm}"
KERNEL_DIR="${REPO_ROOT}/linux"
UBOOT_DIR="${REPO_ROOT}/u-boot"
readonly REPO_ROOT BUILD_DIR CROSS_COMPILE ARCH KERNEL_DIR UBOOT_DIR KERNEL_DTB

usage() {
    echo "Usage: $0 <target> [args]"
    echo ""
    echo "Targets:"
    echo "  kernel [mode]          Build Linux kernel; mode: dev or reproducible"
    echo "  kernel-dev             Build Linux kernel for fast development"
    echo "  kernel-reproducible    Build Linux kernel with reproducible settings"
    echo "  uboot                  Build U-Boot (MLO + u-boot.img)"
    echo "  driver <name>          Build out-of-tree driver from drivers/<name>/"
    echo "  all                    Build kernel + uboot + all drivers"
    echo ""
    echo "Environment:"
    echo "  KERNEL_BUILD_MODE=dev|reproducible"
    echo "  KERNEL_JOBS=<n>         Parallel kernel build jobs (default: nproc)"
    echo "  KERNEL_RECONFIGURE=1    Regenerate dev .config before building"
    echo "  KERNEL_DEV_DEBUG=0      Skip dev-mode debug symbol enablement"
    echo "  REPRODUCIBLE_BUILD=1    Legacy alias for KERNEL_BUILD_MODE=reproducible"
    exit 1
}

is_enabled() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

resolve_kernel_mode() {
    local mode="${1:-${KERNEL_BUILD_MODE}}"

    if is_enabled "${REPRODUCIBLE_BUILD}"; then
        mode="reproducible"
    fi

    case "${mode,,}" in
        dev|development) echo "dev" ;;
        repro|reproducible) echo "reproducible" ;;
        *) die "unknown kernel build mode: ${mode} (expected: dev or reproducible)" ;;
    esac
}

kernel_make() {
    local obj_dir="$1"
    shift

    make O="${obj_dir}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "$@"
}

kernel_export_reproducible_env() {
    local source_date_epoch
    local build_timestamp

    source_date_epoch="$(git -C "${KERNEL_DIR}" log -1 --format=%ct 2>/dev/null || true)"
    if [[ -z "${source_date_epoch}" ]]; then
        source_date_epoch="0"
        warn "could not read kernel git commit time; using epoch 0"
    fi
    build_timestamp="$(date -u -d "@${source_date_epoch}" "+%Y-%m-%d %H:%M:%S")"

    export KBUILD_BUILD_USER="builder"
    export KBUILD_BUILD_HOST="bsp-build"
    export KBUILD_BUILD_VERSION="1"
    export KCONFIG_NOTIMESTAMP="1"
    export LC_ALL="C"
    export SOURCE_DATE_EPOCH="${source_date_epoch}"
    export KBUILD_BUILD_TIMESTAMP="${build_timestamp}"
}

kernel_merge_fragment() {
    local obj_dir="$1"
    local fragment="$2"

    if [[ -f "${fragment}" ]]; then
        ./scripts/kconfig/merge_config.sh -O "${obj_dir}" -m \
            "${obj_dir}/.config" "${fragment}"
    fi
}

kernel_configure_base() {
    local obj_dir="$1"

    kernel_make "${obj_dir}" omap2plus_defconfig
    kernel_merge_fragment "${obj_dir}" "${REPO_ROOT}/linux/configs/boneblack-custom.config"
    touch "${obj_dir}/.bsp-configured"
}

kernel_config_needs_refresh() {
    local obj_dir="$1"

    [[ ! -f "${obj_dir}/.config" ]] ||
        [[ ! -f "${obj_dir}/.bsp-configured" ]] ||
        is_enabled "${KERNEL_RECONFIGURE:-0}"
}

kernel_source_has_in_tree_artifacts() {
    [[ -f "${KERNEL_DIR}/.config" ]] ||
        [[ -d "${KERNEL_DIR}/include/config" ]] ||
        [[ -d "${KERNEL_DIR}/arch/${ARCH}/include/generated" ]]
}

kernel_prepare_source_tree() {
    if kernel_source_has_in_tree_artifacts; then
        note "kernel source has in-tree build artifacts; running mrproper"
        make -C "${KERNEL_DIR}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper
    fi
}

kernel_dtb_path() {
    local obj_dir="$1"

    echo "${obj_dir}/arch/arm/boot/dts/${KERNEL_DTB}"
}

kernel_copy_artifacts() {
    local obj_dir="$1"
    local label="$2"
    local out="${BUILD_DIR}/kernel"

    mkdir -p "${out}"
    cp "${obj_dir}/arch/arm/boot/zImage" "${out}/"
    cp "$(kernel_dtb_path "${obj_dir}")" "${out}/"
    note "kernel ${label} done -> ${out}/"
}

build_kernel_dev() {
    local obj_dir="${BUILD_DIR}/linux/dev"

    mkdir -p "${obj_dir}"
    note "kernel dev"
    kernel_prepare_source_tree
    cd "${KERNEL_DIR}"

    if kernel_config_needs_refresh "${obj_dir}"; then
        kernel_configure_base "${obj_dir}"
        if is_enabled "${KERNEL_DEV_DEBUG:-1}"; then
            ./scripts/config --file "${obj_dir}/.config" \
                --enable DEBUG_INFO \
                --disable DEBUG_INFO_REDUCED \
                --disable DEBUG_INFO_SPLIT
        fi
        kernel_make "${obj_dir}" olddefconfig
    fi

    kernel_make "${obj_dir}" -j"${KERNEL_JOBS}" zImage dtbs modules
    kernel_copy_artifacts "${obj_dir}" "dev"
}

build_kernel_reproducible() {
    local obj_dir="${BUILD_DIR}/linux/reproducible"

    rm -rf "${obj_dir}"
    mkdir -p "${obj_dir}"
    note "kernel reproducible"
    kernel_prepare_source_tree
    kernel_export_reproducible_env
    cd "${KERNEL_DIR}"

    kernel_configure_base "${obj_dir}"
    kernel_merge_fragment "${obj_dir}" "${REPO_ROOT}/linux/configs/reproducible.config"
    kernel_make "${obj_dir}" olddefconfig
    kernel_make "${obj_dir}" -j"${KERNEL_JOBS}" zImage dtbs modules
    kernel_copy_artifacts "${obj_dir}" "reproducible"
}

build_kernel() {
    case "$(resolve_kernel_mode "${1:-}")" in
        dev) build_kernel_dev ;;
        reproducible) build_kernel_reproducible ;;
    esac
}

build_uboot() {
    local out="${BUILD_DIR}/uboot"

    mkdir -p "${out}"
    note "uboot"
    cd "${UBOOT_DIR}"
    make CROSS_COMPILE="${CROSS_COMPILE}" am335x_boneblack_custom_defconfig
    make CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)"
    if [[ ! -f MLO || ! -f u-boot.img ]]; then
        die "MLO or u-boot.img not produced"
    fi
    cp MLO u-boot.img "${out}/"
    note "uboot done -> ${out}/"
}

build_driver() {
    local name="${1:?driver name required}"
    local driver_dir="${REPO_ROOT}/drivers/${name}"
    local out

    if [[ ! -d "${driver_dir}" ]]; then
        die "drivers/${name}/ not found"
    fi
    out="${BUILD_DIR}/drivers/${name}"
    mkdir -p "${out}"
    note "driver ${name}"
    make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KERNEL_DIR="${KERNEL_DIR}" -C "${driver_dir}"
    find "${driver_dir}" -name "*.ko" -exec cp {} "${out}/" \;
    note "driver ${name} done -> ${out}/"
}

build_all() {
    build_kernel "${KERNEL_BUILD_MODE}"
    build_uboot
    for driver_dir in "${REPO_ROOT}"/drivers/*/; do
        [[ -d "${driver_dir}" ]] || continue
        build_driver "$(basename "${driver_dir}")"
    done
}

main() {
    [[ $# -ge 1 ]] || usage

    case "$1" in
        kernel)
            build_kernel "${2:-}"
            ;;
        kernel-dev) build_kernel_dev ;;
        kernel-reproducible) build_kernel_reproducible ;;
        uboot)  build_uboot ;;
        driver)
            [[ $# -ge 2 ]] || usage
            build_driver "$2"
            ;;
        all)    build_all ;;
        *)      usage ;;
    esac
}

main "$@"
