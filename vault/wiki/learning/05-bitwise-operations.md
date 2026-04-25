---
title: Bitwise Operations
last_updated: 2026-04-18
category: learning
---

# Bitwise Operations

Embedded C bit manipulation — GPIO, register control.

## 4 Basic Operations

```c
#define BIT(n)  (1U << (n))

REG |=  BIT(n);   // SET   bit n
REG &= ~BIT(n);   // CLEAR bit n
REG ^=  BIT(n);   // TOGGLE bit n
(REG >> n) & 1U  // READ  bit n (0 or 1)
```

## Bitmask — Multiple Bits

```c
#define PIN2  BIT(2)
#define PIN3  BIT(3)
#define MASK  (PIN2 | PIN3)

REG |=  MASK;   // Set both PIN2 and PIN3
REG &= ~MASK;   // Clear both
REG ^=  MASK;   // Toggle both
REG &   MASK   // Read — result ≠ 0 if any bit set
```

## Practical Example — GPIO

```c
#define GPIOA_ODR  (*(volatile uint32_t*)0x40020014)
#define LED_PIN    BIT(5)

GPIOA_ODR |=  LED_PIN;   // LED on
GPIOA_ODR &= ~LED_PIN;  // LED off
GPIOA_ODR ^=  LED_PIN;  // Blink

// Safe multi-bit write: clear first, then set
GPIOA_ODR = (GPIOA_ODR & ~MASK) | VALUE;
```

## Bitfield Struct — Named Bits

```c
typedef union {
    uint32_t raw;
    struct {
        uint32_t PE     : 1;  // bit 0 — UART Enable
        uint32_t RE     : 1;  // bit 2 — Receiver Enable
        uint32_t TE     : 1;  // bit 3 — Transmitter Enable
        uint32_t        : 5;  // bits 4-8 reserved
        uint32_t PS     : 1;  // bit 9 — Parity Select
        uint32_t        : 22; // padding
    } bits;
} USART_CR1_t;

volatile USART_CR1_t *CR1 = (USART_CR1_t*)0x40011000;
CR1->bits.TE = 1;   // Enable transmitter
CR1->raw = 0;       // Clear entire register
```

> Bitfield order is compiler-dependent — not portable.

## Extract / Insert Multi-bit Value

```c
// Extract bits [6:4]
#define SHIFT  4
#define MASK   (0x7U << SHIFT)
uint8_t val = (REG & MASK) >> SHIFT;

// Write 3-bit value to bits [6:4]
REG = (REG & ~MASK) | ((val & 0x7U) << SHIFT);
```

## Quick Reference

| Purpose                        | Code                           |
| ------------------------------ | ------------------------------ |
| Set bit n                      | `REG \|= (1U << n)`            |
| Clear bit n                    | `REG &= ~(1U << n)`            |
| Toggle bit n                   | `REG ^= (1U << n)`             |
| Read bit n                     | `(REG >> n) & 1U`              |
| Check bit set                  | `if (REG & BIT(n))`            |
| Safe multi-bit write           | `REG = (REG & ~MASK) \| VALUE` |
| Extract n bits from position p | `(REG >> p) & ((1U << n) - 1)` |
