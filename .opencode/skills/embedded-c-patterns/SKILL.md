# embedded-c-patterns

Embedded C patterns for Linux drivers, FreeRTOS code, and Yocto integration.

Use when writing/modifying:

- kernel module logic in `drivers/`
- DTS-related C interactions
- RTOS support code
- recipe-adjacent C build integration

Primary references in this repo:

- `.claude/skills/embedded-c-patterns/SKILL.md`
- `.claude/rules/coding-standards.md`
- `.editorconfig` and `.clang-format`

Non-negotiables:

- minimal changes only
- no speculative abstractions
- IRQ-safe patterns
- negative errno and clear error paths

Validation helpers:

- `cppcheck --enable=all --suppress=missingIncludeSystem <file.c>`
- `linux/scripts/checkpatch.pl --strict -f <file.c>`
