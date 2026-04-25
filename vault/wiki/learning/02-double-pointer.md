---
title: Double Pointer
last_updated: 2026-04-18
category: learning
---

# Double Pointer (Pointer to Pointer)

## Pointer Chain

```c
int   val = 42;
int  *p   = &val;    // p  = 0x200  val
int **pp  = &p;      // pp = 0x300  p to val

// Reading
*pp   == 0x200       // address of p
**pp  == 42          // value of val

// Write through
**pp = 99;           // val becomes 99
```

## Memory Layout

```
pp (0x300)  p (0x200)  val (0x100)
   [0x200]       [0x100]         [42]
```

## Quick Reference

| Expression | Result                              |
| ---------- | ----------------------------------- |
| `pp`       | address of p (0x300)                |
| `*pp`      | value of p = address of val (0x200) |
| `**pp`     | value of val (42)                   |
| `*pp = q`  | make p point to another region      |
| `**pp = v` | change val through 2 pointer layers |

## Why Double Pointer as Parameter?

C passes arguments **by value**. Passing `int *p` function only gets a copy, cannot change caller's `p`. Passing `int **pp` function can change `*pp` (i.e., caller's p).

```c
// WRONG — caller's p unchanged
void alloc_wrong(int *p) {
    p = malloc(4);   // only changes local copy
}

// CORRECT — caller gets new address
void alloc_ok(int **pp) {
    *pp = malloc(4); // changes caller's p
}
```

## Kernel Pattern: Linked List Delete Node

```c
// Delete node without special-casing head
void remove_node(struct node **head, int val) {
    struct node **cur = head;       // pointer to *head

    while (*cur && (*cur)->val != val)
        cur = &(*cur)->next;        // advance to next slot

    if (*cur)
        *cur = (*cur)->next;        // bypass node to delete
}

// Call: remove_node(&list, 42);
// When deleting head: *head = head->next — no special case needed
```
