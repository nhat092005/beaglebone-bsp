---
title: Git Advanced — Backport / Upstream
last_updated: 2026-04-18
category: learning
---

# Git Advanced — Backport / Upstream Workflow

Essential for kernel development: backporting fixes, submitting upstream.

## git bisect — Find Bug Commit

```bash
git bisect start
git bisect bad              # Current commit is broken
git bisect good v5.10.1    # Known good commit

# Git checks out intermediate test mark
make && ./test_uart.sh
git bisect good           # No bug
git bisect bad            # Bug present

# Result: culprit commit hash
git bisect reset
```

**Automated:**

```bash
git bisect start HEAD v5.10.1
git bisect run ./test_uart.sh  # exit 0=good, exit 1=bad
```

## git cherry-pick — Pick Single Commit

```bash
git cherry-pick <commit_hash>        # Apply 1 commit
git cherry-pick abc123 def456        # Apply multiple
git cherry-pick v5.15..v5.15.3     # Apply range

# Conflict fix continue
git cherry-pick --continue
git cherry-pick --abort               # Cancel
git cherry-pick -n <hash>           # Stage only, don't commit
```

## git rebase — Clean History

```bash
git rebase main                   # Rebase onto main

# Interactive: squash/reword/reorder
git rebase -i HEAD~4
```

```
pick abc1234 Add UART driver
pick def5678 Fix typo           squash
pick ghi9012 Fix build warning fixup
pick jkl3456 Add DTS entry     reword
```

> Never rebase public branches — rewrites history.

## git format-patch — Create Patch

```bash
git format-patch -1 HEAD                # Last commit
git format-patch -3 HEAD                # Last 3 commits
git format-patch HEAD~3..HEAD         # Range
git format-patch -1 HEAD -o patches/  # Save to directory
```

Output: `0001-uart-fix-rx-buffer-overflow.patch`

## git am — Apply Patch

```bash
git am patches/0001-uart-fix.patch
git am patches/*.patch

# Conflict handling
git am --continue
git am --skip
git am --abort
git am --whitespace=fix patches/*.patch
```

## Real Workflow: Backport Kernel Fix

```bash
# 1. Find fix on mainline
git log --oneline mainline/master | grep "uart"
git show <hash>

# 2. Checkout stable branch
git checkout linux-5.10.y

# 3. Try cherry-pick
git cherry-pick <hash>

# 4a. No conflict create patch for maintainer
git format-patch -1 HEAD -o patches/

# 4b. Conflict fix manually continue
git add drivers/tty/serial/omap-serial.c
git cherry-pick --continue
git format-patch -1 HEAD -o patches/
```

## Upstream Submission (Kernel Style)

```bash
# 1. Create patch
git format-patch -1 HEAD --cover-letter -o patches/

# 2. Check style
./scripts/checkpatch.pl patches/0001-*.patch

# 3. Find maintainer
./scripts/get_maintainer.pl patches/0001-*.patch

# 4. Send via email
git send-email --to="maintainer@kernel.org" patches/0001-*.patch
```

## Quick Reference

| Command                            | Use When                              |
| ---------------------------------- | ------------------------------------- |
| `git bisect`                       | Find regression commit                |
| `git cherry-pick`                  | Pick specific fix from another branch |
| `git rebase -i`                    | Clean history before upstream         |
| `git format-patch`                 | Create kernel-style patch             |
| `git am`                           | Apply patch to repo                   |
| `git log --oneline mainline..HEAD` | Show commits not yet upstreamed       |
