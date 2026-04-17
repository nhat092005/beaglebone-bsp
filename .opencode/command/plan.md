---
description: Produce a short implementation plan with assumptions and verification steps.
argument-hint: "<task description>"
---

Return a plan before coding.

Output format:

1. `Goal`: one-sentence restatement
2. `Scope`: files or directories likely affected
3. `Assumptions`: explicit assumptions
4. `Plan`: 3-6 numbered steps
5. `Verify`: exact commands/checks for done state

Use repo-native verification where possible:

- `make kernel`
- `make uboot`
- `make driver DRIVER=<name>`
- `make bitbake BB=<target>`
- `cppcheck --enable=all --suppress=missingIncludeSystem <file.c>`
- `linux/scripts/checkpatch.pl --strict -f <file.c>`

Do not edit files in this command.
