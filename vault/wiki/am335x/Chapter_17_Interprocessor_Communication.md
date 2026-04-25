---
title: AM335x Chapter 17 — Interprocessor Communication (Mailbox + Spinlock)
tags:
  - am335x
  - reference
source: AM335x TRM Chapter 17
---

# 17 Interprocessor Communication

## 17.1 Mailbox

### 17.1.1 Introduction

The Mailbox module provides interrupt-driven 32-bit message passing between processors. One system Mailbox instance exists, comprising **8 sub-module mailboxes** (MAILBOX0–7), each with a **4-message FIFO**.

| Feature | Value |
|---------|-------|
| Mailbox sub-modules | 8 |
| Messages per mailbox | 4 × 32-bit |
| OCP data bus width | 32-bit |
| OCP address bus width | 9-bit |
| Burst support | No |
| Interrupt outputs | 4 (one per user) |
| Users | User 0: MPU, User 1: PRU-ICSS PRU0, User 2: PRU-ICSS PRU1, User 3: WakeM3 |
| Unsupported features | None |

> [!NOTE]
> WakeM3 has access only to L4_Wakeup peripherals and cannot directly read Mailbox registers. The Mailbox interrupt asserts to WakeM3; actual message payload must be placed in the Control Module `IPC_MSG_REG{0–7}` registers or in M3 internal memory.

### 17.1.2 Integration

**Block diagram:**

```
L4 Peripheral Interconnect
         │
         ▼
+──────────────────────────────────────────+
│             Mailbox (×8)                 │
│  ┌────────────────────────────────────┐  │
│  │  MAILBOXm (m=0..7): 4×32b FIFO    │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │   IRQ registers (per user u=0..3)  │  │
│  └────────────────────────────────────┘  │
+──────────────────────────────────────────+
         │ mail_u0 ──► MPU (MBINT0)
         │ mail_u1 ──► PRU-ICSS PRU0
         │ mail_u2 ──► PRU-ICSS PRU1
         │ mail_u3 ──► WakeM3
```

### 17.1.3 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | L4PER_L4LS_GCLK |
| Reset | PER_DOM_RST_N |
| Idle | Smart Idle |
| Interrupts | mail_u0 (MBINT0)→MPU; mail_u1→PRU-ICSS PRU0; mail_u2→PRU-ICSS PRU1; mail_u3→WakeM3 |
| DMA | None |
| Physical Address | L4 Peripheral slave port |

### 17.1.4 Clock Signals

| Clock Signal | Max Freq | Source | Domain |
|-------------|----------|--------|--------|
| Functional/Interface clock | 100 MHz | CORE_CLKOUTM4 / 2 | pd_per_l4ls_gclk |

No external pins.

---

## 17.2 Mailbox Functional Description

### 17.2.1 Power Management

`MAILBOX_SYSCONFIG[3:2].SIDLEMODE`:

| Value | Mode | Behavior |
|-------|------|----------|
| 0x0 | Force-idle | Immediately enters idle on low-power request. Ensure no asserted interrupts before requesting. |
| 0x1 | No-idle | Never enters idle |
| 0x2 | Smart-idle | Enters idle only after all asserted output interrupts are acknowledged |

### 17.2.2 Interrupt Events

| Event | Non-maskable source | Maskable Status | Enable | Disable |
|-------|--------------------|-----------------|----|---------|
| New message in mailbox m | IRQSTATUS_RAW_u[0+m×2].NEWMSGSTATUSUU MBm | IRQSTATUS_CLR_u[0+m×2] | IRQENABLE_SET_u[0+m×2] | IRQENABLE_CLR_u[0+m×2] |
| Mailbox m not full | IRQSTATUS_RAW_u[1+m×2].NOTFULLSTATUSUMBm | IRQSTATUS_CLR_u[1+m×2] | IRQENABLE_SET_u[1+m×2] | IRQENABLE_CLR_u[1+m×2] |

> [!CAUTION]
> After handling an interrupt, write logical 1 to the corresponding bit of `MAILBOX_IRQSTATUS_CLR_u` to clear it. Writing 1 to `IRQSTATUS_CLR_u` also clears the corresponding `IRQSTATUS_RAW_u` bit.

### 17.2.3 16-bit Register Access

The module supports 16-bit access. For `MAILBOX_MESSAGE_m` registers, two consecutive 16-bit accesses are allowed, but **least-significant half-word must be accessed first** (low address before high address). The FIFO update and associated status/interrupt occur only on access to the most-significant 16 bits.

---

## 17.3 Mailbox Programming Guide

### 17.3.1 Initialization

| Step | Register / Field | Value |
|------|-----------------|-------|
| Software reset | MAILBOX_SYSCONFIG[0].SOFTRESET | 1 |
| Wait for reset complete | MAILBOX_SYSCONFIG[0].SOFTRESET | poll = 0 |
| Set idle mode | MAILBOX_SYSCONFIG[3:2].SIDLEMODE | 0x2 (smart-idle) |

### 17.3.2 Send Message — Polling

| Step | Register | Value |
|------|----------|-------|
| Check if FIFO full | MAILBOX_FIFOSTATUS_m[0].FIFOFULLMBM | wait =0h |
| Write message | MAILBOX_MESSAGE_m[31:0].MESSAGEVALUEMBM | data |

### 17.3.3 Send Message — Interrupt

| Step | Register | Value |
|------|----------|-------|
| Check if FIFO full | MAILBOX_FIFOSTATUS_m[0].FIFOFULLMBM | if =1h: |
| Enable not-full interrupt | MAILBOX_IRQENABLE_SET_u[1 + m×2] | 1h |
| (wait for interrupt, then write message) | MAILBOX_MESSAGE_m[31:0] | data |

### 17.3.4 Receive Message — Polling

| Step | Register | Value |
|------|----------|-------|
| Check FIFO not empty | MAILBOX_MSGSTATUS_m[2:0].NBOFMSGMBM | ≠0h |
| Read message | MAILBOX_MESSAGE_m[31:0].MESSAGEVALUEMBM | — |

### 17.3.5 Receive Message — Interrupt

| Step | Register | Value |
|------|----------|-------|
| Enable new-message interrupt | MAILBOX_IRQENABLE_SET_u[0 + m×2] | 1h |
| In ISR: read interrupt status | MAILBOX_IRQSTATUS_CLR_u[0 + m×2] | read = 1 |
| Check message count | MAILBOX_MSGSTATUS_m[2:0].NBOFMSGMBM | ≠0h |
| Read message | MAILBOX_MESSAGE_m[31:0].MESSAGEVALUEMBM | — |
| Acknowledge interrupt | MAILBOX_IRQSTATUS_CLR_u[0 + m×2] | write 1 |

### 17.3.6 Event Servicing — Send ISR (queue-not-full)

| Step | Register | Value |
|------|----------|-------|
| Read status | MAILBOX_IRQSTATUS_CLR_u[1 + m×2] | read |
| Write message | MAILBOX_MESSAGE_m[31:0].MESSAGEVALUEMBM | data |
| Acknowledge | MAILBOX_IRQSTATUS_CLR_u[1 + m×2] | write 1 |

---

## 17.4 Mailbox Register Map

Base address: 0x480C8000

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | REVISION | 400h | IP revision (SCHEME[31:30], FUNC[27:16], RTL[15:11], MAJOR[10:8]=4h, Custom[7:6]=10h, MINOR[5:0]) |
| 10h | SYSCONFIG | 8h | SIDLEMODE[3:2], SOFTRESET[0] |
| 40h | MESSAGE_0 | 0h | MESSAGEVALUEMBM[31:0] — read removes from FIFO |
| 44h | MESSAGE_1 | 0h | Same as MESSAGE_0 for mailbox 1 |
| 48h | MESSAGE_2 | 0h | Same, mailbox 2 |
| 4Ch | MESSAGE_3 | 0h | Same, mailbox 3 |
| 50h | MESSAGE_4 | 0h | Same, mailbox 4 |
| 54h | MESSAGE_5 | 0h | Same, mailbox 5 |
| 58h | MESSAGE_6 | 0h | Same, mailbox 6 |
| 5Ch | MESSAGE_7 | 0h | Same, mailbox 7 |
| 80h | FIFOSTATUS_0 | 0h | FIFOFULLMBM[0]: 0=NotFull, 1=Full |
| 84h | FIFOSTATUS_1 | 0h | Same for mailbox 1 |
| 88h | FIFOSTATUS_2 | 0h | Same, mailbox 2 |
| 8Ch | FIFOSTATUS_3 | 0h | Same, mailbox 3 |
| 90h | FIFOSTATUS_4 | 0h | Same, mailbox 4 |
| 94h | FIFOSTATUS_5 | 0h | Same, mailbox 5 |
| 98h | FIFOSTATUS_6 | 0h | Same, mailbox 6 |
| 9Ch | FIFOSTATUS_7 | 0h | Same, mailbox 7 |
| C0h | MSGSTATUS_0 | 0h | NBOFMSGMBM[2:0]: number of unread messages (max 4) |
| C4h | MSGSTATUS_1 | 0h | Same, mailbox 1 |
| C8h | MSGSTATUS_2 | 0h | Same, mailbox 2 |
| CCh | MSGSTATUS_3 | 0h | Same, mailbox 3 |
| D0h | MSGSTATUS_4 | 0h | Same, mailbox 4 |
| D4h | MSGSTATUS_5 | 0h | Same, mailbox 5 |
| D8h | MSGSTATUS_6 | 0h | Same, mailbox 6 |
| DCh | MSGSTATUS_7 | 0h | Same, mailbox 7 |
| 100h | IRQSTATUS_RAW_0 | 0h | User 0 raw interrupt status (debug use); W1 sets bit |
| 104h | IRQSTATUS_CLR_0 | 0h | User 0 masked status; W1 clears bit + RAW |
| 108h | IRQENABLE_SET_0 | 0h | User 0 interrupt enable; W1 to enable |
| 10Ch | IRQENABLE_CLR_0 | 0h | User 0 interrupt disable; W1 to disable |
| 110h | IRQSTATUS_RAW_1 | 0h | User 1 (PRU0) raw status |
| 114h | IRQSTATUS_CLR_1 | 0h | User 1 masked status; W1 clears |
| 118h | IRQENABLE_SET_1 | 0h | User 1 enable; W1 |
| 11Ch | IRQENABLE_CLR_1 | 0h | User 1 disable; W1 |
| 120h | IRQSTATUS_RAW_2 | 0h | User 2 (PRU1) raw status |
| 124h | IRQSTATUS_CLR_2 | 0h | User 2 masked status |
| 128h | IRQENABLE_SET_2 | 0h | User 2 enable |
| 12Ch | IRQENABLE_CLR_2 | 0h | User 2 disable |
| 130h | IRQSTATUS_RAW_3 | 0h | User 3 (WakeM3) raw status |
| 134h | IRQSTATUS_CLR_3 | 0h | User 3 masked status |
| 138h | IRQENABLE_SET_3 | 0h | User 3 enable |
| 13Ch | IRQENABLE_CLR_3 | 0h | User 3 disable |

**IRQ register bit layout** (`IRQSTATUS_CLR_u`, `IRQSTATUS_RAW_u`, `IRQENABLE_SET_u`, `IRQENABLE_CLR_u`):

- Bit `0 + m×2` → new message event for mailbox m (m=0..7)
- Bit `1 + m×2` → not-full event for mailbox m

---

## 17.5 Spinlock

### 17.5.1 Introduction

The Spinlock module provides 64 hardware semaphores for mutual exclusion between processors. Attempting to lock an already-locked spinlock returns the **current owner** value; a successful lock returns 0.

| Feature | Value |
|---------|-------|
| Spinlock registers | 64 |
| Lock operation | Read LOCK_m: returns 0 if acquired, 1 (or current value) if already locked |
| Unlock operation | Write 0 to LOCK_m |
| OCP interface | L4 Peripheral slave |
| Interrupt | None (polling-based) |
| DMA | None |

### 17.5.2 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | L4PER_L4LS_GCLK |
| Reset | PER_DOM_RST_N |
| Physical Address | L4 Peripheral slave port |
| Base Address | 0x480CA000 |

### 17.5.3 Spinlock Register Map

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | REVISION | — | IP revision (read-only) |
| 10h | SYSCONFIG | — | Idle mode configuration |
| 14h | SYSSTATUS | — | Reset done status |
| 20h | SYSTEST | — | Diagnostic / test |
| 800h–9FCh | LOCK_0–LOCK_63 | 0h | Spinlock registers (64 × 4-byte): read=try lock, write 0=release |

**Lock/unlock protocol:**

```c
/* Lock spinlock N */
while (SPINLOCK->LOCK[N] != 0);   /* spin until acquired (read returns 0) */

/* Critical section */
...

/* Unlock */
SPINLOCK->LOCK[N] = 0;
```

> [!NOTE]
> The read of `LOCK_m` is an **atomic test-and-set**: if the lock is free (value=0) it sets the lock and returns 0; if already locked it returns the lock value (non-zero). This is guaranteed atomic at the OCP interconnect level.
