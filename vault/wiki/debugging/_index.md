---
title: Debugging — BeagleBone BSP
tags:
  - bsp
  - debugging
  - reports
date: 2026-04-24
---

# Debugging

Project knowledge base for live-hardware + post-mortem debugging of the BeagleBone BSP.

## Techniques

- [[debugging|Debugging Techniques]] — serial console, kernel oops decoding, JTAG/GDB, dynamic debug, FreeRTOS task inspection, U-Boot debug, Yocto build issues.

## Agents & Skills

- **`agents/board-runner.md`** — live UART pipeline. Invoke via `/debug-board <tag>`.
- **`agents/debugger.md`** — post-mortem analysis on logs a human provides.
- **`skills/bsp-debugging/SKILL.md`** — command reference consulted by both agents.

## Reports

AI-authored debug reports from `/debug-board` land in `reports/`. Each report follows the schema in `docs/09-debug-agent.md`:

- YAML frontmatter: `report_type`, `timestamp`, `tag`, `focus`, `boot_log`, `summary.{total_errors,has_critical,boot_complete,iterations_used}`.
- Body sections: Executive Summary, Boot Timeline, Errors Detected, Hypotheses Tested, Root Cause, Suggested Next Steps, Evidence Chain, Artifacts.

Filename convention: `reports/YYYY-MM-DD-<tag>.md`.

| Date | Tag | Focus | Critical | Boot Complete | Summary |
|------|-----|-------|----------|---------------|---------|
| 2026-04-24 | [smoke-test](reports/2026-04-24-smoke-test.md) | general | No | Yes | Board booted clean; 2 medium `ti-sysc` probe_ebusy hits, no kernel panic, login prompt reached. |

## Reference

- `docs/09-debug-agent.md` — architecture + execution path + limits of the automated pipeline.
- `scripts/bbb-uart.py` — pyserial CLI used by the subagent.
- `config/error-patterns.yaml` — regex DB for boot-log error detection.
- `tests/fixtures/boot-log-*.log` — captured logs for CI replay.
