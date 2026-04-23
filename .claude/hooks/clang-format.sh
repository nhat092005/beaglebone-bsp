#!/usr/bin/env bash
# clang-format.sh -- Auto-format .c/.h files after Write/Edit. PostToolUse hook.

set -euo pipefail

INPUT=$(cat)

notify() {
  local title="$1" msg="$2"
  if command -v notify-send &>/dev/null; then
    notify-send "$title" "$msg" --expire-time=3000 2>/dev/null &
  fi
  echo "[BSP] $title: $msg" >&2
}

FILE=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null || echo "")

[[ -z "$FILE" ]] && exit 0
[[ ! "$FILE" =~ \.(c|h)$ ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

if ! command -v clang-format &>/dev/null; then
  notify "Format skipped" "clang-format is not installed"
  exit 0
fi

clang-format -i "$FILE"
notify "Format successful" "Automatically formatted: $(basename "$FILE")"
