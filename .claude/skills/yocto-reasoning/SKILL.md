---
name: yocto-reasoning
description: Reasoning scaffold for Yocto/BitBake recipe work. Covers recipe vs bbappend, SRC_URI pinning, inherit module, DEPENDS vs RDEPENDS, machine config, sstate cache, and typical failure modes. Use when writing/modifying recipes, debugging bitbake errors, or extending meta-bbb.
origin: custom-bsp
---

# Yocto Reasoning — meta-bbb layer

A reasoning scaffold. For specifics see `vault/wiki/yocto/` + `docs/05-kernel-config.md`.

## Layer structure

```
meta-bbb/
├── conf/
│   ├── layer.conf                       ← BBFILE_COLLECTIONS, BBFILE_PATTERN
│   └── machine/beaglebone-custom.conf   ← extends beaglebone-yocto
├── recipes-kernel/linux/
│   └── linux-yocto_%.bbappend           ← pulls repo-level kernel patches/configs/dts
├── recipes-drivers/<name>/
│   ├── <name>_1.0.bb                    ← out-of-tree module
│   └── files/...                        ← local patches + sources
├── recipes-apps/<name>/
│   └── <name>_1.0.bb                    ← userspace app
└── recipes-core/images/
    └── bbb-image.bb                     ← target image recipe
```

## Recipe vs bbappend — when to use which

| Situation                                                                 | File type                                           |
| ------------------------------------------------------------------------- | --------------------------------------------------- |
| Build your own out-of-tree driver                                         | new `.bb`                                           |
| Build your own userspace app                                              | new `.bb`                                           |
| Add a patch / config fragment to an existing upstream recipe (`linux-yocto`) | `.bbappend`                                         |
| Override/add files for an existing recipe                                 | `.bbappend` with `FILESEXTRAPATHS:prepend`          |
| Add a new dependency to an image                                          | modify `bbb-image.bb` or write an `.inc`            |

## The SRC_URI pinning rule

Any `git://` or `https://` URL in `SRC_URI` **must** be pinned:

- `SRCREV = "<40-char SHA>"` (not a tag; tags can be moved)
- `LIC_FILES_CHKSUM = "file://COPYING;md5=<md5>"` (computed from actual file in source)

Local `file://` patches do NOT need checksums — they are already tracked in the layer.

Never use floating refs (`${AUTOREV}`, branch names). Reproducibility = license + SHA + LIC_FILES_CHKSUM.

## inherit module — out-of-tree kernel modules

```bitbake
SUMMARY = "PWM fan driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=<md5>"

SRC_URI = "file://Makefile file://pwm-fan.c file://COPYING"
S = "${WORKDIR}"

inherit module
```

`inherit module` handles: cross-compile setup, `do_compile` with kernel headers, `do_install` to `/lib/modules/<kernel>/extra/`. Do NOT write manual install tasks.

## DEPENDS vs RDEPENDS

- `DEPENDS` = recipes needed at **build time** (headers, libraries to link against).
- `RDEPENDS_${PN}` = packages needed at **runtime** (shared libs, binaries called by scripts).

Kernel modules built via `inherit module` implicitly DEPEND on `virtual/kernel`.

## do_ task ordering

```
do_fetch → do_unpack → do_patch → do_configure → do_compile → do_install → do_package → do_package_write_* → do_rootfs (image-level)
```

To add custom work: `do_install:append() { ... }` or `do_compile:prepend() { ... }`. Use `:append` / `:prepend` (colon syntax), not legacy `_append`.

## Variable override rules (critical)

Yocto's variable operators matter:

- `=`  simple assign (last wins)
- `?=` default (first wins)
- `??=` weak default
- `+=` append with space (whitespace-safe)
- `:=` immediate expansion
- `:append` end-of-parse append (use this for most task/var modifications)
- `:prepend` end-of-parse prepend

Order of evaluation: conf files → .bbclass → .bb → .bbappend (in layer priority order).

## Machine config (beaglebone-custom)

```
require conf/machine/beaglebone-yocto.conf

PREFERRED_PROVIDER_virtual/kernel = "linux-yocto"
PREFERRED_VERSION_linux-yocto = "5.10.%"

KERNEL_DEVICETREE = "am335x-boneblack-custom.dtb"
IMAGE_BOOT_FILES = "MLO u-boot.img zImage am335x-boneblack-custom.dtb"
```

## Common bitbake failures

| Error                                       | Fix                                                                                     |
| ------------------------------------------- | --------------------------------------------------------------------------------------- |
| `Nothing PROVIDES 'virtual/kernel'`         | `MACHINE` mis-set in `local.conf` or layer missing from `BBLAYERS`                       |
| `QA Issue: ... installed but not shipped`   | Add files to `FILES:${PN}` or delete in `do_install:append`                              |
| `LIC_FILES_CHKSUM mismatch`                 | License file changed upstream; recompute md5 via `md5sum <file>` and update recipe       |
| `ERROR: Task ... do_patch failed`           | Patch context broken; regenerate with `devtool modify` + `devtool finish`                |
| `ERROR: Nothing RPROVIDES ...`              | Missing recipe or wrong `RDEPENDS`                                                       |

## Verify

```bash
# What recipe provides this package?
bitbake -e bbb-image | grep "^IMAGE_INSTALL"
oe-pkgdata-util find-path /path/to/file

# Layer list
bitbake-layers show-layers

# All recipes providing X
bitbake-layers show-recipes '*kernel*'

# Dry-run package contents
bitbake -c listtasks <recipe>
```

## See also

- `.claude/rules/coding-standards.md` §"Yocto / BitBake".
- `docs/05-kernel-config.md` — kernel config via Yocto.
- `vault/wiki/yocto/_index.md` — layer knowledge.
- `skills/karpathy-discipline/` — think-before-recipe scaffold.
