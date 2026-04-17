---
description: Sync impacted `vault/wiki` pages with recent code changes.
---

Use this after substantive code changes in `linux/`, `drivers/`, `meta-bbb/`, `u-boot/`, or `scripts/`.

Workflow:

1. Detect changed files (staged + unstaged + recent commits).
2. Map changed areas to matching docs under `vault/wiki/`.
3. Update only impacted pages and keep command examples executable.

If no wiki page matches the changed area, update:

- `vault/wiki/_master-index.md`

When changes are large, invoke `doc-updater` agent to perform the mapping and edits.
