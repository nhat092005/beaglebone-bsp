---
description: Run static analysis (cppcheck and kernel checkpatch) on changed C/C++ files. Report issues by severity. Use before committing driver or module code.
---

# Check -- Static Analysis

Run static analysis on C and C++ files changed in this BSP project.

## What This Command Does

1. Find changed C/C++ files via git diff
2. Run cppcheck on those files
3. Run kernel checkpatch on driver files
4. Categorize findings by severity
5. Report results and block on CRITICAL or HIGH issues

## When to Use

Use `/check` when:

- Before committing any change to `drivers/` or `apps/`
- After writing a new kernel module or IRQ handler
- When reviewing code for embedded safety issues
- When `git diff` shows changes to `.c` or `.h` files

## Phase 1 -- Find Changed Files

```bash
git diff --name-only HEAD -- '*.c' '*.h' '*.cpp' '*.hpp'
git diff --staged --name-only -- '*.c' '*.h' '*.cpp' '*.hpp'
```

If no changed C/C++ files found, run against all files under `drivers/` and `apps/`.

## Phase 2 -- Run cppcheck

```bash
cppcheck --enable=all \
         --suppress=missingIncludeSystem \
         --inline-suppr \
         --error-exitcode=1 \
         <list of files or directory>
```

If cppcheck is not installed, report: "cppcheck not found. Install with: sudo apt install cppcheck" and skip this step.

## Phase 3 -- Run Kernel checkpatch (driver files only)

Run checkpatch only if the changed file is inside `drivers/`:

```bash
linux/scripts/checkpatch.pl --no-tree -f <file.c>
```

Or check the staged diff:

```bash
git diff --staged | linux/scripts/checkpatch.pl --no-tree -
```

If `linux/scripts/checkpatch.pl` does not exist, skip this step and note it in the report.

## Phase 4 -- Report

Output format:

```
Static Analysis Report
Files checked: N

[CRITICAL] cppcheck: memory leak at drivers/foo/foo.c:42
  Description: ...
  Fix: Use devm_kzalloc instead of kzalloc

[HIGH] checkpatch: line over 100 characters at drivers/foo/foo.c:88
  Fix: Break the line

[MEDIUM] cppcheck: variable 'ret' assigned but never used at foo.c:15

Summary
  CRITICAL: 0
  HIGH: 1
  MEDIUM: 2
  LOW: 0

Verdict: WARNING -- resolve HIGH issues before committing
```

## Stop Conditions

Do not auto-fix any code. This command reports only. If fixes are needed, invoke the `cpp-reviewer` agent.

## Approval Criteria

| Status  | Condition                         |
| ------- | --------------------------------- |
| PASS    | No CRITICAL or HIGH issues        |
| WARNING | MEDIUM issues only                |
| BLOCK   | Any CRITICAL or HIGH issues found |

## Related

- Agent: `agents/cpp-reviewer.md`
- Skill: `skills/embedded-c-patterns/`
