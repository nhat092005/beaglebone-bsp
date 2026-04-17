#!/usr/bin/env bash
# notify.sh -- Play a short beep to alert the user.
# Used by Claude Code hooks on Stop and SessionEnd events.
# Reads JSON input from stdin (required by Claude Code hook protocol).

set -euo pipefail

# Read stdin (required -- Claude Code hooks must consume stdin)
INPUT=$(cat)

# On Stop event: avoid infinite loop if another hook is active
if echo "$INPUT" | grep -q '"stop_hook_active":true'; then
  exit 0
fi

beep_once() {
  if command -v paplay &>/dev/null && [ -f /usr/share/sounds/freedesktop/stereo/message.oga ]; then
    paplay /usr/share/sounds/freedesktop/stereo/message.oga &
  elif command -v paplay &>/dev/null && [ -f /usr/share/sounds/freedesktop/stereo/bell.oga ]; then
    paplay /usr/share/sounds/freedesktop/stereo/bell.oga &
  elif command -v pw-play &>/dev/null && [ -f /usr/share/sounds/freedesktop/stereo/bell.oga ]; then
    pw-play /usr/share/sounds/freedesktop/stereo/bell.oga &
  elif command -v aplay &>/dev/null && [ -f /usr/share/sounds/alsa/Front_Center.wav ]; then
    aplay -q /usr/share/sounds/alsa/Front_Center.wav &
  elif command -v beep &>/dev/null; then
    beep -f 880 -l 300 &
  else
    printf '\a'
  fi
}

beep_once
