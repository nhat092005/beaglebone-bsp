---
name: gitnexus-guide
description: Use when needing GitNexus tool/resource/schema guidance in beaglebone-bsp.
---

Useful resources:

- `gitnexus://repos`
- `gitnexus://repo/beaglebone-bsp/context`
- `gitnexus://repo/beaglebone-bsp/clusters`
- `gitnexus://repo/beaglebone-bsp/processes`
- `gitnexus://repo/beaglebone-bsp/schema`

Prefer high-level tools (`query`, `context`, `impact`, `detect_changes`,
`rename`) before raw Cypher. Use Cypher only for structural queries those tools
cannot answer.
