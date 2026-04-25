---
title: Memory Layout
last_updated: 2026-04-18
category: learning
---

# Memory Layout — Embedded C / Linux Process

## Overview

```
High address ┌─────────────────┐
             │   Stack         │ (grows DOWN, local vars, return addr)
             │        ↓        │
             │   (gap)         │
             │        ↑        │
             │   Heap          │ (grows UP, malloc/free)
             ├─────────────────┤
             │   BSS           │ (global/static, uninitialized = 0)
             ├─────────────────┤
             │   Data          │ (global/static, initialized, not 0)
             ├─────────────────┤
             │   Text (Code)   │ (machine code, read-only)
Low address  └─────────────────┘
```

## Segments

### Text — Code

- Contains: machine code after compilation
- Permissions: **read + execute**, no write
- In Flash (bare-metal) or mapped from ELF (Linux)

```c
void foo(void) { }  // .text
```

### Data — Initialized Global/Static

- Contains: global/static variables with non-zero initializer
- Loaded from Flash to RAM at startup

```c
uint32_t baud_rate = 115200;  // .data
static uint8_t mode = 2;      // .data
```

### BSS — Uninitialized Global/Static

- Contains: global/static = 0 or uninitialized
- **Does not占用 Flash space** — startup code zero-fills only

```c
uint32_t error_count;         // .bss (= 0)
static uint8_t rx_buf[256]; // .bss (256 bytes RAM, 0 bytes Flash)
```

> **Important for embedded:** BSS saves Flash because only size is stored, not data.

### Heap — Dynamic Allocation

- `malloc` / `free` — grows toward stack
- Bare-metal: often very small or **not used** (avoids fragmentation)
- Linux process: mmap, brk system calls

```c
uint8_t *buf = malloc(64);
free(buf);
```

### Stack — Local Variables, Function Calls

- Auto-allocated/free on function entry/exit
- Grows **downward** (ARM, x86)
- Stack overflow (crash)

```c
void foo(void) {
    uint8_t local[128];  // stack, auto-freed on return
}
```

## View with size / readelf

```bash
arm-linux-gnueabihf-size firmware.elf
#    text    data     bss     dec
#   12480     256    1024   13760

# Symbol locations
arm-linux-gnueabihf-nm firmware.elf | grep -E " [bBdDtT] "
# T = .text, D = .data, B = .bss
```

## Bare-metal Startup

```c
// startup.s / crt0 does 3 things before main():
// 1. Copy .data from Flash to RAM
// 2. Zero-fill .bss
// 3. Setup stack pointer
```

## Linker Script (.ld) — Map Segments to Addresses

```ld
/* AM335x example */
MEMORY {
    FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 512K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
}

SECTIONS {
    .text : { *(.text*) } > FLASH
    .data : { *(.data*) } > RAM AT> FLASH
    .bss  : { *(.bss*)  } > RAM
}
```

## Quick Reference

| Segment | Stored In | Contains               | Note                      |
| ------- | --------- | ---------------------- | ------------------------- |
| `.text` | Flash     | Code, `const`          | Read-only, execute        |
| `.data` | Flash to RAM | Global/static not 0      | Copied at startup         |
| `.bss`  | RAM only  | Global/static = 0      | Zero-fill, no Flash       |
| Heap    | RAM       | `malloc`               | Avoid on bare-metal       |
| Stack   | RAM       | Local vars, call chain | Grows down, overflow easy |
