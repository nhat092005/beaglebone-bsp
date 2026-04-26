# Yocto Patches

Store BSP-level Yocto patch notes or reusable patch queues here.

Recipe patches that BitBake applies directly should normally live beside the recipe:

```text
meta-bbb/recipes-*/<recipe>/<recipe>/files/*.patch
```

Reference those files from `SRC_URI`.
