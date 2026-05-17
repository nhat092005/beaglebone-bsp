---
name: bsp-wiki-sync
description: Use after substantive beaglebone-bsp changes in linux, drivers, meta-bbb, u-boot, scripts, or debug workflows to update vault/wiki.
---

1. Inspect changed files with `git diff --name-only`.
2. Map each changed area to the closest page under `vault/wiki/`.
3. Update only impacted docs.
4. Keep command examples executable and current.
5. Update `last_updated` or status metadata only when the target page already uses it.
6. If no existing page matches, update `vault/wiki/_master-index.md`.
7. Verify no stale path references remain.
