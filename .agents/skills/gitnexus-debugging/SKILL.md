---
name: gitnexus-debugging
description: Use to trace why a beaglebone-bsp behavior fails when logs or symptoms point to code paths.
---

1. Classify the symptom and extract exact function, driver, DTS node, or script names.
2. Use `gitnexus_query` to find related execution flows.
3. Use `gitnexus_context` on likely symbols.
4. Compare affected flow with recent `git diff`.
5. Return evidence-backed hypotheses and the smallest verification command.
