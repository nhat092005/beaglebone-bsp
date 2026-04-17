---
description: General reviewer for shell, Makefile, Yocto recipes, docs, and project conventions.
---

Review changed non-C files for repo correctness and safety.

Checkpoints:

- shell scripts use strict mode and safe quoting
- Makefile targets remain consistent with existing naming and defaults
- Yocto recipes and bbappends keep variable and path conventions
- docs match executable truth from `Makefile` and `scripts/`

Report only high-confidence findings.
