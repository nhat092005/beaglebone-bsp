#!/usr/bin/env bash
# Verification script for Opus 4.7 critical issues fixes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

PASS=0
FAIL=0

check() {
    local desc="$1"
    local file="$2"
    local pattern="$3"
    local expected="$4"
    
    echo -n "Checking: ${desc}... "
    
    if grep -q "${pattern}" "${file}"; then
        local actual=$(grep "${pattern}" "${file}" | head -1)
        if echo "${actual}" | grep -q "${expected}"; then
            echo "✅ PASS"
            ((PASS++))
        else
            echo "❌ FAIL"
            echo "  Expected: ${expected}"
            echo "  Actual:   ${actual}"
            ((FAIL++))
        fi
    else
        echo "❌ FAIL (pattern not found)"
        ((FAIL++))
    fi
}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  BeagleBone BSP - Critical Issues Verification                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Issue #1: U-Boot defconfig"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check "U-Boot uses custom defconfig" \
    "scripts/build.sh" \
    "make CROSS_COMPILE.*defconfig" \
    "am335x_boneblack_custom_defconfig"
echo ""

echo "Issue #2: Kernel DTB in build.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check "Kernel build copies custom DTB" \
    "scripts/build.sh" \
    "cp arch/arm/boot/dts/am335x-boneblack.*\.dtb" \
    "am335x-boneblack-custom.dtb"
echo ""

echo "Issue #3: DTB in flash_sd.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check "Flash script uses custom DTB in file list" \
    "scripts/flash_sd.sh" \
    "for f in MLO.*am335x-boneblack.*\.dtb" \
    "am335x-boneblack-custom.dtb"

check "Flash script uses custom DTB in uEnv.txt" \
    "scripts/flash_sd.sh" \
    "uenvcmd=.*am335x-boneblack.*\.dtb" \
    "am335x-boneblack-custom.dtb"
echo ""

echo "Issue #4: Yocto layer.conf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check "Yocto layer priority is 10" \
    "meta-bbb/conf/layer.conf" \
    "BBFILE_PRIORITY_meta-bbb" \
    '"10"'

check "Yocto layer compat is kirkstone" \
    "meta-bbb/conf/layer.conf" \
    "LAYERSERIES_COMPAT_meta-bbb" \
    '"kirkstone"'
echo ""

echo "Cross-file Consistency"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check "deploy.sh uses custom DTB" \
    "scripts/deploy.sh" \
    "am335x-boneblack.*\.dtb" \
    "am335x-boneblack-custom.dtb"
echo ""

echo "File Existence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f "u-boot/configs/am335x_boneblack_custom_defconfig" ]]; then
    echo "✅ PASS: am335x_boneblack_custom_defconfig exists"
    ((PASS++))
else
    echo "❌ FAIL: am335x_boneblack_custom_defconfig not found"
    ((FAIL++))
fi

if [[ -f "linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb" ]]; then
    echo "✅ PASS: am335x-boneblack-custom.dtb exists"
    ((PASS++))
else
    echo "❌ FAIL: am335x-boneblack-custom.dtb not found"
    ((FAIL++))
fi
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                         SUMMARY                                ║"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  Total Tests: %-3d                                             ║\n" $((PASS + FAIL))
printf "║  Passed:      %-3d ✅                                          ║\n" ${PASS}
printf "║  Failed:      %-3d ❌                                          ║\n" ${FAIL}
echo "╚════════════════════════════════════════════════════════════════╝"

if [[ ${FAIL} -eq 0 ]]; then
    echo ""
    echo "🎉 All critical issues have been fixed!"
    exit 0
else
    echo ""
    echo "⚠️  Some issues remain. Please review the failures above."
    exit 1
fi
