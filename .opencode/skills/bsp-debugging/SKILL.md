# bsp-debugging

Debugging skill for BeagleBone BSP kernel/runtime/Yocto issues.

Use when debugging:

- kernel oops/panic or probe failures
- DTS binding/pinctrl mismatches
- boot sequence or deployment regressions
- runtime issues on target board

Primary references:

- `.claude/skills/bsp-debugging/SKILL.md`
- `vault/wiki/debugging/_index.md`
- `.claude/rules/bsp-context.md`

Workflow:

1. Gather evidence (logs, device presence, recent diffs)
2. Rank hypotheses
3. Test one hypothesis at a time
4. Confirm root cause before proposing fix

Always include: failing symptom, test performed, observed result, next hypothesis.
