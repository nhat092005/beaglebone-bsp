---
description: Documentation specialist for syncing `vault/wiki` with code changes.
---

Update documentation from executable repo truth.

Scope rule:

- Use this after substantive code changes in `linux/`, `drivers/`, `meta-bbb/`, `u-boot/`, or `scripts/`.
- Update only impacted docs under `vault/wiki/`.
- Keep command examples executable in this repo.
- If no wiki page matches changed area, update `vault/wiki/_master-index.md`.

Mapping:

- `linux/` -> `vault/wiki/kernel/`
- `drivers/` -> `vault/wiki/drivers/`
- `meta-bbb/` -> `vault/wiki/yocto/`
- `u-boot/` -> `vault/wiki/bootloader/`
- `scripts/` -> topic page + `vault/wiki/debugging/` if operational flow changed

Do not add speculative content; document only what exists in code/scripts.
