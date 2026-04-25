---
title: Function Pointer
last_updated: 2026-04-18
category: learning
---

# Function Pointer

## Declaration Syntax

```c
// return_type (*name)(param_list)
int  (*fp)(int, int);    // takes 2 ints, returns int
void (*cb)(void *data);  // takes void*, returns void

// Assignment — function name auto-decays to pointer
fp = add;
fp = &add;               // also valid, but & not needed

// Call — both ways work
int r = fp(3, 4);
int r = (*fp)(3, 4);
```

## Common Mistake

```c
void (*fp)(int);   // function pointer — parentheses around *fp REQUIRED
void *fp(int);     // NOT function pointer — this is a function returning void*
```

## typedef for Readability

```c
typedef int (*math_fn)(int, int);

math_fn ops[] = { add, sub, mul };
int result = ops[0](10, 5);    // == add(10, 5) == 15
```

## Kernel Pattern: struct file_operations

Entire driver ↔ userspace interface:

```c
static ssize_t my_read(struct file *f, char __user *buf,
                       size_t len, loff_t *off) { ... }

static struct file_operations my_fops = {
    .owner   = THIS_MODULE,
    .read    = my_read,     // function pointer
    .write   = my_write,
    .open    = my_open,
    .release = my_release,
};
```

## Common Errors

| Error                                             | Consequence                                        |
| ------------------------------------------------- | -------------------------------------------------- |
| `void *fp(int)` instead of `void (*fp)(int)`      | declares a function, not a pointer — compile error |
| Signature mismatch when assigning                 | Undefined Behavior at runtime                      |
| Calling NULL pointer: `fp(arg)` when `fp == NULL` | kernel panic / segfault                            |
| In ISR: calling function that may sleep           | deadlock or kernel BUG                             |

```c
// Always check NULL before calling
if (fp)
    fp(arg);
```

## Callback Pattern

```c
typedef void (*callback_fn)(int);

// Driver stores callback
static callback_fn driver_callback;

int driver_register(callback_fn cb) {
    if (!cb)
        return -EINVAL;
    driver_callback = cb;
    return 0;
}

// Later, driver invokes callback
if (driver_callback)
    driver_callback(event);
```
