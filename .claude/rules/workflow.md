# Workflow Rules — Think, Plan, Execute

Behavioral guidelines to reduce common LLM coding mistakes in this BSP project.
Derived from Karpathy's observations: https://x.com/karpathy/status/2015883857489522876

**Tradeoff:** These guidelines bias toward caution over speed. For trivial edits, use judgment.

---

## 1. Think Before Coding

**Do not assume. Do not hide confusion. Surface tradeoffs.**

Before implementing:

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them -- do not pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what is confusing. Ask.

BSP note: Hardware behavior is not always guessable. A wrong assumption about a
register bit, IRQ polarity, or pinmux mode can brick the board or cause silent
malfunction. Always ask before assuming hardware behavior.

---

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that was not requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior kernel engineer say this is overcomplicated?" If yes, simplify.

BSP note: Kernel code runs in privileged mode. Every unnecessary line is a potential
bug with no safety net. A driver that works in 100 lines must not be extended to 400
"just in case."

---

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Do not "improve" adjacent code, comments, or formatting.
- Do not refactor things that are not broken.
- Match existing kernel coding style -- not your preference.
- If you notice unrelated dead code, mention it -- do not delete it.

When your changes create orphans:

- Remove includes, variables, or functions that YOUR changes made unused.
- Do not remove pre-existing code unless explicitly asked.

The test: **Every changed line should trace directly to the user's request.**

BSP note: A working kernel driver must not be touched unless there is a specific
bug to fix. A side-effect edit can cause silent hardware malfunction.

---

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform vague tasks into verifiable goals:

| Instead of        | Say                                                                               |
| ----------------- | --------------------------------------------------------------------------------- |
| "Fix the build"   | "`make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-` exits 0"                      |
| "Fix the driver"  | "Module loads with `modprobe`, `dmesg` shows no errors, `/sys/class/...` appears" |
| "Add DT support"  | "`dtc` compiles without errors, device appears in `/proc/device-tree/`"           |
| "Fix Yocto error" | "`bitbake <recipe>` completes with `Build successful`"                            |
| "Fix the oops"    | "`dmesg` shows no errors, driver probe succeeds, `/sys/` entry exists"            |

Strong success criteria let you loop independently. Weak criteria ("make it work")
require constant clarification.

For multi-step tasks, state a plan before starting:

```
1. [Step] -- verify: [check command or observable output]
2. [Step] -- verify: [check command or observable output]
3. [Step] -- verify: [check command or observable output]
```

---

## 5. Naive First, Optimize Second

**Write the simplest correct solution first. Optimize only when needed.**

From Karpathy: _"Write the naive algorithm that is very likely correct first,
then ask it to optimize it while preserving correctness."_

For BSP work:

- Implement the straightforward register read/write sequence first (even if slow).
- Confirm it works on hardware before adding DMA, interrupts, or performance tweaks.
- Add complexity only once the simple version is verified correct.

This applies to: driver probe sequences, DT node structure, U-Boot environment scripts,
FreeRTOS task logic, and Yocto recipe dependencies.

---

## 6. Definition of Done

A clean build does not mean it's done. A task is not complete until:

**Driver / kernel module (all 8 RULE-3 gates must pass):**

- `checkpatch.pl --strict` → 0 errors, 0 warnings
- `sparse C=2` → 0 warnings
- `insmod` succeeds with no errors in `dmesg`
- `/sys/` or `/dev/` entry appears as expected
- Relevant kselftest or kunit test passes
- 100× `insmod` / `rmmod` loop exits 0
- `CONFIG_PROVE_LOCKING=y` build: no lockdep splat
- `CONFIG_KASAN=y` build: no KASAN report
- Functionality verified by a test script or userspace app

**DTS change:**

- `dtc` compiles without warnings
- Device appears in `/proc/device-tree/`
- Driver binds successfully (`dmesg` shows `probe` OK)

**Yocto recipe:**

- `bitbake <recipe>` returns "Build successful"
- Package is present in rootfs, installed to the correct path

**Bug fix:**

- Root cause identified — not just warning suppressed
- `dmesg` shows no related errors
- Regression check: related features still work

Never claim "works" based on compile alone.
Always end with: "Build is clean — please test on the board."

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites
due to overcomplication, and clarifying questions come before implementation rather
than after mistakes.

---

## Attribution

Principles 1–4 derive from Andrej Karpathy's observations on LLM coding pitfalls:

- X post: https://x.com/karpathy/status/2015883857489522876
- Skill wrapper repo: https://github.com/forrestchang/andrej-karpathy-skills (MIT-licensed)

Principles 5–6 are BSP-specific additions by this project.

For a skill-picker-discoverable version of these principles, see
`.claude/skills/karpathy-discipline/SKILL.md`.
