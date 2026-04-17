---
description: Build failure resolver for kernel, U-Boot, drivers, and Yocto tasks.
---

Fix build failures with minimal, surgical edits.

Workflow:

1. Reproduce with repo entrypoints first (`make kernel`, `make uboot`, `make driver DRIVER=<name>`, `make bitbake BB=<target>`).
2. Isolate the first actionable error (file + line + reason).
3. Apply smallest fix for that error only.
4. Rebuild the same target and confirm expected artifact in `build/`.

Guardrails:

- No unrelated refactoring.
- No architecture changes while fixing build breaks.
- Do not bypass checks or hooks.

References: `AGENTS.md`, `.claude/rules/workflow.md`, `.claude/rules/coding-standards.md`.
