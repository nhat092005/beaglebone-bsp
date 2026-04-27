---
title: Generate Kernel Config
tags:
  - linux
  - kernel
  - kconfig
date: 2026-04-26
category: kernel
---

# Generate Kernel Config

## Base Defconfig

The correct base defconfig for AM335x in v5.10.y is `omap2plus_defconfig`. `am335x_boneblack_defconfig` does not exist in mainline.

```bash
cd linux

# Generate base config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- omap2plus_defconfig
```

## Apply BSP Config Fragment

Use `merge_config.sh`:

```bash
scripts/kconfig/merge_config.sh -m .config configs/boneblack-custom.config
```

Current project caveat: `make kernel` does not merge this fragment today; it
only merges `linux/configs/reproducible.config`. Merge this file manually when
validating the full custom kernel configuration.

## Enable in menuconfig

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
```

---

## Symbol Reference

### GPIO subsystem

#### `CONFIG_GPIOLIB=y`

**Enables:** the GPIO descriptor API (`gpiod_*`), the `gpio_chip` registration framework, and the `gpio_desc` abstraction.

**Required by:** all drivers that touch GPIO lines — gpio-keys, leds-gpio, and out-of-tree `led-gpio` driver.

**Without it:** any driver calling `devm_gpiod_get()` fails to compile.

---

#### `CONFIG_GPIO_SYSFS=y`

**Enables:** the `/sys/class/gpio/` interface — `export`, `unexport`, `direction`, `value`, `edge` sysfs files.

**Required by:** the planned GPIO shell test. `tests/test-gpio.sh` is currently
an empty placeholder in this checkout.

**Without it:** `echo 60 > /sys/class/gpio/export` returns `-sh: write error: Invalid argument`.

---

### I2C subsystem

#### `CONFIG_I2C=y`

**Enables:** the I2C core framework — bus registration, adapter API, and `i2c_client` lifecycle.

**Required by:** `CONFIG_I2C_OMAP`, `CONFIG_I2C_CHARDEV`, and any I2C sensor driver (e.g. SHT3x).

**Without it:** none of the I2C drivers compile.

---

#### `CONFIG_I2C_CHARDEV=y`

**Enables:** the `/dev/i2c-N` character device interface used by `i2cdetect`, `i2cget`, `i2cset`.

**Required by:** the planned I2C shell test. `tests/test-i2c.sh` is currently an
empty placeholder in this checkout.

**Without it:** no `/dev/i2c-*` nodes.

---

#### `CONFIG_I2C_OMAP=y`

**Enables:** the AM335x I2C host controller driver. This driver binds to I2C1 (`0x4802A000`) and I2C2 (`0x4819C000`).

**Required by:** SHT3x sensor on I2C2.

**Without it:** `dmesg | grep i2c` shows no OMAP I2C registrations.

**Note:** I2C0 (`0x44E0B000`) is reserved for the TPS65217 PMIC. Never add custom devices to I2C0.

---

### Hardware monitoring

#### `CONFIG_HWMON=y`

**Enables:** the hwmon core — `/sys/class/hwmon/` bus, `hwmon_device_register()`.

**Required by:** SHT3x hwmon driver (out-of-tree `sht3x` module).

**Without it:** SHT3x driver `hwmon_device_register_with_info()` returns `-ENODEV`.

---

#### `CONFIG_SENSORS_SHT3X=m` (planned)

**Enables:** the Sensirion SHT3x temperature/humidity sensor driver, built as a **loadable module**.

**Why `=m` not `=y`?** Building as a module demonstrates the full `insmod`/`modprobe` workflow.

**Compatible string:** `sensirion,sht3x`

**Note:** The project uses an out-of-tree `sht3x` driver under `drivers/sht3x/`. The in-tree `sht3x` hwmon driver exists but the project implements a custom version for learning purposes.

**On-target:**

```bash
modprobe sht3x
cat /sys/class/hwmon/hwmon*/temp1_input
# expect: integer in millidegrees (e.g. 27000 = 27 C)
cat /sys/class/hwmon/hwmon*/humidity1_input
# expect: integer in milli-percent (e.g. 55000 = 55%)
```

---

### PWM subsystem

#### `CONFIG_PWM=y`

**Enables:** the PWM core framework — `pwm_chip` registration, `/sys/class/pwm/`.

**Required by:** `CONFIG_PWM_TIECAP` and `CONFIG_PWM_TIEHRPWM`.

---

#### `CONFIG_PWM_TIECAP=y`

**Enables:** the AM335x eCAP PWM driver. eCAP is used for single-channel PWM on P9 expansion header.

**Correct symbol name in v5.10.y:** `CONFIG_PWM_TIECAP` (not `PWM_TI_ECAP`).

---

#### `CONFIG_PWM_TIEHRPWM=y`

**Enables:** the AM335x eHRPWM driver. This driver binds to `ehrpwm1` node (base `0x48302200`).

**Required by:** `pwm-led` out-of-tree driver and EHRPWM1A output on P9.14 (GPIO1_18, MUX_MODE6).

**Compatible string in DTS:** `ti,am33xx-ehrpwm`

**On-target:**

```bash
ls /sys/class/pwm/
# expect: pwmchipN
echo 0 > /sys/class/pwm/pwmchip0/export
echo 40000 > /sys/class/pwm/pwmchip0/pwm0/period   # 25 kHz
echo 20000 > /sys/class/pwm/pwmchip0/pwm0/duty_cycle  # 50%
echo 1 > /sys/class/pwm/pwmchip0/pwm0/enable
```

---

### Debug and validation

**Note:** These are for development builds only — significant runtime overhead.

---

#### `CONFIG_DEBUG_FS=y`

**Enables:** debugfs pseudo-filesystem at `/sys/kernel/debug/`.

**Required by:** `CONFIG_PROVE_LOCKING` outputs lock dependency graph to debugfs.

---

#### `CONFIG_DEBUG_KERNEL=y`

**Enables:** master gate for all kernel debug options.

**Required by:** `CONFIG_PROVE_LOCKING` and `CONFIG_KASAN`.

---

#### `CONFIG_PROVE_LOCKING=y`

**Enables:** lockdep — runtime lock dependency validator. Tracks lock acquisition order.

**Why included:** validates GPIO-OMAP patch eliminates deadlock path.

**Runtime cost:** ~10–15% throughput reduction, ~200 KiB extra RAM.

---

#### `CONFIG_KASAN=y`

**Enables:** Kernel Address Sanitizer — catches out-of-bounds, use-after-free, use-after-return.

**Why included:** catches memory bugs in new driver code during development.

**Runtime cost:** 2–3× RAM increase (~1 MB on BBB), ~50% slowdown.

---

## Summary Table

| Symbol                  | Value | Subsystem | Required for       |
| ----------------------- | ----- | --------- | ------------------ |
| `CONFIG_GPIOLIB`        | `y`   | GPIO      | All GPIO drivers   |
| `CONFIG_GPIO_SYSFS`     | `y`   | GPIO      | planned GPIO test |
| `CONFIG_I2C`            | `y`   | I2C       | I2C core           |
| `CONFIG_I2C_CHARDEV`    | `y`   | I2C       | /dev/i2c-\*        |
| `CONFIG_I2C_OMAP`       | `y`   | I2C       | AM335x I2C1+I2C2   |
| `CONFIG_HWMON`          | `y`   | hwmon     | hwmon core         |
| `CONFIG_PWM`            | `y`   | PWM       | PWM core           |
| `CONFIG_PWM_TIECAP`     | `y`   | PWM       | AM335x eCAP        |
| `CONFIG_PWM_TIEHRPWM`   | `y`   | PWM       | eHRPWM, pwm-led    |
| `CONFIG_SENSORS_SHT3X`  | `m`   | hwmon     | SHT3x sensor (planned) |
| `CONFIG_DEBUG_FS`       | `y`   | debug     | debugfs            |
| `CONFIG_DEBUG_KERNEL`   | `y`   | debug     | Gate for debug     |
| `CONFIG_PROVE_LOCKING`  | `y`   | debug     | Lockdep            |
| `CONFIG_KASAN`          | `y`   | debug     | Memory safety      |

---

## Verify Merged Config

```bash
cd linux

# All 13 symbols present (SHT3x not yet in fragment)
grep -E '^CONFIG_(GPIOLIB|GPIO_SYSFS|I2C|I2C_CHARDEV|I2C_OMAP|HWMON|PWM|PWM_TIECAP|PWM_TIEHRPWM|DEBUG_FS|DEBUG_KERNEL|PROVE_LOCKING|KASAN)=' .config | wc -l
# expect: 13
```

---

## References

- Kernel Kconfig: https://www.kernel.org/doc/html/latest/kbuild/kconfig-language.html
