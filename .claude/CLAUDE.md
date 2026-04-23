# .claude/CLAUDE.md — Subagent Invocation Guide

Read by Claude Code subagents. Complements root `CLAUDE.md` (the master tables live there).

This file answers: "How do I invoke another agent or skill from inside a subagent, and what protocol do we follow across the session?"

## Rules of Engagement

- **Never duplicate content** from root `CLAUDE.md`. If you need the agents/commands/skills inventory, read it.
- **Single-writer rule**: only `doc-updater` writes to `vault/wiki/**`. Other agents propose changes via notes, not direct writes.
- **Single-owner rule**: only `board-runner` touches `/dev/ttyUSB0` and `vault/wiki/debugging/reports/`.
- **Review pairing**: any agent that writes C code must hand off to `cpp-reviewer` before the task is considered complete. DTS / shell / Yocto → `reviewer`.

## Session Behavior Protocol

### Every subagent on spawn

1. Read the root `CLAUDE.md` + all 4 imported rules (they are small).
2. Read the skill(s) relevant to the task: default = `embedded-c-patterns` + `karpathy-discipline`.
3. For DT work: also read `skills/device-tree-reasoning/SKILL.md`.
4. For U-Boot work: `skills/uboot-reasoning/SKILL.md`.
5. For Yocto work: `skills/yocto-reasoning/SKILL.md`.
6. For runtime diagnosis: `skills/bsp-debugging/SKILL.md`.

### Hand-off conventions

| Source agent                  | Situation                 | Hand to                                                          |
| ----------------------------- | ------------------------- | ---------------------------------------------------------------- |
| `architect`                   | Design approved           | caller runs `/sdd` (not architect directly)                      |
| `build-resolver`              | Needs runtime evidence    | `debugger` or `/debug-board` (live)                              |
| `debugger`                    | Fix identified            | `cpp-reviewer` for review, then user approves                    |
| `board-runner`                | Report written            | `doc-updater` (index refresh)                                    |
| `cpp-reviewer` / `reviewer`   | Issues found              | back to originating agent with concrete fixes                    |
| Any agent                     | Feature complete          | `doc-updater` (via explicit invocation or `/sync-wiki`)          |

## Canonical Reference Map

| Need...                                   | Read...                                   |
| ----------------------------------------- | ----------------------------------------- |
| Agent / command / skill inventory         | root `CLAUDE.md`                          |
| Decision discipline (Karpathy-derived)    | `.claude/rules/workflow.md`               |
| Code style per layer                      | `.claude/rules/coding-standards.md`       |
| Hardware addresses / boot sequence        | `.claude/rules/bsp-context.md`            |
| Toolchain flags / defconfigs              | `.claude/rules/tech-defaults.md`          |
| Knowledge base TOC                        | `vault/wiki/_master-index.md`             |
| Per-agent behavior contract               | `.claude/agents/<name>.md`                |
| Per-slash-command runbook                 | `.claude/commands/<name>.md`              |
| OpenCode / tool-agnostic entry            | `AGENTS.md`                               |

## Anti-patterns

- **Running a build without `/plan` first** on a non-trivial task.
- **Reading the full AM335x TRM into context.** Read `.claude/rules/bsp-context.md` first; fetch only the specific TRM section you need via URL.
- **Assuming hardware behavior.** If a peripheral / register / pinmux fact is not in `bsp-context.md` or the wiki, STOP and ask.
- **Touching upstream DTS files** (`linux/arch/arm/boot/dts/am33xx.dtsi` etc.). Use the project overlay `linux/dts/am335x-boneblack-custom.dts`.
- **Writing the same fact in two places** — fix the root cause (bad cross-reference), not the symptom.
