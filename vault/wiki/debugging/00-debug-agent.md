---
title: UART Debug Agent
last_updated: 2026-04-26
category: debugging
---

# BeagleBone UART Debug Agent - Technical Reference

> **Diataxis type:** explanation + how-to hybrid — shows how the `/debug-board`
> pipeline is wired and how to run or extend it.

This document covers the architecture, execution path, usage, and known limits
of the automated UART debug pipeline introduced in TODO Phase 10. It is the
reference companion to `.claude/agents/board-runner.md`, `.claude/commands/debug-board.md`,
and `scripts/bbb-uart.py`.

---

## Context

### Problem

Manual BBB debug flow before Phase 10:

1. Open `minicom -D /dev/ttyUSB0 -b 115200`
2. Press reset, watch boot scroll
3. Copy-paste log into a chat / file
4. Ask an agent to analyze
5. Manually run `i2cdetect`, `dmesg | grep`, etc. and paste output back

Slow. Not recorded. Evidence chain fragmented. Boot log capture depends on
human reaction time ("did I scroll fast enough?"). Every debug session is
re-discovered from scratch.

### Goal

`/debug-board <tag>` drives the board end-to-end: UART connect → boot capture →
targeted commands → regex + LLM analysis → AI-authored report written to
`vault/wiki/debugging/reports/`. Every session is recorded, indexed, and
reproducible (via the replay mode and captured fixtures).

### Non-goals

- **No MCP runtime.** The Claude Code `Bash` tool plus a thin Python CLI
  already provides everything an MCP server would. The older
  `docs/Agents_Debug.md` blueprint was not adopted verbatim.
- **No automated fixes.** The agent observes, analyzes, and reports. Applying
  a suggested fix remains a user decision routed through `/plan` → `/sdd`.
- **No TTY programs.** No `vi`, `top`, `htop`, `nano`, `less` over the
  pipeline — those need raw TTY + ANSI handling this CLI does not provide.

---

## Architecture

### Component inventory

| Component     | Path                                    | Role                                                                           |
| ------------- | --------------------------------------- | ------------------------------------------------------------------------------ |
| Slash command | `.claude/commands/debug-board.md`       | Entry point. Preflight checks + spawn subagent.                                |
| Subagent      | `.claude/agents/board-runner.md`        | ReAct loop owner. Capture, analyze, probe, write report.                       |
| CLI helper    | `scripts/bbb-uart.py`                   | pyserial I/O. Subcmds: `capture-boot`, `send`, `scan`, `replay`.               |
| Regex DB      | `scripts/error-patterns.yaml`           | ≥17 patterns: kernel panic, probe, DT, I2C, SPI, GPIO, clock, PM, module, PWM. |
| Fixtures      | `tests/fixtures/boot-log-*.log`         | Captured logs for CI + iteration without hardware.                             |
| Reports dir   | `vault/wiki/debugging/reports/`         | AI-written reports. Indexed by `doc-updater`.                                  |
| Peer skill    | `.claude/skills/bsp-debugging/SKILL.md` | Manual debug-command reference consulted by the agent.                         |

### Block diagram

```
┌─────────────────────────────────────────────────────────────┐
│  User: /debug-board <tag> [focus] [--replay <logfile>]      │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  .claude/commands/debug-board.md                            │
│  - preflight (/dev/ttyUSB0 present, dialout, deps)          │
│  - spawns board-runner via Agent tool                       │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  board-runner subagent (tools: Bash, Read, Write)           │
│                                                             │
│  P1 init → P2 capture-boot → P3 scan → P4 ReAct probes      │
│          → P5 synthesize report → P6 hand to doc-updater    │
└────────────────────┬────────────────────────────────────────┘
                     │ Bash("python3 scripts/bbb-uart.py ...")
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  scripts/bbb-uart.py (pyserial + PyYAML)                    │
│    capture-boot  →  /dev/ttyUSB0  →  /tmp/bbb-<tag>-<ts>.log│
│    send          →  /dev/ttyUSB0  →  JSON{output,sentinel}  │
│    scan / replay →  logfile + YAML → JSON{errors,by_sev,..} │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  FTDI USB→3.3V TTL  →  BBB J1 pin 4/5  →  UART0 @0x44E09000 │
│  → getty → /bin/sh → output → UART0 TX → FTDI → ttyUSB0     │
└─────────────────────────────────────────────────────────────┘
```

### Why subagent + CLI, not MCP server

| Alternative               | Reason rejected                                                                                                                             |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Full MCP server (FastMCP) | ReAct loop = what a Claude Code subagent already provides. MCP adds a JSON-RPC protocol + daemon lifecycle for zero incremental capability. |
| Shell pipeline only       | Cannot do the analysis step. Report becomes a regex dump, not AI-reasoned synthesis.                                                        |
| Extend `debugger` agent   | `debugger` has a post-mortem contract (analyze logs a human provides). Live-board ownership is a different vertical. Mixing bloats both.    |
| Skill only                | Skills are documentation; no feedback loop. UART diagnostics need stateful round-trips.                                                     |

---

## Execution Path

Per diagnostic command round-trip, measured latency ~200–400 ms typical.

```
1. board-runner decides next command based on Phase 3/4 reasoning
2. Emits tool call:
     Bash("python3 scripts/bbb-uart.py send 'i2cdetect -y 1' --timeout 5")
3. Claude Code harness runs the Bash command in the host zsh/bash
4. python3 fork+exec → bbb-uart.py send
5. bbb-uart.py: serial.Serial('/dev/ttyUSB0', 115200, timeout=1.0)
   - reset_input_buffer()
   - write("i2cdetect -y 1; echo __DONE_<uuid>__\r\n")
   - flush()
6. FTDI chip converts USB bulk OUT → 3.3V TTL bytes on J1 pin 5
7. BBB UART0 RX (MMIO 0x44e09000) → 8250-omap driver → tty layer
8. /dev/ttyO0 (on board) → agetty → /bin/sh → execs i2cdetect
9. i2cdetect stdout → /dev/ttyO0 → UART0 TX (J1 pin 4)
10. FTDI USB bulk IN → host /dev/ttyUSB0 RX buffer
11. bbb-uart.py: readline() loop until line contains sentinel "__DONE_<uuid>__"
12. serial.close()
13. json.dump({cmd, output, sentinel_matched, elapsed_s, prompt_matched})
14. Python exits → stdout captured by Bash tool
15. Tool result returns to subagent as the string from step 13
16. Subagent reads JSON, updates hypothesis ranking, decides next command
```

### JSON contract

**`send` output schema:**

```json
{
  "cmd": "i2cdetect -y 1",
  "output": [
    "     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f",
    "00:          -- -- -- -- -- -- -- -- -- -- -- -- --",
    "10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --",
    "... (remaining 6 rows)",
    "root@beaglebone-custom:~# "
  ],
  "sentinel_matched": true,
  "elapsed_s": 0.34,
  "prompt_matched": true
}
```

**`scan` / `replay` output schema:**

```json
{
  "total_errors": 6,
  "errors": [
    {"line_number": 34, "line_content": "[    2.161246] omap_i2c 4819c000.i2c: failure adding adapter",
     "name": "i2c_adapter_fail", "severity": "critical", "category": "i2c",
     "description": "I2C adapter registration failed — controller init aborted."}
  ],
  "by_severity": {"critical": [...], "high": [...], "medium": [...]},
  "by_category":  {"i2c": [...], "probe_failure": [...], "clock": [...]},
  "has_critical": true,
  "logfile": "tests/fixtures/boot-log-i2c-error.log"
}
```

**`capture-boot` output schema:**

```json
{
  "cmd": "capture-boot",
  "port": "/dev/ttyUSB0",
  "out": "/tmp/bbb-smoke-test-1714659000.log",
  "lines_captured": 245,
  "boot_complete": true,
  "elapsed_s": 8.73,
  "status": "complete"
}
```

---

## Usage

### Example A — smoke test

```bash
# In Claude Code
/debug-board smoke-test
```

Subagent flow: capture-boot (60 s budget) → scan → expected `total_errors: 0`
or only `severity: info` hits → report written with "no issues detected"
verdict → hand off to doc-updater.

Produces: `vault/wiki/debugging/reports/2026-04-23-smoke-test.md`.

### Example B — focused I2C fault

```bash
/debug-board i2c-fault "i2c bus 2 SHT3x at 0x44 not probing"
```

Subagent flow: capture-boot → scan finds `i2c_adapter_fail` + `probe_eio` →
runs `i2cdetect -l`, `i2cdetect -y 2`, `cat /proc/device-tree/ocp/i2c@4819c000/status`,
`dmesg | grep -i i2c`, `cat /sys/kernel/debug/clk/clk_summary | grep i2c2`
over ≤20 iterations → synthesizes root-cause hypothesis (e.g. "I2C2 disabled
in DT" or "SHT3x compatible string typo") → writes report.

### Example C — fixture replay (no hardware)

```bash
/debug-board ci-replay --replay tests/fixtures/boot-log-i2c-error.log
```

Skips all serial I/O. Useful when:

- Iterating on `scripts/error-patterns.yaml` — add a new regex, replay a fixture,
  check hit count without touching a board.
- Running in CI — GitHub Actions workflow can invoke the scan step to catch
  regressions in the pattern DB.
- Developing the subagent prompt — test the reasoning logic against known-good
  and known-bad fixtures.

### Direct CLI usage (without the slash command)

The CLI is usable standalone for scripting:

```bash
# One-shot boot capture
python3 scripts/bbb-uart.py capture-boot \
  --port /dev/ttyUSB0 --out /tmp/boot.log --timeout 60

# One-shot command
python3 scripts/bbb-uart.py send "uname -r" --timeout 5

# One-shot scan
python3 scripts/bbb-uart.py scan /tmp/boot.log --patterns scripts/error-patterns.yaml
```

Combine with standard Unix tools:

```bash
python3 scripts/bbb-uart.py scan /tmp/boot.log --patterns scripts/error-patterns.yaml \
  | jq '.by_category.i2c[].line_content'
```

---

## Limits

These are real, not theoretical. Know them before blaming the pipeline.

### Stateless-per-call

Each `bbb-uart.py send` opens the port, does one round-trip, and closes. Shell
state (cwd, env vars, sudo token) is **not** preserved across calls:

```bash
# BAD — second call sees cwd=/, not /tmp
python3 scripts/bbb-uart.py send "cd /tmp"
python3 scripts/bbb-uart.py send "pwd"

# GOOD — chain in one command
python3 scripts/bbb-uart.py send "cd /tmp && pwd"
```

### No TTY apps

`vi`, `top`, `htop`, `nano`, `less` require raw TTY with ANSI escape handling
the CLI does not implement. Use non-TTY equivalents:

| TTY tool | Non-TTY replacement                                   |
| -------- | ----------------------------------------------------- |
| `top`    | `ps auxf` / `cat /proc/loadavg`                       |
| `less`   | `cat \| head -N` or write to file + `Read`            |
| `vi`     | `echo 'new content' > file`                           |
| `htop`   | `ps -eo pid,ppid,comm,%cpu,%mem --sort=-%cpu \| head` |

### Prompt detection fragility

The CLI uses a sentinel (`__DONE_<uuid>__`) appended to each command, so it is
robust against custom `PS1` values. If `sentinel_matched=false` in the JSON
response, possible causes:

- Shell is not Bash-compatible (sentinel is an `echo` statement).
- Line buffering disabled (unusual).
- Board froze / disconnected mid-command.

The subagent retries once with longer timeout, then escalates to the user.

### Port contention

`/dev/ttyUSB0` is exclusive. If another process holds it (`minicom`, `screen`,
a second `bbb-uart.py` instance), `serial.Serial(...)` fails with `EBUSY`.
Close competing sessions first:

```bash
sudo fuser /dev/ttyUSB0    # list PIDs holding the port
sudo fuser -k /dev/ttyUSB0 # force-close (last resort)
```

Daemon mode (shared connection, unix-socket clients) is deferred — see
Extending below.

### Power cycle = manual

The BBB has no software-controlled reset from the host unless you add a USB
relay or a smart plug. `capture-boot` prints a stderr message asking you to
press the reset button. Automate later with a cheap USB-HID relay if desired.

### Bash tool 10-minute cap

Long-running commands on the board exceed the Claude Code Bash tool timeout.
For minute-scale operations (running `cyclictest`, kernel builds on target),
write output to a file and poll:

```bash
python3 scripts/bbb-uart.py send "cyclictest -q -D60 > /tmp/ct.log &"
# ... do other work ...
python3 scripts/bbb-uart.py send "cat /tmp/ct.log"
```

### Output truncation

Huge command output (`dmesg` on a verbose boot, `cat /sys/kernel/debug/clk/clk_tree`)
can exceed tool-result size limits. Write to a file on the board, `scp`
or re-read in chunks:

```bash
python3 scripts/bbb-uart.py send "dmesg > /tmp/dmesg.out"
python3 scripts/bbb-uart.py send "wc -l /tmp/dmesg.out"
python3 scripts/bbb-uart.py send "grep -i error /tmp/dmesg.out | head -50"
```

### Binary data

pyserial decodes bytes with `utf-8` + `errors='ignore'`. Binary dumps get
mangled. For a register dump, base64-encode on the board:

```bash
python3 scripts/bbb-uart.py send "devmem2 0x44e09000 w | base64"
```

---

## Extending

### Add a regex to the pattern DB

Edit `scripts/error-patterns.yaml`, add a new entry under `patterns:`:

```yaml
- name: my_new_pattern
  regex: "my_driver: foo bar failed"
  severity: high
  category: my_category
  description: "What this indicates and what to check next."
```

Verify it compiles and matches a fixture:

```bash
python3 -c "import yaml, re; [re.compile(p['regex']) for p in yaml.safe_load(open('scripts/error-patterns.yaml'))['patterns']]"
python3 scripts/bbb-uart.py replay tests/fixtures/boot-log-<fixture>.log \
  --patterns scripts/error-patterns.yaml | jq '.by_category.my_category'
```

No code change required. The subagent automatically picks up the new category
in its Phase 3 analysis.

### Add a subcommand to the CLI

Edit `scripts/bbb-uart.py`:

1. Write a `cmd_<name>(args)` function returning `int` exit code.
2. Register it in `build_parser()` with a `sub.add_parser(...)` + `set_defaults(func=cmd_<name>)`.
3. Document in this file's "JSON contract" section if the output JSON changes.

### Migrate to daemon mode (when session state matters)

The stateless-per-call limit bites when you need persistent shell state
(running a long-running service on the board while querying it). Add:

```
bbb-uart.py serve --port /dev/ttyUSB0 --sock /tmp/bbb.sock &
bbb-uart.py send-sock --sock /tmp/bbb.sock "cd /tmp"
bbb-uart.py send-sock --sock /tmp/bbb.sock "pwd"  # → /tmp
```

Daemon holds the pyserial connection. Clients talk to it over a Unix socket.
One shell session persists across Claude Code `Bash` invocations.

Do this only when stateless-per-call becomes a real blocker — the complexity
cost is non-trivial (socket lifecycle, mutex, orphan-daemon detection).

### Multi-board (promote to MCP server)

If you later need remote access, parallel debugging of two boards, or
integration from a non-Claude-Code client, promote `bbb-uart.py` to an MCP
server using FastMCP. The tool surface stays the same (`capture-boot`, `send`,
`scan`) — only the transport changes from CLI stdout to JSON-RPC.

At that point, the older `docs/Agents_Debug.md` blueprint becomes a useful
reference if it is restored from history.

---

## References

- `.claude/agents/board-runner.md` — the subagent driving the pipeline.
- `.claude/agents/debugger.md` — sister agent for post-mortem analysis on
  logs the user provides (no live UART).
- `.claude/commands/debug-board.md` — slash-command wrapper.
- `.claude/skills/bsp-debugging/SKILL.md` — manual debug-command reference
  that the board-runner agent consults during Phase 4.
- `scripts/bbb-uart.py` — the CLI.
- `scripts/error-patterns.yaml` — regex knowledge base.
- Older `docs/Agents_Debug.md` blueprint — not adopted verbatim; MCP-server
  approach deliberately rejected in the current implementation.
- `vault/wiki/hardware-beagleboneblack/bringup-notes.md` — hardware wiring of
  the UART0 console.
- `vault/wiki/uboot/00-boot-flow.md` — SPL to U-Boot to kernel to init sequence
  the `capture-boot` subcommand expects.
- pyserial API: `pyserial.readthedocs.io/en/latest/pyserial_api.html`
- AM335x TRM §19 — UART/IrDA/CIR subsystem (UART0 base `0x44E09000`).
- BeagleBone Black SRM §7 — J1 header UART0 pinout (pin 1 GND, pin 4 RX, pin 5 TX).
