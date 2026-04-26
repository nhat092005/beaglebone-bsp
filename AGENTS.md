# AGENTS.md — BeagleBone BSP Project Guide (OpenCode)

> Entry point for OpenCode and tool-agnostic AI coding tools.
> Claude Code users should read `CLAUDE.md` instead.

**Target**: AM335x (BeagleBone Black), ARMv7-A, `arm-linux-gnueabihf-`
**Stack**: Linux 5.10.y-cip kernel, U-Boot 2022.07, Yocto Kirkstone, FreeRTOS (QEMU lm3s6965evb)

---

## Project Layout

```
beaglebone-bsp/
├── apps/           Userspace (reserved, not yet populated)
├── drivers/        Out-of-tree kernel modules (i2c-sensor, led-gpio, pwm-fan)
├── freertos/       FreeRTOS firmware (scaffold only, no source yet)
├── linux/          Kernel sources (configs/, dts/, patches/)
├── meta-bbb/       Yocto BSP layer
├── u-boot/         U-Boot source + patches
├── scripts/        build.sh, deploy.sh, flash_sd.sh
├── tests/          Shell tests (test-reproducible-build.sh implemented, others placeholder)
├── docs/           Project documents
├── vault/wiki/     Knowledge base (indexed via _master-index.md)
├── .opencode/      OpenCode agents, commands, config
└── .claude/        Claude Code agents, commands, rules, skills
```

---

## Quick Build Reference

```bash
# Kernel
make kernel

# U-Boot
make uboot

# Out-of-tree driver
make driver DRIVER=<name>

# All targets
make all

# Yocto (from container)
make yocto-shell
make bitbake BB=bbb-image
```

Manual cross-compile defaults:

- `ARCH=arm`
- `CROSS_COMPILE=arm-linux-gnueabihf-`

Static analysis:

```bash
cppcheck --enable=all --suppress=missingIncludeSystem <file.c>
linux/scripts/checkpatch.pl --strict -f <file.c>
```

Serial console: `minicom -D /dev/ttyUSB0 -b 115200` (8N1, ttyO0).

---

## Agents

| Agent            | Role                                                      | When to invoke                                        |
| ---------------- | --------------------------------------------------------- | ----------------------------------------------------- |
| `researcher`     | Research hardware / subsystem before implementing         | Before any unfamiliar peripheral or kernel subsystem  |
| `architect`      | BSP system design, ADRs                                   | When planning a new driver, DT node, or major feature |
| `cpp-reviewer`   | C/C++ review (kernel, FreeRTOS, U-Boot)                   | After any driver/app code change                      |
| `reviewer`       | General review (DTS, Makefile, shell, Yocto recipes)      | PR / diff review, non-C files                         |
| `build-resolver` | Yocto / kernel / U-Boot build error fixer                 | When a build command exits non-zero                   |
| `debugger`       | Post-mortem runtime diagnosis (oops, probe fail, DT bind) | User provides logs, you analyze                       |
| `doc-updater`    | Keep `vault/wiki/` in sync with code                      | After a feature lands                                 |

Invoke agents via `@` mention (e.g., `@researcher`).

---

## Commands

| Command       | What it does                                                                      |
| ------------- | --------------------------------------------------------------------------------- |
| `/plan`       | Produce implementation plan with assumptions and verification steps before coding |
| `/sdd`        | Subagent-Driven Development — execute plan task-by-task with two-stage review     |
| `/build`      | Auto-detect context and run the right build (kernel / U-Boot / Yocto / driver)    |
| `/check`      | cppcheck + kernel checkpatch on changed C files                                   |
| `/status`     | Project health snapshot (git state, artifacts, wiki status)                       |
| `/checkpoint` | Create/list/rollback git checkpoints                                              |
| `/sync-wiki`  | Sync `vault/wiki/` with codebase via `doc-updater` agent                          |

---

## Skills

Skills auto-discovered from `.claude/skills/`:

| Skill                   | Use when                                                                       |
| ----------------------- | ------------------------------------------------------------------------------ |
| `embedded-c-patterns`   | Writing new C: kernel drivers, FreeRTOS tasks, ISR safety, MMIO, DMA           |
| `bsp-debugging`         | Diagnosing runtime issues: oops, JTAG, dynamic debug, serial, Yocto build fail |
| `karpathy-discipline`   | Any non-trivial task — think / simplify / surgical / goal-driven scaffolding   |
| `device-tree-reasoning` | DT node missing, probe deferred, compatible mismatch, pinctrl failure          |
| `uboot-reasoning`       | SPL size gate, boot-env, bootcmd, zImage/DTB load, tftp, saveenv               |
| `yocto-reasoning`       | Recipe writing, bbappend vs recipe, SRC_URI pinning, DEPENDS vs RDEPENDS       |

Load skills via `skill` tool when needed.

---

## Workflow Protocol

1. **Start of session**: read this file and `vault/wiki/_master-index.md` before taking action.
2. **Before writing code**: run `/plan` for any non-trivial task. State success criteria.
3. **After writing driver / DTS / recipe code**: invoke `@cpp-reviewer` (C/C++) or `@reviewer` (other).
4. **After a feature lands**: invoke `@doc-updater` or run `/sync-wiki`.
5. **Build failures**: invoke `@build-resolver`. Runtime failures with logs: invoke `@debugger`.

---

## Build Artifacts

`scripts/build.sh` copies outputs to `build/`:

- kernel: `build/kernel/zImage`, `build/kernel/am335x-boneblack-custom.dtb`
- u-boot: `build/uboot/MLO`, `build/uboot/u-boot.img`
- drivers: `build/drivers/<name>/*.ko`

`make deploy` uses `scripts/deploy.sh` and expects artifacts already in `build/`.

`make flash DEV=/dev/sdX` uses `scripts/flash_sd.sh` and expects all boot files in `build/` first.

---

## Safety-Critical Gotchas

- `scripts/flash_sd.sh` is destructive: repartitions target disk after typing `yes`; refuses `/dev/sda`, `/dev/nvme0n1`, `/dev/mmcblk0`.
- Flash script must run as root and writes:
  - partition 1: 100MB FAT32 (boot)
  - partition 2: ext4 (rootfs)
- `make deploy` pings target first and defaults to `HOST=192.168.7.2`.

---

## Verification and Quality

- No active CI enforcement in `.github/workflows/` (files are empty); verify locally.
- Static checks expected by repo guidance:
  - `cppcheck --enable=all --suppress=missingIncludeSystem <file.c>`
  - `linux/scripts/checkpatch.pl --strict -f <file.c>` (run from `linux/` when applicable)
- For C/DTS/Yocto edits, follow `.editorconfig` + `.clang-format` (kernel-style tabs for C/Makefile/DTS; spaces for `.bb` and `.sh`).

---

## Wiki Sync Rule

After substantive code changes in `linux/`, `drivers/`, `meta-bbb/`, `u-boot/`, or `scripts/`, update only impacted docs under `vault/wiki/` and keep examples executable.

If no wiki page matches the changed area, update `vault/wiki/_master-index.md`.

---

## Git Conventions

[Conventional Commits](https://www.conventionalcommits.org/). Driven by `cliff.toml`.

```
feat(driver): add PWM fan driver for AM335x EHRPWM
fix(dts): correct UART0 pinmux reg address
docs(wiki): update I2C sensor wiring notes
```

Typical scopes: `driver`, `dts`, `kernel`, `uboot`, `yocto`, `rtos`, `wiki`, `scripts`, `opencode`.

---

## Cross-references

- Live UART debug pipeline: `vault/wiki/debugging/00-debug-agent.md`
- Board bring-up guide: `vault/wiki/hardware-beagleboneblack/00-bringup-notes.md`
- Boot sequence detail: `vault/wiki/uboot/00-boot-flow.md`
- Master wiki index: `vault/wiki/_master-index.md`
- Claude Code entry point: `CLAUDE.md`

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
