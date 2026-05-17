#!/usr/bin/env bash
set -euo pipefail

input=$(cat)

cmd=$(
  printf '%s' "$input" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input") or {}
print(tool_input.get("command") or "")
' 2>/dev/null || true
)

if [[ -z "$cmd" ]]; then
  exit 0
fi

if printf '%s\n' "$cmd" | grep -qE '(^|[;&|]|\n)[[:space:]]*(rtk[[:space:]]+)?git[[:space:]]+add[[:space:]]+(-A|\.)[[:space:]]*($|[;&|])'; then
  cat >&2 <<'EOF'
Blocked: `git add -A` and `git add .` are forbidden in this BSP repository.

Reason: broad staging can capture build artifacts, generated images, logs, or local credentials.

Use exact staging instead:
  rtk git add -- path/to/file
  rtk git add -u
EOF
  exit 2
fi
