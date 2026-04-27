---
title: DTS Validation (RULE-5)
tags:
  - validation
  - dtbs-check
  - dtschema
last_updated: 2026-04-27
category: dts
---

# DTS Validation - 4-Step Mandatory Sequence (RULE-5)

## Overview

TODO.md Phase 3.5 requires a mandatory 4-step validation for Device Tree Source files before considering them complete.

**Purpose:** Ensure DTS quality before hardware testing and upstream submission.

## Automated Validation

### Using Makefile

```bash
# Run dtbs_check only (Step 3)
make dtbs-check

# Run full 4-step validation
make verify-dts
```

### Using Script Directly

```bash
cd /home/nhat/Working_Space/my-project/beaglebone-bsp
./scripts/verify-dts.sh
```

### Exit Codes

- `0`: All steps PASS
- `1`: One or more steps FAIL (DTS error)
- `2`: One or more steps BLOCKED (missing tools)

## Step 1: Verify Binding YAML Exists

**Purpose:** Ensure all `compatible` strings have binding documentation.

### Manual Check

```bash
# Find compatible strings in DTS
grep -oE 'compatible = "[^"]+"' linux/arch/arm/boot/dts/am335x-boneblack-custom.dts

# Find binding YAML
find linux/Documentation/devicetree/bindings -name '*.yaml' -exec grep -l 'gpio-keys' {} +
```

### PASS Condition

Every `compatible` string has a corresponding YAML binding file.

### What This Catches

- Missing binding documentation
- Undocumented compatible strings
- Typos in compatible string (if binding doesn't exist)

## Step 2: Compatible Strings Match Binding YAML

**Purpose:** Ensure no typos in compatible strings.

### Manual Check

```bash
cd linux

# Check each compatible string
for c in $(grep -hoE 'compatible = "[^"]+"' arch/arm/boot/dts/am335x-boneblack-custom.dts | cut -d'"' -f2); do
  echo "Checking: $c"
  grep -rl "$c" Documentation/devicetree/bindings/ >/dev/null && echo "  ✓ Found" || echo "  ✗ MISSING"
done
```

### PASS Condition

All compatible strings found in bindings.

### What This Catches

- Typos in compatible strings
- Wrong vendor prefix
- Incorrect device name

## Step 3: dtbs_check Against Binding YAML

**Purpose:** Validate entire DTS structure against schema.

### Prerequisites

```bash
# Check dtschema
python3 -c "import dtschema; print(dtschema.__version__)"

# If not installed
pip3 install dtschema
# or
sudo apt install python3-dtschema
```

### Manual Check

```bash
cd linux

# Run dtbs_check
make ARCH=arm dtbs_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/ 2>&1 | \
  grep -E 'am335x-boneblack-custom.*(error|warning)'

# No output -> PASS
```

### Using Docker

```bash
make dtbs-check
```

### PASS Condition

No lines contain `am335x-boneblack-custom` + `error`.

### What This Catches

- Missing required properties (`reg`, `interrupts`, `clocks`)
- Wrong property data types (string vs integer)
- Invalid node names
- Schema violations
- Incorrect property values

### Common Errors

**Error:** `does not match any of the regexes`

**Meaning:** Node name or property doesn't match schema pattern.

**Fix:** Check binding YAML for correct naming convention.

---

**Error:** `is a required property`

**Meaning:** Missing mandatory property.

**Fix:** Add the required property to DTS node.

---

**Error:** `is not of type`

**Meaning:** Wrong data type (e.g., string instead of integer).

**Fix:** Correct the property value type.

## Step 4: W=1 dtbs Produces No New Warnings

**Purpose:** Ensure no new compiler warnings.

### Manual Check

```bash
cd linux

# Compile with W=1
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- W=1 dtbs 2>&1 | \
  grep -ci 'am335x-boneblack-custom.*warning'

# Output = 0 -> PASS
```

### Standalone Compilation

```bash
cpp -nostdinc \
  -I linux/arch/arm/boot/dts \
  -I linux/include \
  -I linux/include/dt-bindings \
  -undef -D__DTS__ \
  -x assembler-with-cpp \
  linux/arch/arm/boot/dts/am335x-boneblack-custom.dts | \
dtc -I dts -O dtb -o /tmp/custom.dtb \
  -W error -W no-unit_address_vs_reg \
  -i linux/arch/arm/boot/dts - 2>&1 | \
grep -i 'am335x-boneblack-custom'

# No output -> PASS
```

### PASS Condition

0 warnings for custom DTS.

### What This Catches

- Deprecated syntax
- Code smells
- Non-optimal configurations
- Potential issues

### Note on Base DTS Warnings

Warnings from base DTS files are upstream issues:
- `am33xx-l4.dtsi`
- `am33xx-clocks.dtsi`
- `am335x-boneblack-common.dtsi`

**These are safe to ignore if:**
- No errors mentioning custom DTS
- DTB compiles successfully
- `dtc` exit code is 0

## Why 4 Steps?

| Step | Checks | Catches |
|------|--------|---------|
| 1 | Binding exists | Missing documentation |
| 2 | String matches | Typos |
| 3 | Schema validation | Structure errors, missing properties |
| 4 | Compiler warnings | Code quality issues |

**Skipping any step risks:**
- Runtime probe failures
- Driver not loading
- Kernel crashes
- Upstream patch rejection

## Current Status (2026-04-27)

```
✅ PASS:    4/4
❌ FAIL:    0/4
⚠️  BLOCKED: 0/4
```

| Step | Status | Note |
|------|--------|------|
| Step 1 | ✅ PASS | gpio-keys binding found |
| Step 2 | ✅ PASS | Compatible strings match |
| Step 3 | ✅ PASS | dtschema in Docker |
| Step 4 | ✅ PASS | 0 warnings |

**Progress:** 100% complete

## Troubleshooting

### dtschema Installation Failed

**Error:** `externally-managed-environment`

**Solution:**

```bash
# Use venv
python3 -m venv ~/venv-dtschema
source ~/venv-dtschema/bin/activate
pip install dtschema

# Or use apt
sudo apt install python3-dtschema
```

### Step 3 Reports Schema Error

**Example:**

```
gpio_keys: 'button' does not match any of the regexes: 'pinctrl-[0-9]+'
```

**Solution:**

1. Read binding YAML:
   ```bash
   cat linux/Documentation/devicetree/bindings/input/gpio-keys.yaml
   ```

2. Understand schema requirements

3. Modify DTS accordingly

4. Rerun validation

### DTB Compilation Failed

**Error:** `Error: /tmp/custom.dtb not generated`

**Solution:**

1. Check syntax:
   ```bash
   cpp -nostdinc -I linux/arch/arm/boot/dts -I linux/include \
     -I linux/include/dt-bindings -undef -D__DTS__ \
     -x assembler-with-cpp \
     linux/arch/arm/boot/dts/am335x-boneblack-custom.dts
   ```

2. Look for errors (missing includes, syntax errors)

3. Fix and retry

## Integration with Build System

### Makefile Targets

```bash
# Compile kernel + DTB
make kernel

# Validate DTS
make dtbs-check

# Full 4-step validation
make verify-dts
```

### Docker Integration

All validation runs inside Docker container with dtschema pre-installed.

Image: `bbb-builder:latest`  
dtschema version: `2026.4`

## References

- Linux DT Specification: https://devicetree.org/specifications/
- Kernel DT bindings: `linux/Documentation/devicetree/bindings/`
- dtschema project: https://github.com/devicetree-org/dt-schema
- Validation script: `scripts/verify-dts.sh`
- TODO.md Phase 3.5: Project validation requirements
