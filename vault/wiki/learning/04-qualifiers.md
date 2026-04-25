---
title: Qualifiers — volatile, const, static, extern
last_updated: 2026-04-18
category: learning
---

# Qualifiers — volatile, const, static, extern

Embedded C qualifiers for hardware interaction.

## volatile

Prevents compiler from caching variable in register. Use when variable changes **outside main code flow**.

```c
volatile uint8_t flag;        // Shared with ISR
*(volatile uint32_t*)0x4002;  // Hardware register
volatile const uint32_t *reg; // Read-only hardware register
```

> Does not replace mutex — `counter++` still has race condition even with `volatile`.

## const

Write-protected. In embedded: compiler places in **Flash** instead of RAM.

```c
const uint8_t table[256] = {...};  // Flash, no RAM usage
void send(const uint8_t *buf);   // Promises not to modify input buffer

const uint8_t *p;       // Data const, pointer can change
uint8_t * const p;       // Pointer const, data can change
```

## static

**Inside function** persists across calls, doesn't reset.  
**File scope** hidden from other files (private).

```c
void debounce(void) {
    static uint16_t count = 0;  // Retains value between calls
}

// uart.c
static uint8_t rx_buf[256];    // Not accessible from other files
static void buf_push(uint8_t); // Private function
```

## extern

Declares variable/function **defined in another file**.

```c
// config.c   uint32_t tick = 0;       // definition
// config.h   extern uint32_t tick;        // declaration
// main.c    #include "config.h"  tick++;
```

> Do NOT put definition (with initializer) in `.h` linker error.

## Common Patterns

| Pattern               | Code                                |
| --------------------- | ----------------------------------- |
| ISR flag              | `volatile uint8_t rx_done;`         |
| Read-only register    | `*(volatile const uint32_t*)0x...`  |
| Lookup table in Flash | `static const uint16_t lut[256]`    |
| Module private        | `static` at file scope              |
| Shared across files   | `extern volatile uint32_t tick_ms;` |
