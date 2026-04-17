---
description: Execute an approved plan task-by-task with focused subagents and verification gates.
argument-hint: "<path to plan file | plan text>"
---

Run Subagent-Driven Development for multi-file work.

Process:

1. Parse `$ARGUMENTS` into atomic tasks (action, files, verify).
2. Execute one task at a time with a focused subagent.
3. Verify each task with explicit commands.
4. Run diff review before moving to next task:
   - `cpp-reviewer` for `.c/.h/.dts/.dtsi`
   - `reviewer` for `.sh/.bb/.bbappend/Makefile/docs`
5. Stop on blockers and report clearly.

Use repo-native verification commands (`make kernel`, `make uboot`, `make driver`, `make bitbake`, `cppcheck`, `checkpatch`).

After completion, recommend `/build`, `/check`, and `/sync-wiki`.
