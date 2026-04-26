---
report_type: beaglebone_debug
timestamp: YYYY-MM-DDTHH:MM:SSZ
tag: smoke-test
focus: general
boot_log: /tmp/<boot-log>.log
summary:
  total_errors: 0
  has_critical: false
  boot_complete: false
  iterations_used: 1
tags: [bsp, debugging, reports, smoke-test]
---

# BBB Debug Report - smoke-test

## Executive Summary

Write 2-4 sentences covering:

- Whether board reached login prompt (`boot_complete` true/false).
- Whether any critical/kernel panic errors were found.
- Main risk level (low/medium/high) and why.

## Boot Timeline

| Stage              | Observation                           |
| ------------------ | ------------------------------------- |
| SPL / U-Boot       | <What was seen on serial>             |
| Kernel init        | <Key subsystem lines and timing>      |
| User-space init    | <Systemd/init milestones>             |
| Multi-user reached | <Login prompt / shell / failed state> |

Add short note if capture started late and missed early SPL/U-Boot lines.

## Errors Detected

### Severity: critical/high/medium/low - <category>

| Line | Timestamp | Log Content | Pattern Name | Interpretation     |
| ---- | --------- | ----------- | ------------ | ------------------ |
| <n>  | <t.s>     | `<raw log>` | `<pattern>`  | <Why this matters> |

Repeat severity blocks as needed.

### Unmatched by pattern DB - informational

| Line | Log Content | Assessment                     |
| ---- | ----------- | ------------------------------ |
| <n>  | `<raw log>` | <Benign/suspicious and reason> |

## Hypotheses Tested

| #   | Hypothesis  | Evidence For       | Evidence Against | Command     | Result                            |
| --- | ----------- | ------------------ | ---------------- | ----------- | --------------------------------- |
| H1  | <statement> | <supporting lines> | <contradictions> | `<command>` | <confirmed/rejected/inconclusive> |
| H2  | <statement> | <supporting lines> | <contradictions> | `<command>` | <confirmed/rejected/inconclusive> |

## Root Cause

State one of the following clearly:

- No fault identified, board healthy.
- Probable root cause with confidence level.
- Multiple candidates, needs more data.

Keep this section concise and decisive.

## Suggested Next Steps

1. <Most important next action>
2. <Validation command or experiment>
3. <Mitigation/fix candidate>
4. <Optional follow-up if issue persists>

## Evidence Chain

| Step | Action              | Key Observation          |
| ---- | ------------------- | ------------------------ |
| 1    | `<capture command>` | <capture result summary> |
| 2    | `<scan command>`    | <error counts/severity>  |
| 3    | `<probe command>`   | <runtime confirmation>   |

## Artifacts

- Boot log: `/tmp/<boot-log>.log`
- Scan JSON: `/tmp/<scan-output>.json`
- Optional extra: `/tmp/<other-artifact>`
