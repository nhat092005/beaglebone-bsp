---
name: bsp-debug-board
description: Use for the BeagleBone live UART debug workflow that replaced the old debug-board slash command.
---

This is a skill workflow, not a Codex custom slash command.

Before hardware access, get explicit user approval and run preflight:

```bash
ls /dev/ttyUSB0
groups | tr ' ' '\n' | grep -xq dialout
python3 -c "import serial, yaml"
test -f scripts/debug/error-patterns.yaml
test -x scripts/debug/bbb-uart.py
```

Flow:

1. Capture boot or replay fixture with `scripts/debug/bbb-uart.py`.
2. Scan logs using `scripts/debug/error-patterns.yaml`.
3. Form hypotheses from concrete log evidence.
4. Run bounded `send` probes only when needed.
5. Write a report under `vault/wiki/debugging/reports/` when requested.

Keep every command and artifact path in the final report.
