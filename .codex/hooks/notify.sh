#!/usr/bin/env bash
set -euo pipefail

if [[ "${BSP_CODEX_NOTIFY_ACTIVE:-0}" == "1" ]]; then
  exit 0
fi

title="Codex"
msg="Turn complete in beaglebone-bsp"

if command -v notify-send >/dev/null 2>&1; then
  BSP_CODEX_NOTIFY_ACTIVE=1 notify-send "$title" "$msg" --expire-time=3000 >/dev/null 2>&1 || true
fi

printf '\a' 2>/dev/null || true
