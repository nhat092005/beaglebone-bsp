# CLAUDE.md — BeagleBone BSP Project Guide

> Single entry point for Claude Code. Read in full at every session start.
> Subagents also read `.claude/CLAUDE.md` (invocation semantics).

**Target**: AM335x (BeagleBone Black), ARMv7-A, `arm-linux-gnueabihf-`
**Stack**: Linux 5.10.y-cip kernel, U-Boot 2022.07, Yocto Kirkstone, FreeRTOS (QEMU lm3s6965evb)

---

## Project Layout

```
beaglebone-bsp/
├── apps/           Userspace (gstreamer-demo, qt-hmi, sensor-monitor)
├── drivers/        Out-of-tree kernel modules (i2c-sensor, led-gpio, pwm-fan)
├── freertos/       FreeRTOS firmware (QEMU standalone)
├── linux/          Kernel sources (configs/, dts/, patches/)
├── meta-bbb/       Yocto BSP layer
├── u-boot/         U-Boot source + patches
├── scripts/        build.sh, deploy.sh, flash_sd.sh, bbb-uart.py
├── config/         error-patterns.yaml (used by board-runner agent)
├── tests/          On-target shell tests + fixtures
├── docs/           Numbered technical docs (00-roadmap → 09-debug-agent)
├── vault/wiki/     Knowledge base (indexed via _master-index.md)
└── .claude/        Agents, commands, rules, skills
```

---

## Quick Build Reference

```bash
# Kernel
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- omap2plus_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules

# U-Boot
make CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_custom_defconfig
make CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)

# Yocto
MACHINE=beaglebone-custom source poky/oe-init-build-env build && bitbake bbb-image

# Out-of-tree driver
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_DIR=$(pwd)/linux -C drivers/<name>

# Containerized (preferred)
make docker && make kernel   # see AGENTS.md for full Makefile target list
```

Static analysis:

```bash
scripts/checkpatch.pl --strict -f <file.c>   # from linux/
cppcheck --enable=all --suppress=missingIncludeSystem <file.c>
clang-format -i <file.c>
```

Serial console: `minicom -D /dev/ttyUSB0 -b 115200` (8N1, ttyO0).

---

## Agents (canonical table)

| Agent            | Role                                                      | When to invoke                                        |
| ---------------- | --------------------------------------------------------- | ----------------------------------------------------- |
| `researcher`     | Research hardware / subsystem before implementing         | Before any unfamiliar peripheral or kernel subsystem  |
| `architect`      | BSP system design, ADRs                                   | When planning a new driver, DT node, or major feature |
| `cpp-reviewer`   | C/C++ review (kernel, FreeRTOS, U-Boot)                   | After any driver/app code change                      |
| `reviewer`       | General review (DTS, Makefile, shell, Yocto recipes)      | PR / diff review, non-C files                         |
| `build-resolver` | Yocto / kernel / U-Boot build error fixer                 | When a build command exits non-zero                   |
| `debugger`       | Post-mortem runtime diagnosis (oops, probe fail, DT bind) | User provides logs, you analyze                       |
| `board-runner`   | Live UART debug pipeline                                  | Invoked by `/debug-board <tag>`                       |
| `doc-updater`    | Keep `vault/wiki/` in sync with code                      | After a feature lands; invoked by other agents        |

---

## Slash Commands (canonical table)

| Command        | What it does                                                                              |
| -------------- | ----------------------------------------------------------------------------------------- |
| `/plan`        | Re-anchor workflow rules, surface assumptions, define success criteria before coding      |
| `/sdd`         | Subagent-Driven Development — execute an approved plan task-by-task with two-stage review |
| `/build`       | Auto-detect context and run the right build (kernel / U-Boot / Yocto / driver / app)      |
| `/check`       | cppcheck + kernel checkpatch on changed C files                                           |
| `/status`      | Project health snapshot (git state, artifacts, wiki status)                               |
| `/checkpoint`  | Create a named git checkpoint before a risky change                                       |
| `/sync-wiki`   | Sync `vault/wiki/` with codebase via `doc-updater` agent                                  |
| `/debug-board` | Drive BBB over UART, capture boot + run tests, write AI report to vault                   |

---

## Skills (canonical table)

| Skill                           | Use when                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------ |
| `skills/embedded-c-patterns/`   | Writing new C: kernel drivers, FreeRTOS tasks, ISR safety, MMIO, DMA           |
| `skills/bsp-debugging/`         | Diagnosing runtime issues: oops, JTAG, dynamic debug, serial, Yocto build fail |
| `skills/karpathy-discipline/`   | Any non-trivial task — think / simplify / surgical / goal-driven scaffolding   |
| `skills/device-tree-reasoning/` | DT node missing, probe deferred, compatible mismatch, pinctrl failure          |
| `skills/uboot-reasoning/`       | SPL size gate, boot-env, bootcmd, zImage/DTB load, tftp, saveenv               |
| `skills/yocto-reasoning/`       | Recipe writing, bbappend vs recipe, SRC_URI pinning, DEPENDS vs RDEPENDS       |

---

## Session Behavior (protocol)

1. **Start of session**: read this file, all 4 imported rules, and `vault/wiki/_master-index.md` before taking action.
2. **Before writing code**: run `/plan` for any non-trivial task. State success criteria.
3. **Before touching hardware**: check `.claude/rules/bsp-context.md` for the exact peripheral base / IRQ / pinmux. If not listed, read the AM335x TRM.
4. **After writing driver / DTS / recipe code**: invoke `cpp-reviewer` (C/C++) or `reviewer` (other).
5. **After a feature lands**: invoke `doc-updater` or run `/sync-wiki`.
6. **Build failures**: spawn `build-resolver`. Runtime failures with logs: spawn `debugger`. Runtime failures on live board: `/debug-board`.

---

## Git Conventions

[Conventional Commits](https://www.conventionalcommits.org/). Driven by `cliff.toml`.

```
feat(driver): add PWM fan driver for AM335x EHRPWM
fix(dts): correct UART0 pinmux reg address
docs(wiki): update I2C sensor wiring notes
```

Typical scopes: `driver`, `dts`, `kernel`, `uboot`, `yocto`, `rtos`, `wiki`, `scripts`, `claude`, `opencode` (for agent-system changes).

---

## Cross-references

- Live UART debug pipeline: `docs/09-debug-agent.md`
- Board bring-up guide: `docs/01-bringup-notes.md`
- Boot sequence detail: `docs/02-boot-flow.md`
- Master wiki index: `vault/wiki/_master-index.md`
- OpenCode / non-Claude-Code tools: `AGENTS.md`

---

## Rules (auto-imported — do not duplicate their content above)

@.claude/rules/workflow.md
@.claude/rules/coding-standards.md
@.claude/rules/bsp-context.md
@.claude/rules/tech-defaults.md

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **beaglebone-bsp** (4799 symbols, 4800 relationships, 2 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource                                        | Use for                                  |
| ----------------------------------------------- | ---------------------------------------- |
| `gitnexus://repo/beaglebone-bsp/context`        | Codebase overview, check index freshness |
| `gitnexus://repo/beaglebone-bsp/clusters`       | All functional areas                     |
| `gitnexus://repo/beaglebone-bsp/processes`      | All execution flows                      |
| `gitnexus://repo/beaglebone-bsp/process/{name}` | Step-by-step execution trace             |

## CLI

| Task                                         | Read this skill file                                        |
| -------------------------------------------- | ----------------------------------------------------------- |
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md`       |
| Blast radius / "What breaks if I change X?"  | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?"             | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md`       |
| Rename / extract / split / refactor          | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md`     |
| Tools, resources, schema reference           | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md`           |
| Index, status, clean, wiki CLI commands      | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md`             |

<!-- gitnexus:end -->
