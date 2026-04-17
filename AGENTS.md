# AGENTS.md

## Start Here (source of truth)

- Prefer executable configs/scripts over docs if they conflict.
- Primary instruction files: `CLAUDE.md`, `.claude/rules/workflow.md`, `.claude/rules/coding-standards.md`, `.claude/rules/tech-defaults.md`.
- OpenCode-native prompts/agents/skills are in `.opencode/` (mirrors high-value `.claude/` behavior).
- Build orchestration is in `Makefile` + `scripts/build.sh` (not CI; workflow files are currently empty).

## Repo Reality (high-signal boundaries)

- `scripts/` is the real entrypoint for local build/deploy/flash flow.
- `meta-bbb/` is the Yocto layer; machine config is `meta-bbb/conf/machine/beaglebone-custom.conf` (inherits `beaglebone-yocto`).
- Kernel custom inputs for Yocto are pulled from repo-level `linux/patches/`, `linux/configs/`, `linux/dts/` via `meta-bbb/recipes-kernel/linux/linux-yocto_%.bbappend`.
- Out-of-tree modules live under `drivers/<name>/` and are built with per-driver Makefiles.
- `apps/` and `freertos/` currently contain no tracked files; don't assume runnable targets there.
- `tests/test-*.sh` currently exist but are empty placeholders.

## Preferred Commands (don't guess)

- Build Docker image:
  - `make docker`
- Build kernel / U-Boot / one driver / all:
  - `make kernel`
  - `make uboot`
  - `make driver DRIVER=led-gpio`
  - `make all`
- Yocto from container (auto-sources env):
  - `make yocto-shell`
  - `make bitbake BB=core-image-minimal`
- Manual cross defaults used by scripts:
  - `ARCH=arm`
  - `CROSS_COMPILE=arm-linux-gnueabihf-`

## Build Artifacts + Required Order

- `scripts/build.sh` copies outputs to `build/`:
  - kernel: `build/zImage`, `build/am335x-boneblack.dtb`
  - u-boot: `build/MLO`, `build/u-boot.img`
  - drivers: `build/*.ko`
- `make deploy` uses `scripts/deploy.sh` and expects artifacts already in `build/`.
- `make flash DEV=/dev/sdX` uses `scripts/flash_sd.sh` and expects all boot files in `build/` first (`MLO`, `u-boot.img`, `zImage`, `am335x-boneblack.dtb`).

## Safety-Critical Gotchas

- `scripts/flash_sd.sh` is destructive: repartitions target disk after typing `yes`; it refuses `/dev/sda`, `/dev/nvme0n1`, `/dev/mmcblk0`.
- Flash script must run as root and writes:
  - partition 1: 64MB FAT32 (boot)
  - partition 2: ext4 (rootfs)
- `make deploy` pings target first and defaults to `HOST=192.168.7.2`.

## Verification and Quality

- There is no active CI enforcement in `.github/workflows/` (files are empty); verify locally.
- Static checks expected by repo guidance:
  - `cppcheck --enable=all --suppress=missingIncludeSystem <file.c>`
  - `linux/scripts/checkpatch.pl --strict -f <file.c>` (run from `linux/` when applicable)
- For C/DTS/Yocto edits, follow `.editorconfig` + `.clang-format` (kernel-style tabs for C/Makefile/DTS; spaces for `.bb` and `.sh`).

## Wiki Sync Rule

- After substantive code changes in `linux/`, `drivers/`, `meta-bbb/`, `u-boot/`, or `scripts/`, update only impacted docs under `vault/wiki/` and keep examples executable.
- If no wiki page matches the changed area, update `vault/wiki/_master-index.md`.

## Commit Convention

- Use Conventional Commits; changelog grouping is driven by `cliff.toml`.
- Typical scopes seen in repo guidance: `driver`, `dts`, `wiki`.
