---
title: Debugging
last_updated: 2026-04-26
category: debugging
---

# Debugging

Debugging knowledge base for BeagleBone BSP bring-up, UART capture, log triage, and report-driven diagnosis.

## Workflow

| #   | Topic                      | File                              |
| --- | -------------------------- | --------------------------------- |
| 00  | UART Debug Agent           | [[00-debug-agent.md]]             |
| 01  | Smoke Test Report Template | [[reports/example-smoke-test.md]] |

## What This Section Covers

- Serial-console based boot capture and post-boot probing
- Structured error scanning using `config/error-patterns.yaml`
- Root-cause reporting with evidence chain and actionable next steps
- Replay workflow for offline/CI debugging without live hardware

## Reports

Debug reports are stored in `vault/wiki/debugging/reports/`.

Naming convention:

```text
YYYY-MM-DD-<tag>.md
```

Recommended report schema:

- YAML frontmatter:
  - `report_type`
  - `timestamp`
  - `tag`
  - `focus`
  - `boot_log`
  - `summary.total_errors`
  - `summary.has_critical`
  - `summary.boot_complete`
  - `summary.iterations_used`
- Body sections:
  - Executive Summary
  - Boot Timeline
  - Errors Detected
  - Hypotheses Tested
  - Root Cause
  - Suggested Next Steps
  - Evidence Chain
  - Artifacts

| Date | Tag      | Focus   | Critical | Boot Complete | File                              |
| ---- | -------- | ------- | -------- | ------------- | --------------------------------- |
| N/A  | template | general | N/A      | N/A           | [[reports/example-smoke-test.md]] |

## References

- `vault/wiki/debugging/00-debug-agent.md` - architecture and usage of the automated UART debug pipeline
- `docs/09-debug-agent.md` - project-level command and agent behavior reference
- `scripts/bbb-uart.py` - UART capture/send/scan CLI
- `config/error-patterns.yaml` - boot-log regex patterns and severities
- `tests/fixtures/boot-log-*.log` - replay fixtures for CI and local analysis
