---
description: Drive BeagleBone over UART — capture boot, run diagnostic commands, analyze errors, write AI-authored report to vault/wiki/debugging/reports/.
---

# Debug Board — live UART pipeline

Spawns the `board-runner` subagent to drive a BeagleBone Black over the host serial console, capture a boot log, run targeted diagnostic commands, and emit a structured debug report into the project vault.

**Input**: `$ARGUMENTS` — required `<tag>` (short name for the session, used in the report filename), optional `<focus>` (hypothesis hint, e.g. `"i2c bus 1"` or `"probe defer"`), optional `--replay <logfile>` (fixture mode — skip live UART, analyze an existing log).

---

## Phase 1 — Preflight

Before spawning the subagent, confirm live-debug prerequisites (skip if `--replay` was passed):

```bash
ls /dev/ttyUSB0 || { echo "fatal: /dev/ttyUSB0 not present — connect FTDI cable"; exit 1; }
groups | tr ' ' '\n' | grep -xq dialout || { echo "fatal: user not in dialout group — run 'sudo usermod -a -G dialout $USER' then re-login"; exit 1; }
python3 -c "import serial, yaml" 2>&1 || { echo "fatal: missing deps — run 'pip install -r scripts/requirements-debug.txt'"; exit 1; }
test -f config/error-patterns.yaml || { echo "fatal: error-patterns.yaml missing"; exit 1; }
test -x scripts/bbb-uart.py || { echo "fatal: scripts/bbb-uart.py missing or not executable"; exit 1; }
```

If any check fails, stop and report the failing command to the user. Do not proceed.

## Phase 2 — Spawn board-runner

Invoke the `board-runner` subagent via the `Agent` tool with the following context:

- `subagent_type`: `board-runner`
- `description`: `Drive BBB for <tag>` (one line)
- `prompt`: include
  - The raw `$ARGUMENTS` string (tag + optional focus + optional `--replay <logfile>`).
  - A reminder of its contract: capture → analyze → probe → report to `vault/wiki/debugging/reports/$(date -I)-<tag>.md`, then hand off to `doc-updater`.
  - The resolved boot-log path (`/tmp/bbb-<tag>-<epoch>.log`) so it uses consistent filenames.
  - The current date (`$(date -I)`) for the report filename.

The subagent owns the full ReAct loop (Phases 1–6 in its spec). Do not micromanage — let it decide which commands to run.

## Phase 3 — Report the path to the user

When the subagent returns, read its final message for the report path. Verify the file exists:

```bash
REPORT="vault/wiki/debugging/reports/$(date -I)-<tag>.md"
test -s "$REPORT" || { echo "warning: report file missing or empty"; exit 2; }
head -20 "$REPORT"
echo "---"
echo "Full report: $REPORT"
```

Print the path to the user. Do not edit the report yourself — it is the subagent's artifact.

## Phase 4 — No fixes

You MUST NOT apply any fix suggested in the report. The user reviews and decides. If the user asks you to apply a fix afterward, that is a separate request requiring the standard `/plan` → `/sdd` flow.

---

## Examples

**Smoke test**

```
/debug-board smoke-test
```

Boots a board with no known issue. Expected report: 0 errors or only `info`-severity `probe_defer` hits.

**Focused I2C diagnosis**

```
/debug-board i2c-fault "i2c bus 1 TMP102 at 0x48"
```

Subagent runs `i2cdetect -y 1`, checks DT status, reviews clock tree for i2c1.

**Fixture replay (no hardware)**

```
/debug-board ci-replay --replay tests/fixtures/boot-log-i2c-error.log
```

Skips UART; analyzer runs against captured log. Useful for CI and iterating on the pattern DB.

---

## Related

- Agent: `agents/board-runner.md` — the subagent this command spawns.
- Agent: `agents/debugger.md` — use directly for post-mortem analysis without live UART.
- Agent: `agents/doc-updater.md` — invoked by board-runner after report write.
- Skill: `skills/bsp-debugging/SKILL.md` — command reference.
- Doc: `docs/09-debug-agent.md` — architecture + limits.
