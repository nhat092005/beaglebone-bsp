---
name: gitnexus-exploring
description: Use to understand beaglebone-bsp architecture or execution flows with GitNexus before grepping broadly.
---

Use GitNexus for relationship-aware exploration:

1. Read `gitnexus://repo/beaglebone-bsp/context` if repo freshness matters.
2. Run `gitnexus_query({repo: "beaglebone-bsp", query: "...", goal: "..."})`.
3. Use `gitnexus_context` on specific symbols when callers/callees matter.
4. Cite files and symbols from GitNexus results.
5. Fall back to `rtk rg` for text-only docs/config references.
