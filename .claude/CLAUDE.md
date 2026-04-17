# .claude/CLAUDE.md — Agent & Skill Index

This file is read by Claude Code sub-agents and complements the root `CLAUDE.md`.

## Active Agents

| File                       | Role                                 | When to invoke                         |
| -------------------------- | ------------------------------------ | -------------------------------------- |
| `agents/cpp-reviewer.md`   | C/C++ code review (embedded-focused) | After any driver/app code change       |
| `agents/build-resolver.md` | Fix Yocto/kernel/U-Boot build errors | When build fails                       |
| `agents/architect.md`      | BSP system design, ADRs              | New feature/driver planning            |
| `agents/doc-updater.md`    | Keep wiki/ in sync with code         | After feature completion               |
| `agents/debugger.md`       | Runtime debugging, kernel oops       | Bug investigation                      |
| `agents/reviewer.md`       | General code review                  | PR/diff review                         |
| `agents/researcher.md`     | Research hardware/subsystem          | Before implementing unfamiliar feature |

## Available Skills

| Folder                        | Skill                               | Use when           |
| ----------------------------- | ----------------------------------- | ------------------ |
| `skills/embedded-c-patterns/` | Kernel/FreeRTOS/Yocto code patterns | Writing new C code |
| `skills/bsp-debugging/`       | Debug techniques for all BSP layers | Diagnosing issues  |

## Session Behavior

- Always check `vault/wiki/_master-index.md` before starting work on a domain
- After finishing a feature, invoke `doc-updater` to sync wiki
- Before writing a new driver, invoke `architect` for design review
- After writing code, invoke `cpp-reviewer` automatically

## Key References

- Root `CLAUDE.md` — project overview, build commands, coding rules
- `vault/wiki/_master-index.md` — knowledge base table of contents
- `vault/wiki/kernel/_index.md` — kernel/DTS knowledge
- `vault/wiki/yocto/_index.md` — Yocto layer knowledge
- `vault/wiki/bootloader/_index.md` — U-Boot knowledge
- `vault/wiki/drivers/_index.md` — driver patterns and list
- `vault/wiki/rtos/_index.md` — FreeRTOS/OpenAMP knowledge
- `vault/wiki/debugging/_index.md` — debugging techniques
