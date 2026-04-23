---
description: Create or list named git checkpoints with a log entry. Use before starting a new feature or large change. Supports rollback to any named checkpoint.
---

# Checkpoint

Create, list, or roll back to a named git checkpoint.

**Input**: $ARGUMENTS

## Mode Selection

If $ARGUMENTS starts with "create": go to Create Checkpoint.
If $ARGUMENTS is "list": go to List Checkpoints.
If $ARGUMENTS starts with "rollback": go to Rollback.
If $ARGUMENTS is empty: go to List Checkpoints.

---

## Create Checkpoint

Creates a git commit tagged as a checkpoint with a log entry.

### Step 1 -- Check current state

```bash
git status --short
git stash list | head -5
```

### Step 2 -- Stage and commit

```bash
git add -u
git commit -m "[CHECKPOINT] $NAME -- $(date '+%Y-%m-%d %H:%M')"
```

If there are unstaged changes that should not be committed yet, use stash instead:

```bash
git stash push -m "[CHECKPOINT] $NAME"
```

### Step 3 -- Write log entry

```bash
mkdir -p .claude
echo "$(date '+%Y-%m-%d %H:%M') | $NAME | $(git rev-parse --short HEAD)" >> .claude/checkpoints.log
```

### Step 4 -- Report

```
Checkpoint created
Name:   $NAME
SHA:    $(git rev-parse --short HEAD)
Time:   $(date '+%Y-%m-%d %H:%M')
Log:    .claude/checkpoints.log
```

---

## List Checkpoints

```bash
cat .claude/checkpoints.log 2>/dev/null || echo "No checkpoints yet."
git log --oneline --grep="\[CHECKPOINT\]" -10
```

Output format:

```
Recent Checkpoints
2026-04-15 22:00 | before-uart-driver  | abc1234
2026-04-14 18:30 | clean-yocto-build   | def5678

Run /checkpoint rollback <name> to return to a checkpoint.
```

---

## Rollback to Checkpoint

Ask the user to confirm before rolling back:

```
Confirm rollback to checkpoint '$NAME'?
All changes after this checkpoint will be stashed, not deleted.

WARNING: This will put you in detached HEAD state.
You must run `git checkout -b <branch-name>` before making new commits.

Type 'yes' to confirm.
```

Wait for confirmation. If not confirmed, stop.

If confirmed:

```bash
# Find SHA for the checkpoint name
SHA=$(grep "$NAME" .claude/checkpoints.log | tail -1 | awk '{print $NF}')

# Stash current changes first
git stash push -m "auto-stash before rollback to $NAME"

# Check out the checkpoint commit
git checkout "$SHA"
```

Report the result. Remind user: (1) current changes are in stash, (2) HEAD is now detached — run `git checkout -b <branch>` before committing.

## Stop Conditions

- Do not rollback if $NAME is not found in the checkpoint log
- Do not delete any code -- always stash before rollback
- Do not auto-confirm rollback -- always wait for user input

## Success Criteria

- `create`: `.claude/checkpoints.log` has new entry with correct SHA
- `list`: checkpoint log printed without error
- `rollback`: working directory matches the checkpoint commit, previous changes in stash
