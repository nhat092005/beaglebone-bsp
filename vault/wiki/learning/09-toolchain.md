---
title: Toolchain — arm-none-eabi vs arm-linux-gnueabihf
last_updated: 2026-04-18
category: learning
---

# Toolchain — arm-none-eabi vs arm-linux-gnueabihf

## Reading Toolchain Name

```
arm  -  none  -  eabi
  │       │        └─ ABI: Embedded Application Binary Interface
  │       └────────── OS: none (no OS, bare-metal)
  └────────────────── Arch: ARM

arm  -  linux  -  gnueabihf
  │        │          └─ hf: hardware float (FPU), EABI calling convention
  │        └──────────── OS: Linux
  └─────────────────────── Arch: ARM
```

## Comparison

|                 | `arm-none-eabi`                  | `arm-linux-gnueabihf`                    |
| --------------- | -------------------------------- | ---------------------------------------- |
| **Purpose**     | Bare-metal, RTOS                 | Linux userspace, kernel module           |
| **OS target**   | No OS                            | Linux                                    |
| **C library**   | `newlib` (small)                 | `glibc` (full)                           |
| **Syscalls**    | None                             | `open`, `read`, `mmap`...                |
| **Output**      | `.elf` runs directly on MCU      | ELF runs on Linux process                |
| **Startup**     | Write `startup.s`, linker script | `glibc` handles (`crt0`, dynamic linker) |
| **Use for BBB** | FreeRTOS / PRU firmware          | App, driver, kernel                      |

## What Happens If You Use Wrong

```bash
# arm-linux-gnueabihf for bare-metal
# Binary links glibc calls Linux syscalls crashes immediately

# arm-none-eabi for Linux app
# No glibc missing printf, malloc linker error
```

## Real Usage on BeagleBone Black

```bash
# Kernel + U-Boot + Linux app (arm-linux-gnueabihf)
export CROSS_COMPILE=arm-linux-gnueabihf-
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE am335x_evm_defconfig
make ARCH=arm CROSS_COMPILE=$CROSS_COMPILE zImage dtbs -j4

# FreeRTOS / PRU / bare-metal demo (arm-none-eabi)
export CROSS_COMPILE=arm-none-eabi-
make CROSS_COMPILE=$CROSS_COMPILE all
```

## Verify Correct Toolchain

```bash
file firmware.elf
# arm-none-eabi:       ELF 32-bit LSB executable, ARM, statically linked, not stripped
# arm-linux-gnueabihf: ELF 32-bit LSB executable, ARM, dynamically linked,
#                    interpreter /lib/ld-linux-armhf.so.3

arm-none-eabi-readelf      -d firmware.elf | grep "Shared"  # empty (no shared lib)
arm-linux-gnueabihf-readelf -d app.elf     | grep "Shared"  # libgcc, libc...
```

## hf vs no hf

```bash
arm-linux-gnueabi      # Soft-float: FPU emulated in software (slow)
arm-linux-gnueabihf    # Hard-float: Uses FPU hardware (VFP/NEON) (faster)

# AM335x Cortex-A8 has NEON FPU (always use hf)
```

## Quick Reference

```
Writing code for...
├── MCU without OS (STM32, bare AM335x PRU) arm-none-eabi
├── FreeRTOS                                  arm-none-eabi
├── U-Boot                                    arm-linux-gnueabihf
├── Linux kernel / driver                     arm-linux-gnueabihf
└── Linux userspace app                       arm-linux-gnueabihf
```
