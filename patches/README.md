# BSP Patch Archive

This directory stores BSP-owned patches outside vendor source trees.

Layout:

```text
patches/
├── u-boot/
│   └── <upstream-version>/
│       ├── series
│       └── 0001-example.patch
├── linux/
│   └── <upstream-version>/
│       ├── series
│       └── 0001-example.patch
└── yocto/
    └── README.md
```

Rules:

- Keep vendor trees disposable.
- Keep long-lived project patches here.
- Add a `series` file when patch order matters.
- Use raw `git diff` patches with `git apply`.
- Use `git format-patch` patches with `git am`.
