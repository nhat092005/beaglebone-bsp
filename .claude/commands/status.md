---
description: Show a project status snapshot covering git state, build artifacts, wiki status, and suggested next actions. Run at the start of a session to orient quickly.
---

# Status

Display a quick snapshot of the BeagleBone BSP project state.

## Phase 1 -- Git State

```bash
git log --oneline -5
git status --short
git stash list | head -3
cat .claude/checkpoints.log 2>/dev/null | tail -3
```

## Phase 2 -- Build Artifacts

Check which build outputs exist:

```bash
ls -lh linux/arch/arm/boot/zImage 2>/dev/null
ls -lh linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb 2>/dev/null
ls -lh u-boot/u-boot.img 2>/dev/null
find drivers -name '*.ko' 2>/dev/null | head -5
```

For each artifact: report whether it exists, its size, and how recently it was built (file modification time).

Check if any source files are newer than the build artifacts (staleness check):

```bash
# DTS files newer than zImage -- means kernel may need rebuild
find linux/arch/arm/boot/dts -newer linux/arch/arm/boot/zImage -name "*.dts" 2>/dev/null

# C source files newer than any .ko driver -- means drivers may need rebuild
NEWEST_KO=$(find drivers -name "*.ko" 2>/dev/null | head -1)
if [ -n "$NEWEST_KO" ]; then
  find drivers -name "*.c" -newer "$NEWEST_KO" 2>/dev/null | head -5
fi
```

If any stale sources are found, flag the affected artifact as **STALE** in the report.

## Phase 3 -- Wiki Status

Check `_index.md` files for last-updated timestamps:

```bash
for f in vault/wiki/*/_index.md; do
  grep "Last Updated:" "$f" 2>/dev/null || echo "$f: not updated"
done
```

Also check the most recent git commits touching the wiki directory (catches updates to regular files without `_index.md`):

```bash
git log --oneline -- vault/wiki/ | head -3
```

Report both: the `Last Updated:` field from each index file, and the last commit date on the wiki directory.

## Phase 4 -- Project File Count

```bash
for d in apps drivers freertos linux meta-bbb scripts tests u-boot; do
  count=$(find "$d" -type f 2>/dev/null | wc -l)
  echo "$d: $count files"
done
```

## Phase 5 -- Report

Format the output as a plain text summary:

```
Project Status -- BeagleBone BSP -- <date>

GIT
  Last commit: <message> (<SHA>)
  Uncommitted: <N files>
  Last checkpoint: <name> (<SHA>) or none

BUILD ARTIFACTS
  zImage:               exists (3.1 MB, built 2h ago) or missing | STALE if DTS newer
  am335x-boneblack.dtb: exists or missing
  u-boot.img:           exists or missing
  Custom drivers built: <N> | STALE if .c sources newer than .ko

WIKI
  kernel:     Last Updated: 2026-04-15 or not updated
  bootloader: Last Updated: ... or not updated
  drivers:    Last Updated: ... or not updated
  yocto:      Last Updated: ... or not updated
  rtos:       Last Updated: ... or not updated
  debugging:  Last Updated: ... or not updated
  Last wiki commit: <message> (<SHA>) or none

SUGGESTED NEXT ACTIONS
  1. <action based on what is missing or stale>
  2. <action>
  3. <action>
```

Suggested next actions should be based on actual state. Examples:

- "Run /build kernel -- zImage is missing"
- "Run /build kernel -- zImage is STALE (DTS modified after last build)"
- "Run /build drivers -- .ko files are STALE (.c sources modified after last build)"
- "Run /sync-wiki -- wiki has not been updated since last commit"
- "Run /checkpoint create <name> -- no checkpoint exists for this session"
- "Run /check -- C files were modified but no static analysis has run"

## Stop Conditions

- Do not fail if any directory or artifact does not exist -- report it as missing
- Do not run any build commands -- this command is read-only
- If staleness check finds no stale sources, omit the STALE flag silently

## Success Criteria

- Report printed within 10 seconds
- All sections present even if data is missing
- At least one suggested next action provided
