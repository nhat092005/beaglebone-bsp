# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Target: AM335x (BeagleBone Black) | Cross-compile: `arm-linux-gnueabihf-` | Kernel: ARMv7-A

## Quick Build Reference

```bash
# Kernel
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_boneblack_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc) zImage dtbs modules

# U-Boot
make CROSS_COMPILE=arm-linux-gnueabihf- am335x_evm_defconfig
make CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)

# Yocto
source poky/oe-init-build-env build && bitbake core-image-minimal

# Out-of-tree driver
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_DIR=$(pwd)/linux -C drivers/<name>
```

## Static Analysis

```bash
# Kernel coding style check (run from linux/)
scripts/checkpatch.pl --strict -f <file.c>

# C static analysis
cppcheck --enable=all --suppress=missingIncludeSystem <file.c>
```

`.clang-format` at the repo root enforces kernel coding style. Format changed files with:

```bash
clang-format -i <file.c>
```

## Tests

On-target integration tests live in `tests/`. Run a single test over SSH:

```bash
bash tests/test-gpio.sh
bash tests/test-i2c.sh
bash tests/test-pwm.sh
```

Connect to the board first: `minicom -D /dev/ttyUSB0 -b 115200` (8N1, ttyO0).

## Git Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Commit messages drive changelog generation via `cliff.toml`:

```
feat(driver): add PWM fan driver for AM335x EHRPWM
fix(dts): correct UART0 pinmux reg address
docs(wiki): update I2C sensor wiring notes
```

## Custom Slash Commands

| Command       | What it does                                                                         |
| ------------- | ------------------------------------------------------------------------------------ |
| `/plan`       | Re-anchor workflow rules, surface assumptions, define success criteria before coding |
| `/sdd`        | Subagent-Driven Development: execute an approved plan task-by-task with subagents    |
| `/build`      | Auto-detect context and run the right build (kernel / U-Boot / Yocto / driver / app) |
| `/check`      | Run cppcheck + kernel checkpatch on changed C files                                  |
| `/status`     | Project health snapshot: git state, build artifacts, wiki status                     |
| `/checkpoint` | Create a named git checkpoint before a risky change                                  |
| `/sync-wiki`  | Sync `vault/wiki/` with the current codebase — runs doc-updater agent                |

## Project Layout

```
beaglebone-bsp/
├── apps/           # Userspace applications (gstreamer-demo, qt-hmi, sensor-monitor)
├── drivers/        # Out-of-tree kernel modules (i2c-sensor, led-gpio, pwm-fan)
├── freertos/       # FreeRTOS + OpenAMP firmware
├── linux/          # Linux kernel source (configs/, dts/, patches/)
├── meta-bbb/       # Yocto BSP layer (recipes-apps/, recipes-drivers/, recipes-kernel/)
├── scripts/        # build.sh, deploy.sh, flash_sd.sh
├── tests/          # On-target shell test scripts
├── u-boot/         # U-Boot source (configs/, patches/)
├── vault/wiki/     # Project knowledge base (bootloader/, debugging/, drivers/, kernel/, rtos/, yocto/)
└── .claude/        # Agents, commands, rules, skills
```

## Agents

| Agent            | When to use                                                 |
| ---------------- | ----------------------------------------------------------- |
| `researcher`     | Before implementing an unfamiliar peripheral or subsystem   |
| `architect`      | When planning a new driver or major feature                 |
| `cpp-reviewer`   | After writing or modifying any C/C++ code                   |
| `reviewer`       | General review: DTS, Makefile, shell scripts, Yocto recipes |
| `build-resolver` | When Yocto, kernel, or U-Boot build fails                   |
| `debugger`       | When tracking a runtime bug or kernel oops                  |
| `doc-updater`    | After completing a feature -- sync vault/wiki               |

## Reference Files (read when relevant)

- Hardware addresses, boot sequence: `.claude/rules/bsp-context.md`
- Toolchain flags, defconfigs, serial console: `.claude/rules/tech-defaults.md`

---

@.claude/rules/workflow.md
@.claude/rules/coding-standards.md
