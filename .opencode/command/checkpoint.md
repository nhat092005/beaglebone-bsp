---
description: Create and list lightweight git checkpoints for long tasks.
argument-hint: [create <name> | list | rollback <name>]
---

Modes:

- `create <name>`: make a checkpoint commit named `[CHECKPOINT] <name>` and append `.claude/checkpoints.log`.
- `list`: show recent checkpoint entries from git log and `.claude/checkpoints.log`.
- `rollback <name>`: locate checkpoint SHA from `.claude/checkpoints.log`, stash current work, then move to that commit.

Safety:

- Never hard reset.
- Always stash before rollback.
- If checkpoint name is ambiguous or missing, stop and report candidates.
