---
description: Subagent-Driven Development — break an approved plan into atomic tasks and execute each one with a dedicated subagent, two-stage review, and checkpoint on success. Use for new drivers, major features, or multi-file changes.
argument-hint: "<path to plan file | plan text>"
---

# SDD — Subagent-Driven Development

Execute an approved plan task-by-task using focused subagents, with two-stage review
after each task before moving to the next.

Inspired by: Superpowers `subagent-driven-development` skill.
Adapted for: BeagleBone BSP — kernel drivers, DTS, Yocto, FreeRTOS.

**Input**: $ARGUMENTS — path to a plan file produced by `/plan`, or inline plan text.

---

## Prerequisites

Before running `/sdd`, these must be true:

1. `/plan` has been run and user has said "approve" or "go ahead"
2. `/checkpoint create before-<feature-name>` has been created
3. Build baseline is clean: `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)` exits 0

If any prerequisite is missing, stop and tell the user which one to fix first.

---

## Phase 1 — Parse the Plan

Read the plan from $ARGUMENTS. Extract each numbered step into a task list.

Each task must have:

- **Action**: what to do (create file, edit file, add DT node, etc.)
- **Files**: exact file paths affected
- **Verify**: the specific command or check that proves the task is done

If the plan is missing verify conditions, generate them using this table:

| Task type            | Auto-generated verify                                                                                |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| Kernel C file change | `cd linux && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)` exits 0                    |
| DTS change           | `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs` exits 0 (run from linux dir)                 |
| Out-of-tree driver   | `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_DIR=$(pwd)/linux -C drivers/<name>` exits 0 |
| Yocto recipe         | `bitbake -e <recipe>` exits 0 (parse only — full build needs user confirm)                           |
| Shell script         | `bash -n <script.sh>` exits 0                                                                        |
| New file created     | `[ -f <path> ]` exits 0                                                                              |

Print the parsed task list for user review before executing:

```
SDD Task List
=============
Tasks: N

[T1] <action>
     Files: <paths>
     Verify: <command>

[T2] ...

Ready to execute. Type "go" to start, or "stop" to abort.
```

Wait for user to type "go" before proceeding.

---

## Phase 2 — Execute Each Task (Loop)

For each task T(i):

### Step A — Spawn Focused Subagent

Brief the subagent with ONLY what it needs for this task:

```
You are working on task T{i} of {N} in a BeagleBone BSP development session.

TASK: {action}
FILES TO TOUCH: {files}
SUCCESS CONDITION: {verify command exits 0}

CONSTRAINTS:
- Touch ONLY files in scope of this task (Kconfig and Makefile changes are in scope if the task adds a new file)
- Follow kernel coding style (devm_*, negative errno, dev_err)
- No comments unless hardware-non-obvious
- No features beyond what this task requires
- Stop when the verify condition passes — do not continue to next task

Rules: @.claude/rules/workflow.md
Standards: @.claude/rules/coding-standards.md
Hardware context: @.claude/rules/bsp-context.md
Toolchain defaults: @.claude/rules/tech-defaults.md
```

The subagent executes the task and reports back with:

- Files changed (list)
- Diff summary
- Verify command output

### Step B — Stage 1 Review: Spec Compliance

Ask: **"Does this implementation match what the task asked for?"**

Check:

- [ ] Only the listed files were touched
- [ ] The action matches the task description
- [ ] No extra features or refactoring added
- [ ] Verify command passes

If Stage 1 fails: send the subagent back with specific correction instructions.
If the verify build command fails: invoke `build-resolver` agent before retrying.
Maximum 2 retries per task. If still failing after 2 retries → stop, report to user.

### Step C — Stage 2 Review: Code Quality

Invoke `cpp-reviewer` agent if the changed files include `.c`, `.h`, `.dts`, `.dtsi`.
Invoke `reviewer` agent if the changed files include `.sh`, `.bb`, `.bbappend`, `Makefile`.

The reviewer checks ONLY the diff for this task — not the entire codebase.

Block on CRITICAL or HIGH issues. Fix before proceeding.
Log MEDIUM issues in the session report without blocking.

### Step D — Task Checkpoint

If both reviews pass:

```bash
git add -A
git commit -m "feat(<scope>): T{i}/{N} — {task description}"
```

Use conventional commit format. Scope = driver name, dts, yocto, rtos, etc.

Report task completion:

```
✓ T{i}/{N} complete
  Commit: abc1234
  Files: <list>
  Review: PASS (cpp-reviewer: 0 CRITICAL, 0 HIGH)
```

Then proceed to T(i+1).

---

## Phase 3 — Post-Execution Report

After all tasks complete (or on stop):

```
SDD Session Report
==================
Feature: <name>
Tasks:   {completed}/{total}
Status:  COMPLETE | PARTIAL | STOPPED

Completed Tasks
  ✓ T1 — abc1234 — <description>
  ✓ T2 — def5678 — <description>
  ✗ T3 — BLOCKED — <reason>

Medium Issues Logged (non-blocking)
  - drivers/foo/foo.c:42 — variable assigned but not used (cppcheck)

Build Status
  Run /build to verify final artifact.

Next Steps
  1. /build kernel        — verify zImage builds clean
  2. /check               — final static analysis on all changed files
  3. /checkpoint create after-<feature-name>
  4. /sync-wiki           — update vault/wiki with new driver docs
  5. Flash and test on board: bash tests/test-<feature>.sh
```

---

## Stop Conditions

Stop immediately and report if:

- User types "stop" at any point
- A task fails Stage 1 review after 2 retries
- A CRITICAL issue is found in Stage 2 review that cannot be fixed without architectural change
- The verify build command fails and the `build-resolver` agent cannot resolve it

---

## Related

- Command: `/plan` — always run this first to produce the plan `/sdd` executes
- Command: `/checkpoint` — save state before and after a `/sdd` session
- Command: `/build` — verify final artifact after session completes
- Command: `/check` — final static analysis pass after session completes
- Command: `/sync-wiki` — update docs after feature lands
- Agent: `agents/cpp-reviewer.md` — invoked automatically in Stage 2
- Agent: `agents/reviewer.md` — invoked automatically in Stage 2
- Agent: `agents/build-resolver.md` — invoked if build fails during verify
