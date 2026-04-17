# .opencode (beaglebone-bsp)

OpenCode-native workspace config for this repo.

## Source of truth

- `AGENTS.md`
- `Makefile`
- `scripts/build.sh`, `scripts/deploy.sh`, `scripts/flash_sd.sh`

If docs conflict with executable scripts, follow scripts.

## Layout

- `opencode.jsonc`: core OpenCode config
- `command/`: reusable slash commands
- `agent/`: focused subagents for BSP workflows
- `skills/`: embedded-domain guidance loaded by agents
- `tool/`, `plugins/`, `themes/`, `glossary/`: standard OpenCode folders

## Repo constraints mirrored here

- Use `make` targets as primary entrypoints.
- Do not write into `build/` manually.
- Keep flashing safety strict (`scripts/flash_sd.sh` is destructive).
- After substantive code changes in `linux/`, `drivers/`, `meta-bbb/`, `u-boot/`, or `scripts/`, sync impacted docs in `vault/wiki/`.
