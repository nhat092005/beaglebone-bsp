---
description: Print a compact BSP status snapshot (git, artifacts, wiki, next actions).
---

Generate a read-only status report with these sections:

1. Git
   - `git log --oneline -5`
   - `git status --short`
   - last checkpoint in `.claude/checkpoints.log` if present
2. Build artifacts in `build/`
   - `zImage`, `am335x-boneblack.dtb`, `MLO`, `u-boot.img`, and `*.ko`
3. Wiki freshness
   - latest commits under `vault/wiki/`
4. Next actions
   - suggest `/build`, `/check`, `/sync-wiki`, or `/checkpoint` based on observed gaps

Do not run build/deploy/flash from this command.
