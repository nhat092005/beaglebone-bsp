#!/usr/bin/env bash
# notify.sh -- Beep + notification on Stop and SessionEnd.

set -euo pipefail

INPUT=$(cat)

# Avoid infinite loop on re-entry
if echo "$INPUT" | grep -q '"stop_hook_active":true'; then
  exit 0
fi

notify() {
  local title="$1" msg="$2"
  if command -v notify-send &>/dev/null; then
    notify-send "$title" "$msg" --expire-time=4000 2>/dev/null &
  fi
  echo "[BSP] $title: $msg" >&2
}

beep_once() {
  for _ in {1..3}; do
    printf '\a'
    sleep 0.2
  done
}

if echo "$INPUT" | grep -q '"stop_hook_active"'; then
  notify "Claude BSP" "Claude is waiting for your input"
else
  notify "Claude BSP" "Session has ended"
fi

beep_once
