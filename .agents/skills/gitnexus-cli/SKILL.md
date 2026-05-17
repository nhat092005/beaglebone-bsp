---
name: gitnexus-cli
description: Use for GitNexus index, status, analyze, clean, or wiki CLI tasks in beaglebone-bsp.
---

Use MCP tools first when available. If CLI is needed:

- Prefer `rtk proxy npx gitnexus ...` in this environment.
- Re-index only when GitNexus reports stale data or the task needs current graph truth.
- Do not run expensive analyze/index commands without explaining why.
- Report command, result, and whether the index now matches HEAD.
