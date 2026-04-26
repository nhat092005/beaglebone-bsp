# Linux Patches

Store Linux kernel patch queues here, grouped by upstream/kernel base.

Example:

```text
patches/linux/v5.10.y-cip/
├── series
└── 0001-example.patch
```

Yocto recipe-specific kernel patches may also live under `meta-bbb/recipes-kernel/.../files/` when BitBake must apply them directly.
