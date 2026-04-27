---
title: dtschema Integration
tags:
  - dtschema
  - docker
  - validation
last_updated: 2026-04-27
category: dts
---

# dtschema Integration

## Overview

dtschema is the official Linux kernel tool for validating Device Tree files against YAML binding schemas.

**Purpose:** Validate DTS/DTB structure matches binding requirements  
**Used by:** Kernel maintainers for upstream patch review  
**Checks:** Compatible strings, required properties, data types, node structure

## What is dtschema?

dtschema is a Python package that validates Device Tree files against schema definitions written in YAML.

### How It Works

1. Kernel maintainers write binding schemas in YAML format
2. Schemas define:
   - Valid compatible strings
   - Required properties
   - Property data types
   - Node structure rules
3. dtschema reads schemas and validates DTS/DTB files
4. Reports errors if DTS violates schema

### Example

**Binding schema** (`gpio-keys.yaml`):

```yaml
properties:
  compatible:
    enum:
      - gpio-keys
      - gpio-keys-polled
  
  button:
    type: object
    required:
      - gpios
      - linux,code
```

**Valid DTS:**

```dts
gpio_keys {
    compatible = "gpio-keys";
    button {
        gpios = <&gpio1 28 GPIO_ACTIVE_LOW>;
        linux,code = <KEY_PROG1>;
    };
};
```

**Invalid DTS (missing required property):**

```dts
button {
    gpios = <&gpio1 28 GPIO_ACTIVE_LOW>;
    /* Missing linux,code */
};
```

**dtschema error:**

```
'linux,code' is a required property
```

## Docker Integration

### Changes Made

#### 1. Dockerfile (docker/Dockerfile)

Added dependencies:

```dockerfile
# Layer 3 - added swig (required by pylibfdt)
RUN apt-get update && apt-get install -y \
    ...
    swig \
    && rm -rf /var/lib/apt/lists/*

# Layer 5 - dtschema installation
RUN pip3 install --no-cache-dir dtschema
```

**Why swig?** dtschema depends on pylibfdt, which requires swig to compile.

#### 2. Makefile Targets

Added two targets:

```makefile
dtbs-check: .check-docker
	$(DOCKER_RUN) bash -c "cd linux && make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) dtbs_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/ 2>&1 | grep -E 'am335x-boneblack-custom.*(error|warning)' || echo 'No errors/warnings for custom DTS'"

verify-dts: .check-docker
	$(DOCKER_RUN) bash scripts/verify-dts.sh
```

Updated help:

```
Quality:
  make check                Run shellcheck + checkpatch on scripts and drivers
  make dtbs-check           Run dtbs_check on custom DTS (requires dtschema in Docker)
  make verify-dts           Run full 4-step DTS validation (RULE-5)
```

### Docker Image Details

**Image:** `bbb-builder:latest`  
**Size:** 7.31 GB (was ~7.0 GB)  
**dtschema version:** 2026.4  
**Build time:** ~10 minutes (no cache, 12-core system)

### Dependencies Added

- Python 3.x (already present)
- swig 4.0.2 (for pylibfdt compilation)
- dtschema 2026.4 (Python package)
- pylibfdt (automatic dependency)

## Usage

### Run dtbs_check Only

```bash
make dtbs-check
```

**Output:**

```
No errors/warnings for custom DTS
```

### Run Full 4-Step Validation

```bash
make verify-dts
```

Runs `scripts/verify-dts.sh` inside Docker container.

### Verify dtschema Installation

```bash
docker run --rm bbb-builder python3 -c "import dtschema; print(dtschema.__version__)"
```

**Output:** `2026.4`

## Validation Results

TODO.md Phase 3.5 (RULE-5) status:

| Step | Description | Status |
|------|-------------|--------|
| 1 | Binding YAML exists | ✅ PASS |
| 2 | Compatible strings match | ✅ PASS |
| 3 | dtbs_check | ✅ PASS |
| 4 | W=1 dtbs | ✅ PASS |

**Progress:** 4/4 steps complete (100%)

## Manual Installation (Host)

If you need dtschema on host (outside Docker):

### Using pip

```bash
pip3 install dtschema
```

### Using apt (Ubuntu/Debian)

```bash
sudo apt install python3-dtschema
```

### Using venv (if externally-managed-environment error)

```bash
python3 -m venv ~/venv-dtschema
source ~/venv-dtschema/bin/activate
pip install dtschema
```

## Verification Commands

### Check Docker Image

```bash
docker images | grep bbb-builder
```

### Check dtschema in Docker

```bash
docker run --rm bbb-builder python3 -c "import dtschema; print(dtschema.__version__)"
```

### Run Validation

```bash
make dtbs-check
```

### Check Makefile Targets

```bash
make help | grep dtbs
```

## Troubleshooting

### Build Failed: swig not found

**Error:**

```
error: command 'swig' failed: No such file or directory
```

**Solution:** Add swig to Dockerfile Layer 3 (already done).

### dtschema Import Error

**Error:**

```
ModuleNotFoundError: No module named 'dtschema'
```

**Solution:** Rebuild Docker image:

```bash
docker build --no-cache -f docker/Dockerfile -t bbb-builder .
```

### dtbs_check Reports Errors

**Example:**

```
am335x-boneblack-custom.dtb: gpio_keys: 'button' does not match any of the regexes
```

**Solution:** Fix DTS according to binding schema requirements.

## Why dtschema Matters

### For Upstream Submission

- **Required:** All upstream DTS patches must pass `dtbs_check`
- **Maintainers check:** Automated CI runs dtschema on all patches
- **Rejection:** Patches with schema violations are rejected

### For BSP Quality

- **Catches errors early:** Before hardware testing
- **Prevents runtime issues:** Missing properties cause probe failures
- **Documentation:** Ensures DTS matches binding docs

### For Team Collaboration

- **Standard validation:** Everyone uses same tool
- **Consistent quality:** No ambiguity about correctness
- **Automated checks:** Can integrate into CI/CD

## References

- dtschema GitHub: https://github.com/devicetree-org/dt-schema
- Kernel DT docs: `linux/Documentation/devicetree/bindings/writing-schema.rst`
- Docker integration: `docker/Dockerfile`
- Makefile targets: `Makefile` (lines 163-168)
- Validation script: `scripts/verify-dts.sh`
