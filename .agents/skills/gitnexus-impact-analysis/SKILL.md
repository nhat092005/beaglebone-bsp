---
name: gitnexus-impact-analysis
description: Use before modifying functions, classes, methods, or shared symbols in beaglebone-bsp.
---

Before editing a symbol:

1. Run `gitnexus_impact({repo: "beaglebone-bsp", target: "<symbol>", direction: "upstream"})`.
2. Report direct callers, affected processes, modules, and risk level.
3. If risk is HIGH or CRITICAL, warn the user before proceeding.
4. Use `gitnexus_context` for ambiguous symbol names.
5. Before committing, run `gitnexus_detect_changes({repo: "beaglebone-bsp", scope: "all"})`.
