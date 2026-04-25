---
title: Apply Kernel Patches
tags:
  - linux
  - patch
  - git
date: 2026-04-19
category: kernel
---

# Kernel Patches (Stable Tree Backport)

## Background: Stable Tree

The kernel has two trees:

| Tree     | URL                             | Purpose          |
| -------- | ------------------------------- | ---------------- |
| Mainline | `git.kernel.org/torvalds/linux` | New development  |
| Stable   | `git.kernel.org/stable/linux`   | Bugfix backports |

**This project:** tracks `linux-5.10.y` at tag `v5.10.253`

Stable commits follow format:

```
commit <mainline-sha> ("<subject>") upstream.
```

---

## Find a Relevant Patch

### Method A: Search stable branch log

```bash
cd linux
git log --oneline --grep="gpio.*omap" v5.10.252..v5.10.253
```

### Method B: Search lore.kernel.org

```
https://lore.kernel.org/stable/
```

Search query: `gpio omap driver probe`

### Method C: grep stable branch

```bash
cd linux
git log --oneline origin/linux-5.10.y -- drivers/gpio/gpio-omap.c | head -10
```

### Selection Criteria

A patch qualifies if:

1. **Affects hardware** — AM335x GPIO, I2C, PWM, UART, eMMC, USB
2. **Has a `Fixes:` tag** pointing to a real commit
3. **In stable queue** or merged in newer `v5.10.x`
4. **Commit message explains the bug**
5. **Small diff** — under ~100 lines

---

## Locate the Stable Commit SHA

```bash
cd linux
git log --oneline --all | grep "gpio: omap: do not register"
# expect: 57bcd3feffa7 gpio: omap: do not register driver in probe()
```

**This project's fix:**

- Stable SHA: `57bcd3feffa79544c73a1a1872472389a391cc79`
- Upstream SHA: `730e5ebff40c852e3ea57b71bf02a4b89c69435f`
- Subject: `gpio: omap: do not register driver in probe()`

---

## Fetch the Commit (Shallow Clone Issue)

A `--depth=1` clone may not contain target commits:

```bash
cd linux
git cat-file -t 57bcd3feffa7
# If: "fatal: Not a valid object name" → deepen

git fetch --deepen=5000 \
    https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
    linux-5.10.y

git cat-file -t 57bcd3feffa7
# expect: commit
```

---

## BSP Patches Location

```
linux/patches/
├── 0001-gpio-omap-fix-irq-unmask-on-resume.patch
```

---

## Generate Patch File

```bash
cd linux
git format-patch -1 57bcd3feffa7 --stdout \
    > patches/0001-gpio-omap-fix-irq-unmask-on-resume.patch
```

The `commit HASH ("title") upstream.` line is mandatory for stable backports.

---

## Verify Trailer Count

Stable rules require:

- At least one `Fixes:` tag
- At least one `Signed-off-by:`
- `Signed-off-by:` from stable maintainer

```bash
grep -cE '^(Fixes|Signed-off-by|Cc: stable):' patches/0001-*.patch
# expect: integer ≥ 3
```

This patch has: 2 Fixes: + 3 Signed-off-by: = 5 ✓

---

## Run checkpatch

```bash
cd linux
scripts/checkpatch.pl --strict \
    --ignore=GIT_COMMIT_ID,COMMIT_LOG_LONG_LINE,UNKNOWN_COMMIT_ID,BAD_SIGN_OFF \
    patches/0001-*.patch
# expect: total: 0 errors, 0 warnings
```

### Checkpatch False Positives

| Type                   | Root cause                                            | Why not fixable             |
| ---------------------- | ----------------------------------------------------- | --------------------------- |
| `GIT_COMMIT_ID`        | Mainline SHA absent from shallow clone                | Cannot add mainline commits |
| `COMMIT_LOG_LONG_LINE` | Required `commit HASH ("title") upstream.` > 75 chars | Format is mandatory         |
| `UNKNOWN_COMMIT_ID` ×4 | Fixes: SHAs absent from shallow clone                 | Fixes: tags are correct     |
| `BAD_SIGN_OFF`         | Parenthetical affiliation                             | Upstream attribution        |

---

## Apply Patch Locally

```bash
cd linux
git apply patches/0001-gpio-omap-fix-irq-unmask-on-resume.patch
```

Verify hunk applied:

```bash
grep -n 'platform_driver_unregister.*mpuio' drivers/gpio/gpio-omap.c
# expect: two matching lines
```

Verify compiles:

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- drivers/gpio/gpio-omap.o
# expect: CC drivers/gpio/gpio-omap.o
```

---

## Apply (Simple)

```bash
cd linux
git apply ../linux/patches/0001-gpio-omap-fix-irq-unmask-on-resume.patch
```

---

## Verify Patch Applied

```bash
git log --oneline -1
git diff --stat
```

---

## Revert a Patch

```bash
cd linux
git checkout -- .
```

---

## Format for Upstream Submission

### Commit message requirements

```
subsystem: component: short description (< 70 chars)

Longer description explaining what bug and why fix is correct.

Link: https://lore.kernel.org/...
Fixes: <12-char-sha> ("<original commit subject>")
Cc: stable@vger.kernel.org
Signed-off-by: Your Name <your@email.com>
```

### Generate with cover letter

```bash
git format-patch -1 --cover-letter --thread -o outgoing/
```

### Run checkpatch

```bash
scripts/checkpatch.pl --strict outgoing/0001-*.patch
# must be: 0 errors, 0 warnings
```

### Submit via git-send-email

```bash
git send-email \
    --to=linux-gpio@vger.kernel.org \
    --cc=stable@vger.kernel.org \
    outgoing/0001-*.patch
```

---

## Quick Reference

| Task              | Command                                                  |
| ----------------- | -------------------------------------------------------- | ------------- | ------------------------- |
| Verify stable SHA | `git cat-file -t <sha>` → `commit`                       |
| Deepen            | `git fetch --deepen=5000 <url> linux-5.10.y`             |
| Generate patch    | `git format-patch -1 <sha> --stdout > name.patch`        |
| Check trailer     | `grep -cE '^(Fixes                                       | Signed-off-by | Cc: stable):' name.patch` |
| Run checkpatch    | `scripts/checkpatch.pl --strict --ignore=... name.patch` |
| Apply             | `git apply name.patch`                                   |

---

## References

- Linux stable rules: https://www.kernel.org/doc/html/latest/process/stable-kernel-rules.html
