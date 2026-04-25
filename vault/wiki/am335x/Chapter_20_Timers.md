---
title: AM335x Chapter 20 Timers
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 20 Timers (DMTimer)

## Overview

DMTimer — 32-bit free-running upward counter with auto-reload, compare, capture, and PWM capabilities. Supports write-posted mode.

## Instance Base Addresses

| Instance     | Base Address |
| ------------ | ------------ |
| DMTIMER0     | 0x44E05000   |
| DMTIMER1_1MS | 0x44E31000   |
| DMTIMER2     | 0x48040000   |
| DMTIMER3     | 0x48042000   |
| DMTIMER4     | 0x48044000   |
| DMTIMER5     | 0x48046000   |
| DMTIMER6     | 0x48048000   |
| DMTIMER7     | 0x4804A000   |

## System Integration

**Timer0:**

- Power Domain: Wakeup domain
- Interface clock: PD_WKUP_L4_WKUP_GCLK (100 MHz, CORE_CLKOUTM4/2)
- Functional clock: PD_WKUP_TIMER0_GCLK (≤26 MHz, CLK_RC32K — fixed)
- Interrupts: 1 to MPU (TINT0), 1 to WakeM3
- DMA: None; wakeup: supported

**Timer2–7:**

- Power Domain: Peripheral domain
- Interface clock: PD_PER_L4LS_GCLK (100 MHz, CORE_CLKOUTM4/2)
- Functional clock: PD_PER_TIMERx_GCLK (≤26 MHz) — selected via PRCM CLKSEL_TIMERx_CLK from: CLK_M_OSC, CLK_32KHZ, or TCLKIN
- Interrupts: 1 to MPU per instance (TINT2–TINT7); Timer4–7 also routed to TSC_ADC event capture mux
- DMA: Interrupt requests redirected as DMA events (1 per instance)
- Wakeup: Not supported

> PICLKTIMER must be ≤ PICLKOCP/4.

## Pin List

| Pin      | Type  | Description                                                                                        |
| -------- | ----- | -------------------------------------------------------------------------------------------------- |
| TCLKIN   | Input | External timer clock source                                                                        |
| TIMER4–7 | I/O   | Trigger input (PIEVENTCAPT) or PWM output (PORTIMERPWM) — same pad, direction via TCLR[14] GPO_CFG |

## Timer Resolution

| Clock      | Prescaler | Resolution | Period Range         |
| ---------- | --------- | ---------- | -------------------- |
| 32.768 kHz | 1         | 31.25 µs   | 31.25 µs – ~36h 35m  |
| 32.768 kHz | 256       | 8 ms       | 8 ms – ~391d 22h 48m |
| 25 MHz     | 1         | 40 ns      | 40 ns – ~171.8s      |
| 25 MHz     | 256       | 10.24 µs   | ~20.5 µs – ~24h 32m  |

**Interrupt period formula:**

```
Interrupt Period = (0xFFFFFFFF - TLDR + 1) × Timer_Clock_Period × PS
PS = 2^(PTV+1) when PRE=1; PS = 1 when PRE=0
```

**Example TLDR values at 32 kHz, PRE=0:**

| TLDR       | Period    |
| ---------- | --------- |
| 0x00000000 | ~37 hours |
| 0xFFFF0000 | 2 seconds |
| 0xFFFFFFF0 | 500 µs    |
| 0xFFFFFFFE | 62.5 µs   |

## Prescaler Ratios

| PRE | PTV | Divisor      |
| --- | --- | ------------ |
| 0   | X   | 1 (disabled) |
| 1   | 0   | 2            |
| 1   | 1   | 4            |
| 1   | 2   | 8            |
| 1   | 3   | 16           |
| 1   | 4   | 32           |
| 1   | 5   | 64           |
| 1   | 6   | 128          |
| 1   | 7   | 256          |

## Functional Modes

### Timer Mode (Free-running counter)

Counter increments until overflow; can be read/written at any time.

- **One-shot (TCLR AR=0):** Counter stops at overflow; remains at 0.
- **Auto-reload (TCLR AR=1):** TCRR reloaded from TLDR on overflow; continuous.

Counter loading methods: direct write to TCRR, or write to TTGR (triggers load of TLDR into TCRR).

> Do NOT write 0xFFFFFFFF to TLDR — causes undefined behavior.

### Capture Mode

Counter value (TCRR) captured to TCAR1 (and TCAR2 in dual mode) on PIEVENTCAPT transitions. Edge selection via TCLR TCM: 0x0=None; 0x1=Rising; 0x2=Falling; 0x3=Both.

- **Single capture (CAPT_MODE=0):** First event → TCAR1; subsequent events ignored until interrupt cleared.
- **Dual capture (CAPT_MODE=1):** First event → TCAR1; second → TCAR2; useful for period measurement. Detection logic resets when TCAR_IT_FLAG cleared.

### Compare Mode

TCRR continuously compared to TMAR. Enable: TCLR CE=1. Write TMAR before setting CE to avoid spurious match from reset value.

PORTIMERPWM output can pulse or toggle on match.

### PWM Generation

Configure TCLR TRG, PT, SCPWM for PWM:

```
Frequency  = Timer_Clock / ((0xFFFFFFFF - TLDR + 1) × Prescaler)
Duty Cycle = (TMAR - TLDR) / (0xFFFFFFFF - TLDR + 1)
```

> In overflow+match mode (TRG=0x2), first match after setup is ignored until first overflow.

## Write-Posted Mode

Enable: TSICR[2] POSTED=1. OCP write granted before write completes in timer domain. Monitor completion via TWPS register bits.

- **Posted mode:** Requires Timer_freq < OCP_freq/4. Writes immediate; check TWPS before dependent ops.
- **Non-posted mode:** Use when Timer_freq ≥ OCP_freq/4. Write stall: 2 timer clocks + 2 OCP clocks. Read stall: max 3 OCP + 2.5 timer clocks.

## 16-bit Register Access Rules

All registers are 32-bit but 16-bit addressable.

- **Write:** LSB16 first, then MSB16.
- **Functional registers** (TCLR, TCRR, TLDR, TTGR, TMAR): MSB16 must always be written even if unchanged.
- **OCP-only registers** (TIDR, TIOCP_CFG, IRQ\*, TSICR): MSB16 can be skipped if upper 16 bits need no update.
- **TCRR 16-bit read (atomic sequence):** (1) Read lower 16 bits (0x3C) — latches upper half; (2) Read upper 16 bits (0x3E) — returns latched value. Same for TCAR1 (0x50/0x52) and TCAR2 (0x58/0x5A).

## Register Map

| Offset | Register      | Description                                                                |
| ------ | ------------- | -------------------------------------------------------------------------- |
| 0x00   | TIDR          | Identification (read-only)                                                 |
| 0x10   | TIOCP_CFG     | OCP Configuration                                                          |
| 0x20   | IRQ_EOI       | IRQ End-of-Interrupt                                                       |
| 0x24   | IRQSTATUS_RAW | Status Raw (before masking)                                                |
| 0x28   | IRQSTATUS     | Status (after masking, W1C)                                                |
| 0x2C   | IRQENABLE_SET | Interrupt Enable Set (W1 to enable)                                        |
| 0x30   | IRQENABLE_CLR | Interrupt Enable Clear (W1 to disable)                                     |
| 0x34   | IRQWAKEEN     | IRQ Wakeup Enable (Timer0 only)                                            |
| 0x38   | TCLR          | Timer Control Register                                                     |
| 0x3C   | TCRR          | Timer Counter (R/W, on-the-fly)                                            |
| 0x40   | TLDR          | Timer Load (auto-reload value)                                             |
| 0x44   | TTGR          | Timer Trigger (write any value to reload TCRR from TLDR; reads 0xFFFFFFFF) |
| 0x48   | TWPS          | Write Posting Status (read-only)                                           |
| 0x4C   | TMAR          | Timer Match                                                                |
| 0x50   | TCAR1         | Capture Register 1 (read-only)                                             |
| 0x54   | TSICR         | Synchronous Interface Control                                              |
| 0x58   | TCAR2         | Capture Register 2 (read-only)                                             |

## Key Register Descriptions

### TIOCP_CFG (0x10)

| Bits | Field     | Type | Reset | Description                                                |
| ---- | --------- | ---- | ----- | ---------------------------------------------------------- |
| 3-2  | IDLEMODE  | R/W  | 0     | 0=Force-idle; 1=No-idle; 2=Smart-idle; 3=Smart-idle wakeup |
| 1    | EMUFREE   | R/W  | 0     | 0=Timer stops on debug suspend; 1=Runs free in debug       |
| 0    | SOFTRESET | R/W  | 0     | Write 1 to reset; reads 0 when reset complete              |

### IRQ_EOI (0x20)

| Bit | Field        | Description                                                                                 |
| --- | ------------ | ------------------------------------------------------------------------------------------- |
| 0   | DMAEvent_Ack | Write 0 to acknowledge DMA event; module generates next DMA event only after acknowledgment |

### IRQSTATUS_RAW / IRQSTATUS / IRQENABLE_SET / IRQENABLE_CLR / IRQWAKEEN

All share the same 3-bit layout:

| Bit | Field                                      | Description    |
| --- | ------------------------------------------ | -------------- |
| 2   | TCAR_IT_FLAG / TCAR_EN_FLAG / TCAR_WUP_ENA | Capture event  |
| 1   | OVF_IT_FLAG / OVF_EN_FLAG / OVF_WUP_ENA    | Overflow event |
| 0   | MAT_IT_FLAG / MAT_EN_FLAG / MAT_WUP_ENA    | Match event    |

IRQSTATUS: write 1 to clear (also clears raw status). Status not set unless event enabled. IRQWAKEEN applicable to Timer0 only.

### TCLR (0x38) — Main Control Register

| Bits  | Field     | Type | Reset | Description                                                            |
| ----- | --------- | ---- | ----- | ---------------------------------------------------------------------- |
| 14    | GPO_CFG   | R/W  | 0     | 0=PORGPOCFG=0 (pin is output); 1=PORGPOCFG=1 (pin is input)            |
| 13    | CAPT_MODE | R/W  | 0     | 0=Single capture (TCAR1 only); 1=Dual capture (TCAR1 then TCAR2)       |
| 12    | PT        | R/W  | 0     | 0=Pulse mode; 1=Toggle mode on PORTIMERPWM                             |
| 11-10 | TRG       | R/W  | 0     | 0x0=No trigger; 0x1=Trigger on overflow; 0x2=Trigger on overflow+match |
| 9-8   | TCM       | R/W  | 0     | 0x0=No capture; 0x1=Rising; 0x2=Falling; 0x3=Both edges                |
| 7     | SCPWM     | R/W  | 0     | 0=Clear PORTIMERPWM / positive pulse; 1=Set / negative pulse           |
| 6     | CE        | R/W  | 0     | Compare enable (write TMAR before setting)                             |
| 5     | PRE       | R/W  | 0     | Prescaler enable                                                       |
| 4-2   | PTV       | R/W  | 0     | Prescaler value: divisor = 2^(PTV+1) when PRE=1                        |
| 1     | AR        | R/W  | 0     | 0=One-shot; 1=Auto-reload                                              |
| 0     | ST        | R/W  | 0     | 0=Stop; 1=Start. In one-shot, hardware resets ST on overflow           |

### TWPS (0x48) — Write Posting Status (Read-only)

| Bit | Field       | Description        |
| --- | ----------- | ------------------ |
| 4   | W_PEND_TMAR | TMAR write pending |
| 3   | W_PEND_TTGR | TTGR write pending |
| 2   | W_PEND_TLDR | TLDR write pending |
| 1   | W_PEND_TCRR | TCRR write pending |
| 0   | W_PEND_TCLR | TCLR write pending |

Check bit=0 before dependent operations in posted mode.

### TSICR (0x54)

| Bits | Field  | Type | Reset | Description                                                                           |
| ---- | ------ | ---- | ----- | ------------------------------------------------------------------------------------- |
| 2    | POSTED | R/W  | 0x1   | 0=Non-posted (use when Timer ≥ OCP/4); 1=Posted mode (use when Timer < OCP/4)         |
| 1    | SFT    | R/W  | 0     | Software reset of functional part. Read always returns 0. 0=Reset enabled; 1=Disabled |

## Programming Sequences

### One-Shot Timer

```
1. TCLR.ST = 0 (stop)
2. TCLR.AR = 0, set PRE/PTV if needed
3. TCRR = initial value
4. IRQENABLE_SET.OVF_EN_FLAG = 1
5. TCLR.ST = 1 (start)
6. On interrupt: write 1 to IRQSTATUS.OVF_IT_FLAG
```

### Auto-Reload Timer

```
1. TCLR.ST = 0
2. TCLR.AR = 1, set PRE/PTV if needed
3. TLDR = reload value
4. TCRR = initial value (or write TTGR to trigger load)
5. IRQENABLE_SET.OVF_EN_FLAG = 1
6. TCLR.ST = 1
```

### Single Capture

```
1. TCLR.CAPT_MODE = 0, TCLR.TCM = 1/2/3
2. IRQENABLE_SET.TCAR_EN_FLAG = 1
3. TCLR.ST = 1
4. On interrupt: read TCAR1
5. Write 1 to IRQSTATUS.TCAR_IT_FLAG
```

### Dual Capture (Period Measurement)

```
1. TCLR.CAPT_MODE = 1, TCLR.TCM = 1 (rising edge)
2. IRQENABLE_SET.TCAR_EN_FLAG = 1; TCLR.ST = 1
3. First interrupt: TCAR1 = first edge
4. Second interrupt: TCAR2 = second edge
5. Period = TCAR2 - TCAR1
6. Write 1 to IRQSTATUS.TCAR_IT_FLAG
```

### Compare Mode

```
1. TCLR.ST = 0
2. TMAR = match value           ← must write BEFORE setting CE
3. TCLR.CE = 1, TCLR.AR = 1
4. TLDR = reload; TCRR = initial
5. IRQENABLE_SET.MAT_EN_FLAG = 1; TCLR.ST = 1
6. On interrupt: write 1 to IRQSTATUS.MAT_IT_FLAG
```

### PWM Mode

```
1. TCLR.ST = 0
2. TCLR: AR=1, CE=1, PT=1, TRG=2, SCPWM=0/1
3. TLDR = 0xFFFFFFFF - period + 1
4. TMAR = 0xFFFFFFFF - duty_cycle + 1
5. TCRR = TLDR (or write TTGR)
6. TCLR.ST = 1
```

### Write-Posted Mode

```
1. TSICR.POSTED = 1
2. Write to timer register (e.g., TCRR = value)
3. while (TWPS.W_PEND_TCRR) {}   // wait
4. Proceed
```

## Emulation (Debug) Support

To stop timer during debugger breakpoints:

1. Set `TIOCP_CFG.EMUFREE = 0` (allows Debug Subsystem Suspend_Control to stop timer).
2. Set the appropriate `xxx_Suspend_Control` register = 0x9 in the Debug Subsystem (Chapter 27).

If EMUFREE=1, the suspend signal is ignored and the timer runs free regardless of debug state.

## Common Use Cases

| Application           | Mode                  | Key Configuration       |
| --------------------- | --------------------- | ----------------------- |
| Periodic interrupt    | Auto-reload           | AR=1, OVF_EN_FLAG=1     |
| Timeout detection     | One-shot              | AR=0, OVF_EN_FLAG=1     |
| Event timestamping    | Single capture        | CAPT_MODE=0, TCM=edge   |
| Frequency measurement | Dual capture          | CAPT_MODE=1, TCM=1      |
| PWM generation        | Compare + auto-reload | CE=1, AR=1, TRG=2, PT=1 |
| Precise delay         | Compare               | CE=1                    |

## Important Notes

- **TLDR=0xFFFFFFFF:** Never write — causes undefined behavior.
- **Compare mode:** Always write TMAR before setting TCLR.CE.
- **Capture reset:** Detection logic resets automatically when TCAR_IT_FLAG is cleared.
- **Posted mode:** Always check TWPS before operations dependent on previous writes.
- **Prescaler reset:** Resets on timer stop, write to TCRR, or write to TTGR.
- **Wakeup:** Only Timer0 supports wake-up from low-power modes.
- **Interrupt clear:** Write 1 to clear; writing 0 has no effect.
