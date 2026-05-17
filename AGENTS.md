# AGENTS.md - BeagleBone BSP Codex Guide

@/home/nhat/.codex/RTK.md
@/home/nhat/.codex/CONTEXT-MODE.md

Codex is the only supported agent workflow for this repository. Do not use or
reintroduce legacy agent-system artifacts.

**Target:** AM335x BeagleBone Black, ARMv7-A, `arm-linux-gnueabihf-`
**Stack:** Linux 5.10.y-cip practice baseline, U-Boot 2022.07, Yocto Kirkstone,
FreeRTOS QEMU scaffold.

## Project Layout

```text
beaglebone-bsp/
├── apps/           Userspace demos and reserved app space
├── drivers/        Out-of-tree kernel modules
├── freertos/       FreeRTOS firmware scaffold
├── linux/          Kernel config, DTS, and patches
├── meta-bbb/       Yocto BSP layer
├── u-boot/         U-Boot source, config, and patches
├── scripts/        control/, debug/, lib/ operational helpers
├── tests/          Local verification and fixtures
├── docs/           Project docs and runbook
├── vault/wiki/     Maintained engineering knowledge base
├── .codex/         Codex project config, agents, hooks, rules
└── .agents/skills/ Codex repo skills
```

## Workflow

1. Start by reading this file and `vault/wiki/_master-index.md`.
2. For non-trivial work, state success criteria before editing.
3. For unfamiliar BSP, driver, DTS, U-Boot, Yocto, or hardware work, use the
   matching repo skill under `.agents/skills/`.
4. Before changing a function, method, class, or shared symbol, run GitNexus
   impact analysis and report blast radius.
5. Keep changes surgical. Do not rewrite adjacent code, docs, formatting, or
   generated artifacts unless directly required.
6. After substantive code changes in `linux/`, `drivers/`, `meta-bbb/`,
   `u-boot/`, or `scripts/`, update only impacted pages under `vault/wiki/`.
7. Before committing, run `gitnexus_detect_changes()` and confirm affected
   symbols/processes match the intended scope.

## Codex Surfaces

- Project instructions: `AGENTS.md`.
- Project config: `.codex/config.toml`.
- Custom subagents: `.codex/agents/*.toml`.
- Lifecycle hooks: `.codex/hooks.json` and `.codex/hooks/*.sh`.
- Command approval policy: `.codex/rules/default.rules`.
- Repo skills: `.agents/skills/<skill>/SKILL.md`.

Do not describe legacy repo-local custom slash commands as Codex features.
Codex built-in slash commands are available from the CLI; repo workflows such
as build, check, debug-board, and wiki sync live as skills.

## Common Commands

```bash
# Docker image
make docker

# Kernel
make kernel
make kernel-dev
make kernel-reproducible
make kernel-verify

# U-Boot
make uboot

# Out-of-tree driver
make driver DRIVER=<name>

# Yocto
make yocto-shell
make bitbake BB=bbb-image

# Static checks
make check
linux/scripts/checkpatch.pl --strict -f <file.c>
cppcheck --enable=all --suppress=missingIncludeSystem <file.c>
```

Manual cross-compile defaults:

- `ARCH=arm`
- `CROSS_COMPILE=arm-linux-gnueabihf-`

Serial console: `minicom -D /dev/ttyUSB0 -b 115200` (8N1, ttyO0).

## Safety Rules

- `scripts/control/flash_sd.sh` and `scripts/control/flash_yocto_wic.sh` are
  destructive. They repartition target media and require explicit user approval.
- Do not run flash, deploy, SSH, serial-console, or live-board commands without
  explicit user approval.
- Do not run broad staging commands such as `git add .` or `git add -A`; stage
  exact paths.
- Do not store secrets, board credentials, host-specific paths, or local tokens
  in tracked `.codex` or `.agents` files.
- Keep hidden hooks non-mutating. Formatting and checkpatch are explicit
  validation workflows, not automatic post-edit rewrites.

## BSP Coding Rules

- Kernel drivers: prefer `devm_*`, correct errno propagation, `dev_*` logging,
  `MODULE_*` metadata, `of_match_table`, and explicit cleanup/error paths.
- MMIO: use `ioread*`/`iowrite*`, document register offsets, and avoid raw
  pointer dereferences.
- IRQ/locking: do not sleep in atomic context; use IRQ-safe locking where data
  crosses interrupt and process context.
- DTS: verify compatible strings, `status`, `reg`, `#address-cells`,
  `#size-cells`, pinctrl, clocks, and AM335x TRM-derived addresses.
- Yocto: verify `LICENSE`, `LIC_FILES_CHKSUM`, `SRC_URI`, `SRCREV`,
  `FILESEXTRAPATHS`, `DEPENDS` vs `RDEPENDS`, and task ordering.
- Shell: use `set -euo pipefail`, quote variables, resolve repo paths from the
  script location, and guard destructive operations.

## Verification

- No active CI gate is assumed. Verify locally.
- For C/DTS/Yocto edits, follow `.editorconfig` and `.clang-format`.
- Use the smallest relevant proof first, then broader checks when risk demands.
- If a check cannot run because of missing toolchain, Docker, hardware, or
  network access, report the exact blocker and do not claim it passed.

## Wiki Sync

`vault/wiki/` is the maintained engineering knowledge base. Update only impacted
pages after substantive changes. If no page matches the changed area, update
`vault/wiki/_master-index.md`.

## Git Conventions

Use Conventional Commits, aligned with `cliff.toml`.

```text
feat(driver): add PWM fan driver for AM335x EHRPWM
fix(dts): correct UART0 pinmux reg address
docs(wiki): update I2C sensor wiring notes
chore(codex): migrate repo agent workflow to Codex
```

Typical scopes: `driver`, `dts`, `kernel`, `uboot`, `yocto`, `rtos`, `wiki`,
`scripts`, `codex`, `docs`.

## Cross-References

- Master wiki index: `vault/wiki/_master-index.md`
- Board bring-up guide: `vault/wiki/hardware-beagleboneblack/00-bringup-notes.md`
- Boot sequence detail: `vault/wiki/uboot/00-boot-flow.md`
- Live UART debug pipeline: `vault/wiki/debugging/00-debug-agent.md`
- Runbook: `docs/_RUNBOOK.md`

<!-- gitnexus:start -->
# GitNexus - Code Intelligence

This project is indexed by GitNexus as **beaglebone-bsp** (45624 symbols, 53729
relationships, 181 execution flows). Use GitNexus MCP tools to understand code,
assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in
> terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a
  function, class, or method, run `gitnexus_impact({target: "symbolName",
  direction: "upstream"})` and report direct callers, affected processes, and
  risk level.
- **MUST run `gitnexus_detect_changes()` before committing** to verify changes
  only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before
  proceeding with edits.
- Use `gitnexus_query({query: "concept"})` for unfamiliar flows before grep
  whenever relationship context matters.
- Use `gitnexus_context({name: "symbolName"})` when you need callers, callees,
  and process participation for a symbol.

## Never Do

- NEVER edit a function, class, or method without first running
  `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL impact-analysis warnings.
- NEVER rename symbols with find-and-replace; use `gitnexus_rename`.
- NEVER commit without running `gitnexus_detect_changes()`.

## Resources

| Resource | Use for |
| --- | --- |
| `gitnexus://repo/beaglebone-bsp/context` | Codebase overview and staleness check |
| `gitnexus://repo/beaglebone-bsp/clusters` | Functional areas |
| `gitnexus://repo/beaglebone-bsp/processes` | Execution flows |
| `gitnexus://repo/beaglebone-bsp/process/{name}` | Step-by-step trace |

## Skills

| Task | Repo skill |
| --- | --- |
| Understand architecture / how X works | `.agents/skills/gitnexus-exploring/SKILL.md` |
| Blast radius / what breaks | `.agents/skills/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / why X fails | `.agents/skills/gitnexus-debugging/SKILL.md` |
| Rename / extract / refactor | `.agents/skills/gitnexus-refactoring/SKILL.md` |
| GitNexus tools and schema | `.agents/skills/gitnexus-guide/SKILL.md` |
| Index/status/clean/wiki CLI | `.agents/skills/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
