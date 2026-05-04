# BSP Patch Archive

Standalone kernel patches for non-Yocto builds live here.
U-Boot patches live in `meta-bbb/recipes-bsp/u-boot/files/` and are applied by BitBake.

Layout:

```text
patches/
├── linux/
│   └── README.md
└── yocto/
    └── README.md
```

Rules:

- Linux patches: used by `make kernel` standalone build via `git apply`.
- U-Boot patches: managed by Yocto recipe — do not duplicate here.
- Use `git format-patch` to generate patches.
