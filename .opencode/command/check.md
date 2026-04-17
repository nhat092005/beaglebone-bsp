---
description: Run repo-standard static checks for changed C and DTS files.
---

Run checks in this order:

1. Collect changed files from staged and unstaged diffs (`*.c`, `*.h`, `*.dts`, `*.dtsi`).
2. For changed C files, run:
   - `cppcheck --enable=all --suppress=missingIncludeSystem <file.c>`
3. For changed C or DTS under kernel/driver scope, run:
   - `linux/scripts/checkpatch.pl --strict -f <file>`

Report findings by severity:

- `CRITICAL`: likely crash/corruption/security risk
- `HIGH`: clear correctness or style blocker for merge
- `MEDIUM`: non-blocking quality issue

Do not auto-fix in this command. If blockers exist, invoke `cpp-reviewer`.
