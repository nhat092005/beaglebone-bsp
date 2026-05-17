---
name: gitnexus-refactoring
description: Use for safe rename, extract, split, or refactor work in beaglebone-bsp.
---

1. Use `gitnexus_context` to identify the exact symbol.
2. Run upstream `gitnexus_impact`.
3. For renames, use `gitnexus_rename`; do not use broad find-and-replace.
4. Keep refactors behavior-preserving and scoped.
5. Run `gitnexus_detect_changes` before commit.
