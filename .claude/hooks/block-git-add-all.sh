#!/usr/bin/env bash
# block-git-add-all.sh -- Block dangerous git add -A / git add . commands. PreToolUse hook.

set -euo pipefail

INPUT=$(cat)

CMD=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null || echo "")

[[ -z "$CMD" ]] && exit 0

if echo "$CMD" | grep -qE '(^|[;&|]|\n)\s*git add\s+(-A|\.)\s*($|[;&|])'; then
  echo "BLOCKED: 'git add -A' or 'git add .' are forbidden in this BSP project.

Reason: these commands may accidentally stage build artifacts (zImage, *.ko, *.dtb) or sensitive files.

Allowed alternatives:
  git add -u                    (only stage tracked files that have changed)
  git add -- path/to/file.c     (specify an exact file)
  git add -- drivers/ linux/    (specify exact directories)"
  exit 2
fi
