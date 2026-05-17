---
name: bsp-static-check
description: Use before committing or reviewing beaglebone-bsp C, DTS, shell, Makefile, Yocto, or Codex config changes.
---

Run only relevant checks:

- C/C++ driver files: `cppcheck --enable=all --suppress=missingIncludeSystem <file>` and `linux/scripts/checkpatch.pl --strict -f <file>`.
- Shell scripts: `bash -n <file>` and `shellcheck <file>` when available.
- Codex config: parse `.codex/*.toml`, validate `.codex/hooks.json`, run `bash -n .codex/hooks/*.sh`.
- Rules: `codex execpolicy check --pretty --rules .codex/rules/default.rules -- <command>`.
- Docs: grep for stale references and verify links/commands changed by the task.

Report findings by severity: P1 must fix, P2 should fix, P3 optional.
