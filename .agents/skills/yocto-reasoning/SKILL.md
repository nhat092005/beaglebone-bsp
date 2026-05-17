---
name: yocto-reasoning
description: Use for meta-bbb Yocto recipes, bbappend decisions, SRC_URI/SRCREV pinning, DEPENDS/RDEPENDS, FILESEXTRAPATHS, layer priority, and BitBake failures.
---

Yocto rules:

- Use a standalone recipe when this repo owns the source/pinning contract.
- Use `.bbappend` only when extending an external recipe already provided by a layer.
- Pin `SRC_URI` and `SRCREV` deliberately.
- Keep `LICENSE` and `LIC_FILES_CHKSUM` accurate.
- Use `DEPENDS` for build-time dependencies and `RDEPENDS:${PN}` for runtime packages.
- For out-of-tree modules, use `inherit module` and confirm kernel build dependency.
- Run BitBake commands inside the Yocto container/shell path described by the Makefile.

Verify with layer listing, recipe lookup, task logs, and `vault/wiki/yocto/`.
