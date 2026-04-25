---
title: Pointer Arithmetic
last_updated: 2026-04-18
category: learning
---

# Pointer Arithmetic

Adding/subtracting integer to pointer jumps by **`sizeof(type)`**, not bytes.

## Basic Concepts

```c
int arr[] = {10, 20, 30, 40};
int *p = arr;          // p = 0x100 arr[0]

p++;                   // p = 0x104  (jumps 4 bytes = sizeof(int))
p + 2;                 // p = 0x10C  (jumps 8 more bytes)
*(p + 2);              // == arr[3] == 40

// p[n] is identical to *(p + n)
p[1] == *(p + 1);      // true
```

## Expression Table

| Expression | Meaning                                    |
| ---------- | ------------------------------------------ |
| `p + n`    | address + `n * sizeof(*p)`                 |
| `p - n`    | address - `n * sizeof(*p)`                 |
| `p - q`    | element count between p and q (same array) |
| `p[n]`     | identical to `*(p + n)`                    |
| `*p++`     | get `*p`, then increment p (postfix)       |
| `*++p`     | increment p first, then get new value      |

## Memory Layout

`sizeof(int) = 4` bytes:

```
arr[0]: addr 0x100  value 10   (p initial position)
arr[1]: addr 0x104  value 20   (p after p++)
arr[3]: addr 0x10C  value 40   (*(p + 2) when p = arr[1])
```

## MMIO in Kernel (AM335x)

```c
void __iomem *base = devm_ioremap_resource(dev, res);

// CORRECT — use ioread/iowrite (has memory barrier)
u32 val = ioread32(base + REG_CTRL);
iowrite32(0x1, base + REG_ENABLE);

// WRONG — direct dereference, no barrier
// u32 val = *(volatile u32 *)(base + REG_CTRL);
```

**Golden rule:** Never dereference `void __iomem *` directly. Use `ioread*/iowrite*` functions.
