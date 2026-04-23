---
name: karpathy-discipline
description: Think-before-coding discipline for any non-trivial task. Enforces 4 Karpathy principles (assumption checking, simplicity, surgical changes, goal-driven execution) plus 2 BSP additions (naive-first, definition-of-done). Use for planning, refactors, debugging, code review.
origin: external-karpathy-via-forrestchang
---

# Karpathy Discipline — Think, Plan, Execute

Skill-picker wrapper for `.claude/rules/workflow.md`. Use when the task is non-trivial and you need to anchor on first-principles coding discipline before acting.

## When this skill fires

- Task has >1 ambiguous requirement.
- You are about to write >50 LOC.
- You are about to modify existing working code.
- Debugging a hard-to-reproduce issue.
- User asks "what should we do here?" (open-ended).

## The 6 principles

### 1. Think Before Coding

Surface assumptions. Don't pick silently when multiple interpretations exist. If something is unclear, stop and name the confusion. **BSP corollary**: never guess hardware behavior.

### 2. Simplicity First

Minimum code that solves the problem. No speculative features. "Would a senior kernel engineer say this is overcomplicated?" If yes, simplify. **BSP corollary**: privileged-mode code has no safety net.

### 3. Surgical Changes

Touch only what you must. Don't "improve" adjacent code or comments. Every changed line must trace directly to the request. **BSP corollary**: working kernel drivers are not to be touched unless there's a specific bug.

### 4. Goal-Driven Execution

Transform vague tasks into verifiable success criteria before starting. Strong criteria let you loop independently; weak criteria ("make it work") require constant clarification. Examples in `.claude/rules/workflow.md`.

### 5. Naive First, Optimize Second (BSP)

Write the simplest correct register sequence first. Confirm on hardware. Add DMA / interrupts / performance tweaks only after the naive version is verified.

### 6. Definition of Done (BSP)

A clean build is not "done". For a driver, all 8 RULE-3 gates must pass: checkpatch, sparse, insmod, sysfs, kselftest, 100× cycle, lockdep, KASAN. See `.claude/rules/coding-standards.md` §"Static Analysis Gates".

## Quick self-check

Before saying "done":

- [ ] Did I state my assumptions?
- [ ] Is this the minimum solution?
- [ ] Did I only change what was requested?
- [ ] Do I have a verifiable criterion that proves it works?
- [ ] For drivers: did I list which RULE-3 gates still need running?

## Attribution

Principles 1–4 from Andrej Karpathy ([X post](https://x.com/karpathy/status/2015883857489522876)), packaged as skill by [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) under MIT.
Principles 5–6 added by this project.
Full decision-rule text: `.claude/rules/workflow.md`.
