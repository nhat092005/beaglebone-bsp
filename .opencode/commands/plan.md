---
description: Plan a task before writing any code. Re-anchors workflow rules, surfaces assumptions, defines success criteria, and proposes a step-by-step plan. Run this before every non-trivial coding task.
---

# Plan

Re-anchor workflow rules and produce a verified plan before writing any code.

## Phase 1 -- Re-anchor Rules

Read `.claude/rules/workflow.md` now. Do not skip this step.

The four rules that must hold for this task:

1. Think Before Coding -- state assumptions, ask if uncertain
2. Simplicity First -- minimum code that solves the problem
3. Surgical Changes -- touch only what the task requires
4. Goal-Driven Execution -- define what "done" looks like before starting

## Phase 2 -- Understand the Task

Read the task description from the argument: `$ARGUMENTS`

Then answer these questions in writing before proceeding:

1. What exactly is being asked? Restate it in one sentence.
2. What files or components will be affected?
3. What assumptions am I making? List each one explicitly.
4. Is there anything unclear that requires asking the user before starting?

If anything is unclear, stop here and ask. Do not proceed to Phase 3 until all unclear items are resolved.

## Phase 3 -- State Success Criteria

Define what "done" looks like in verifiable terms.

Examples:

- "make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- exits 0"
- "modprobe <driver> succeeds, dmesg shows no errors"
- "dtc compiles without errors"
- "bitbake <recipe> completes with Build successful"

Write the specific success criteria for this task. Do not use vague criteria like "it works" or "the bug is fixed".

## Phase 4 -- Propose Plan

Write a numbered plan. Each step must have a verify condition.

```
Plan: <task name>

1. [Step] -- verify: [specific check]
2. [Step] -- verify: [specific check]
3. [Step] -- verify: [specific check]

Success: <what the overall done state looks like>
```

Keep the plan to 3-5 steps. If it needs more, the task should be split.

## Stop Conditions

Stop and ask the user if:

- The task description is missing or too vague to produce a plan
- The affected files are unclear
- Any assumption could significantly change the implementation approach

Do not write any code or modify any file during this command.

## Success Criteria

This command succeeds when:

- All assumptions are listed explicitly
- Success criteria are verifiable
- Plan is written and ready for user approval

Wait for user to say "approve" or "go ahead" before writing any code.

## Related

- Rule: `.claude/rules/workflow.md` -- the workflow this command enforces
- Command: `/checkpoint` -- save state after plan is approved and work is done
- Command: `/check` -- run static analysis after implementation
