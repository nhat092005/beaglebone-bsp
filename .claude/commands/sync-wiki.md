---
description: Sync vault/wiki with the current codebase after a feature lands
---

# Sync Wiki

Update `vault/wiki/` to reflect the current state of the codebase. Run after any
feature lands, driver is added, or configuration changes.

**Input**: $ARGUMENTS — optional feature name or scope (e.g. "i2c-sensor driver").
If omitted, infer scope from recent git commits.

---

## Phase 1 -- Determine What Changed

```bash
# Changed files since last wiki-touching commit
git log --oneline -- vault/wiki/ | head -1
LAST_WIKI_COMMIT=$(git log --format="%H" -- vault/wiki/ | head -1)
git diff --name-only "$LAST_WIKI_COMMIT"..HEAD -- \
  drivers/ linux/ u-boot/ freertos/ meta-bbb/ apps/ scripts/ tests/
```

Map changed paths to wiki sections:

| Changed Path     | Wiki Section                    |
| ---------------- | ------------------------------- |
| `drivers/`       | `vault/wiki/drivers/`           |
| `linux/dts/`     | `vault/wiki/kernel/`            |
| `linux/configs/` | `vault/wiki/kernel/`            |
| `linux/patches/` | `vault/wiki/kernel/`            |
| `u-boot/`        | `vault/wiki/bootloader/`        |
| `freertos/`      | `vault/wiki/rtos/`              |
| `meta-bbb/`      | `vault/wiki/yocto/`             |
| `scripts/`       | `vault/wiki/debugging/`         |
| `tests/`         | `vault/wiki/debugging/`         |

If no code changes are detected since the last wiki commit, report "Wiki already
up to date" and stop.

---

## Phase 2 -- Invoke doc-updater Agent

Pass the following context to the `doc-updater` agent:

```
Changed files: <list from Phase 1>
Wiki sections to update: <list from mapping>
Feature scope: <$ARGUMENTS or inferred from git log>

Instructions:
- Update _index.md Last Updated timestamps for each affected section
- Add or update entries for any new drivers, DTS nodes, or recipes
- Do not rewrite existing content unless it is now incorrect
- Match the style and structure of existing wiki files
- vault/wiki/_master-index.md: add entries for any new pages created
```

---

## Phase 3 -- Verify

After the doc-updater agent completes, check:

```bash
# Confirm _index.md files were touched
git diff --name-only | grep "vault/wiki"

# Confirm _master-index.md updated if new pages added
git diff --name-only | grep "_master-index.md"
```

If no `vault/wiki/` files changed, the update did not happen — report failure.

---

## Phase 4 -- Report

```
Wiki Sync Report
================
Scope:    <feature or "general">
Sections updated: kernel | bootloader | drivers | yocto | rtos | debugging

Files changed:
  vault/wiki/drivers/_index.md
  vault/wiki/drivers/<name>.md  (new)
  vault/wiki/kernel/_index.md

Status: COMPLETE
```

---

## Stop Conditions

- Do not delete existing wiki content — only update or extend
- Do not create wiki pages for code that does not yet exist in the repo
- If doc-updater reports it cannot determine what to update, ask the user for scope

## Success Criteria

- At least one `vault/wiki/` file has a new modification time
- `_index.md` for each affected section has updated `Last Updated:` timestamp
- `vault/wiki/_master-index.md` lists any newly created pages

## Related

- Agent: `agents/doc-updater.md` — invoked in Phase 2
- Command: `/status` — shows wiki staleness before and after sync
- Command: `/sdd` — calls `/sync-wiki` as final step after feature lands
