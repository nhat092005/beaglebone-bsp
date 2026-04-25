---
title: Struct Packing
last_updated: 2026-04-18
category: learning
---

# Struct Packing — Alignment, Padding, `__attribute__((packed))`

## Problem: Compiler Adds Padding

```c
struct Foo {
    uint8_t  a;   // 1 byte
    uint32_t b;   // 4 bytes
    uint8_t  c;   // 1 byte
};
// sizeof(Foo) = 12 (NOT 6!)
```

```
Offset: 0    1    2    3    4    5    6    7    8    9   10   11
        [a] [pad pad pad] [    b    b    b    b   ] [c] [pad pad pad]
```

Compiler adds padding so **b is at address divisible by 4** CPU accesses faster (aligned).

## Default Alignment Rule

> Each member is placed at offset **divisible by its own `sizeof`**.  
> Struct size is **multiple of largest member**.

```c
struct A { uint8_t a; uint16_t b; uint8_t c; };
// a @ 0, pad @ 1, b @ 2, c @ 4, pad @ 5 sizeof = 6

struct B { uint16_t b; uint8_t a; uint8_t c; };
// b @ 0, a @ 2, c @ 3 sizeof = 4 (reorder saves RAM)
```

**Tip:** Order members **largest to smallest** to reduce padding.

## `__attribute__((packed))` — Remove All Padding

```c
struct __attribute__((packed)) Frame {
    uint8_t  start;    // @ 0
    uint16_t id;       // @ 1 (unaligned)
    uint32_t data;     // @ 3 (unaligned)
    uint8_t  crc;      // @ 7
};
// sizeof = 8 (no padding)
```

**Use when:**

- Parse network/protocol packet from raw byte buffer
- Map to hardware register with fixed layout
- UART/SPI/I2C communication with external device

**Cost:**

```c
// ARM Cortex-A8: unaligned access CPU trap (slow or crash)
struct __attribute__((packed)) Foo { uint8_t a; uint32_t b; };
Foo f;
uint32_t x = f.b;  // Compiler generates byte-by-byte read — slow
```

> Do NOT use `packed` for internal structs just to save RAM — reorder members instead.

## `#pragma pack` — Portable Alternative

```c
#pragma pack(push, 1)
struct UartFrame {
    uint8_t  header;
    uint16_t length;
    uint8_t  payload[64];
};
#pragma pack(pop)
```

## offsetof / sizeof — Verify Layout

```c
#include <stddef.h>

printf("sizeof  = %zu\n", sizeof(struct Foo));
printf("offset a = %zu\n", offsetof(struct Foo, a));
printf("offset b = %zu\n", offsetof(struct Foo, b));
```

## Real Pattern — Parse Protocol Packet

```c
// CORRECT: packed to map raw buffer
typedef struct __attribute__((packed)) {
    uint8_t  cmd;
    uint16_t addr;
    uint32_t value;
    uint8_t  checksum;
} ModbusFrame_t;  // sizeof = 8

uint8_t raw[8] = { 0x03, 0x00, 0x10, ... };
ModbusFrame_t *frame = (ModbusFrame_t *)raw;  // Direct map
```

## Quick Reference

| Technique                 | Use When                      |
| ------------------------- | ----------------------------- |
| Reorder largest to smallest | Save RAM, keep performance |
| `__attribute__((packed))` | Map byte stream / HW register |
| `#pragma pack(1)`         | Like packed, more portable    |
| `offsetof()`              | Debug/verify actual layout    |
| `static_assert`           | Compile-time size check       |

```c
// Verify at compile time
static_assert(sizeof(ModbusFrame_t) == 8, "Wrong frame size");
```
