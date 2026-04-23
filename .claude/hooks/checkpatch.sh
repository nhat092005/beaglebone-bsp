#!/usr/bin/env bash
# checkpatch.sh -- Run kernel checkpatch on .c/.h files in linux/ or drivers/. PostToolUse hook.

set -euo pipefail

INPUT=$(cat)

notify() {
  local title="$1" msg="$2"
  if command -v notify-send &>/dev/null; then
    notify-send "$title" "$msg" --expire-time=5000 2>/dev/null &
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
# Only check files under linux/ or drivers/
[[ ! "$FILE" =~ (^|/)linux/|(^|/)drivers/ ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

CHECKPATCH="linux/scripts/checkpatch.pl"
[[ ! -x "$CHECKPATCH" ]] && exit 0

RESULT=$(perl "$CHECKPATCH" --strict --no-tree -f "$FILE" 2>&1 || true)
BASENAME=$(basename "$FILE")

if echo "$RESULT" | grep -q "^ERROR:"; then
  ERROR_COUNT=$(echo "$RESULT" | grep -c "^ERROR:" || true)
  notify "Checkpatch: ERRORS" "$BASENAME — $ERROR_COUNT kernel style error(s). Run /check to see details."
  # Feed errors to Claude context
  echo "CHECKPATCH ERRORS in $FILE:"
  echo "$RESULT" | grep -E "^(ERROR|WARNING):" | head -10
elif echo "$RESULT" | grep -q "^WARNING:"; then
  WARN_COUNT=$(echo "$RESULT" | grep -c "^WARNING:" || true)
  notify "Checkpatch: Warnings" "$BASENAME — $WARN_COUNT warning(s) (non-blocking)"
else
  notify "Checkpatch: OK" "$BASENAME — style is valid"
fi
