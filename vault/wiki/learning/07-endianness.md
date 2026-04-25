---
title: Endianness
last_updated: 2026-04-18
category: learning
---

# Endianness — Big-Endian vs Little-Endian

## Concept

**Which byte is stored at the lowest address?**

```
uint32_t x = 0x12345678;

Little-Endian (ARM, x86):     Big-Endian (Network):
addr+0  addr+1  addr+2  addr+3  addr+0  addr+1  addr+2  addr+3
  0x78    0x56    0x34    0x12    0x12    0x34    0x56    0x78
  LSB                     MSB      MSB                     LSB
```

> AM335x (BeagleBone) = **Little-Endian** by default.  
> Network protocol (TCP/IP) = **Big-Endian** (called _network byte order_).

## Runtime Detection

```c
uint32_t test = 0x01;
bool is_little = *(uint8_t *)&test == 0x01;
```

## Manual Swap (No Library)

```c
uint16_t swap16(uint16_t x) {
    return (x << 8) | (x >> 8);
}

uint32_t swap32(uint32_t x) {
    return ((x & 0xFF000000) >> 24) |
           ((x & 0x00FF0000) >>  8) |
           ((x & 0x0000FF00) <<  8) |
           ((x & 0x000000FF) << 24);
}
```

## Standard Macros

```c
#include <arpa/inet.h>   // Linux userspace

// Host ↔ Network (big-endian)
uint16_t htons(x);   // host to network 16-bit
uint16_t ntohs(x);  // network to host 16-bit
uint32_t htonl(x);  // host to network 32-bit
uint32_t ntohl(x);  // network to host 32-bit
```

## Safe Byte Stream Parse (Endian-independent)

```c
// CORRECT — read each byte, assemble manually
uint32_t read_be32(const uint8_t *buf) {
    return ((uint32_t)buf[0] << 24) |
           ((uint32_t)buf[1] << 16) |
           ((uint32_t)buf[2] <<  8) |
           ((uint32_t)buf[3]);
}

// WRONG — pointer cast depends on CPU endianness
uint32_t val = *(uint32_t *)buf;
```

## Quick Reference

|                    | Little-Endian              | Big-Endian             |
| ------------------ | -------------------------- | ---------------------- |
| Platform           | ARM (default), x86         | Network, MIPS, PowerPC |
| Low byte           | LSB                        | MSB                    |
| Convert to network | `htons` / `htonl`          | none needed            |
| Detection          | `*(uint8_t*)&val == LSB`   | opposite               |
| Safe parse         | `read_be32()` self-written | always portable        |
