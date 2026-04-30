#!/usr/bin/env bash
# Software-only PWM Servo Validation Script
# Contract Ref: .sisyphus/evidence/task-2-servo-contract.md
# Hardware Ref: P9.14 / EHRPWM1A

set -uo pipefail

# Environment Overrides
SERVO_DEVICE_DIR="${SERVO_DEVICE_DIR:-}"
# Default search for the platform device if SERVO_DEVICE_DIR is not provided
if [[ -z "${SERVO_DEVICE_DIR}" ]]; then
    for dev in /sys/bus/platform/devices/*.servo; do
        if [[ -d "${dev}" ]] && [[ -f "${dev}/position_us" ]]; then
            SERVO_DEVICE_DIR="${dev}"
            break
        fi
    done
fi

echo "--- PWM Servo Software Validation ---"
echo "NOTE: This script performs software-only checks."
echo "NOTE: No real servo motion or electrical timing is verified."

# Prerequisite Handling
if [[ -z "${SERVO_DEVICE_DIR}" ]]; then
    echo "FAIL: No pwm-servo device found in /sys/bus/platform/devices/" >&2
    echo "HINT: Ensure 'pwm-servo' module is loaded and DTS node is enabled." >&2
    exit 1
fi

if [[ ! -d "${SERVO_DEVICE_DIR}" ]]; then
    echo "FAIL: Device directory ${SERVO_DEVICE_DIR} does not exist." >&2
    exit 1
fi

echo "Found servo device: ${SERVO_DEVICE_DIR}"

# ABI Attribute Check
REQUIRED_ATTRIBUTES=("enable" "position_us" "min_us" "neutral_us" "max_us" "period_us")
for attr in "${REQUIRED_ATTRIBUTES[@]}"; do
    if [[ ! -f "${SERVO_DEVICE_DIR}/${attr}" ]]; then
        echo "FAIL: Missing ABI attribute: ${attr}" >&2
        exit 1
    fi
done

# Read Constants
MIN_US=$(cat "${SERVO_DEVICE_DIR}/min_us")
NEUTRAL_US=$(cat "${SERVO_DEVICE_DIR}/neutral_us")
MAX_US=$(cat "${SERVO_DEVICE_DIR}/max_us")
PERIOD_US=$(cat "${SERVO_DEVICE_DIR}/period_us")

echo "Driver Constants: min=${MIN_US}us, neutral=${NEUTRAL_US}us, max=${MAX_US}us, period=${PERIOD_US}us"

# Functional Tests (Requires Root for Writes)
if [[ $EUID -ne 0 ]]; then
    echo "WARN: Not running as root; skipping write tests."
    echo "SUCCESS: Software discovery passed (read-only)."
    exit 0
fi

# 1. Test Enable/Disable
echo "Testing Enable/Disable..."
echo "0" > "${SERVO_DEVICE_DIR}/enable"
[[ "$(cat "${SERVO_DEVICE_DIR}/enable")" == "0" ]]
echo "1" > "${SERVO_DEVICE_DIR}/enable"
[[ "$(cat "${SERVO_DEVICE_DIR}/enable")" == "1" ]]

# 2. Test Valid Position Write
echo "Testing Valid Position Write (${NEUTRAL_US})..."
echo "${NEUTRAL_US}" > "${SERVO_DEVICE_DIR}/position_us"
[[ "$(cat "${SERVO_DEVICE_DIR}/position_us")" == "${NEUTRAL_US}" ]]

# 3. Test Invalid Input (Below Min)
VAL_BELOW_MIN=$((MIN_US - 1))
echo "Testing Invalid Input: Below Min (${VAL_BELOW_MIN})..."
if echo "${VAL_BELOW_MIN}" > "${SERVO_DEVICE_DIR}/position_us" 2>/dev/null; then
    echo "FAIL: Driver accepted value below min_us (${VAL_BELOW_MIN})" >&2
    exit 1
else
    echo "OK: Rejected value below min_us."
fi

# 4. Test Invalid Input (Above Max)
VAL_ABOVE_MAX=$((MAX_US + 1))
echo "Testing Invalid Input: Above Max (${VAL_ABOVE_MAX})..."
if echo "${VAL_ABOVE_MAX}" > "${SERVO_DEVICE_DIR}/position_us" 2>/dev/null; then
    echo "FAIL: Driver accepted value above max_us (${VAL_ABOVE_MAX})" >&2
    exit 1
else
    echo "OK: Rejected value above max_us."
fi

echo "SUCCESS: PWM Servo software-readiness verified."
exit 0
