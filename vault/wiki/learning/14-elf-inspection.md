---
title: ELF Binary Inspection
last_updated: 2026-04-18
category: learning
---

# ELF Binary Inspection

Tools: `readelf`, `objdump`, `file`, `nm`, `size` — for ARM cross-compiled binaries.

## file — Quick Identification

```bash
file hello
# hello: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV),
#        dynamically linked, interpreter /lib/ld-linux-armhf.so.3,
#        BuildID[sha1]=abc123, not stripped
```

| Field                | Meaning                            |
| -------------------- | ---------------------------------- |
| `32-bit LSB`         | 32-bit, Little-Endian              |
| `ARM, EABI5`         | ARM architecture, ABI version 5    |
| `dynamically linked` | Needs glibc at runtime (Linux app) |
| `statically linked`  | Self-contained, no external libs   |
| `not stripped`       | Has debug symbols                  |

## readelf — ELF Structure

```bash
# Header — overview
readelf -h firmware.elf
# Entry point address: 0x80000000
# Type: EXEC
# Machine: ARM

# Sections — data regions in binary
readelf -S firmware.elf
# Name      Type    Addr        Size
# .text     PROGBITS 0x00000000 0x03000
# .data     PROGBITS 0x20000000 0x00100
# .bss      NOBITS   0x20000100 0x00400

# Segments (program headers)
readelf -l firmware.elf

# Symbols
readelf -s firmware.elf | grep -E "main|uart|gpio"
```

## objdump — Disassembly

```bash
# Disassemble entire code
objdump -d firmware.elf

# Disassemble + source (needs -g)
objdump -dS firmware.elf

# Specific section
objdump -d -j .text firmware.elf
objdump -s -j .rodata firmware.elf

# ARM cross binary
arm-linux-gnueabihf-objdump -d hello
arm-none-eabi-objdump -d firmware.elf
```

## nm — Symbol List

```bash
nm firmware.elf
# 20000000 D baud_rate      D = .data (initialized global)
# 20000004 B rx_buffer      B = .bss (uninitialized)
# 00001234 T uart_send     T = .text (function)
# 00000000 t helper_func  t = .text local (static)

nm --size-sort firmware.elf | tail -10  # 10 largest symbols
nm -u hello                          # Undefined (needs external lib)
```

## size — Segment Summary

```bash
arm-none-eabi-size firmware.elf
#    text    data     bss     dec     hex
#   12480     256    1024   13760    35C0

# Flash usage = text + data
# RAM usage   = data + bss
```
