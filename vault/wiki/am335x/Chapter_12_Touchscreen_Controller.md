---
title: AM335x Chapter 12 — Touchscreen Controller (TSC_ADC_SS)
tags:
  - am335x
  - tsc
  - adc
  - reference
source: "AM335x TRM Chapter 12"
---

# 12 Touchscreen Controller (TSC_ADC_SS)

## 12.1 Introduction

The TSC_ADC_SS is an 8-channel general-purpose 12-bit ADC with optional touchscreen support. It can be configured as:

| Configuration | ADC Channels Available |
|--------------|----------------------|
| 8 general-purpose ADC only | AN[7:0] (8 channels) |
| 4-wire TSC + ADC | AN[4:7] (4 channels) |
| 5-wire TSC + ADC | AN[5:7] (3 channels) |
| 8-wire TSC only | No free ADC channels |

### 12.1.1 Features

- 12-bit ADC; minimum 15 ADC clock cycles per sample
- 16 programmable step configuration registers (Step1–Step16)
- 1 idle step (always enabled, applied when FSM in IDLE state)
- 1 touchscreen charge step
- Averaging: 1 (none), 2, 4, 8, or 16 samples per step
- programmable OpenDelay and SampleDelay per step
- Two 64-word × 16-bit FIFOs (FIFO0, FIFO1)
- HW-synchronized start (Pen touch event or external HW signal, but not both per step)
- SW-enabled start (software writes step enable bit)
- DMA request output per FIFO (tsc_adc_FIFO0, tsc_adc_FIFO1)
- HW preemption of SW steps on Pen-down event (optional)

### 12.1.2 Interrupts

| Interrupt | Description |
|-----------|-------------|
| HW_Pen_Event_asynchronous | Pen-down event (async, can wake from idle) |
| HW_Pen_Event_synchronized | Pen-down event (sync to OCP clock) |
| Pen_Up_Event | Pen-up after charge step, if pen is removed |
| End_of_Sequence | All active steps completed |
| FIFO0_Threshold / FIFO1_Threshold | FIFO count ≥ programmable threshold |
| FIFO0_Overrun / FIFO1_Overrun | FIFO write when full |
| FIFO0_Underflow / FIFO1_Underflow | FIFO read when empty |
| Out_of_Range | Sampled data outside ADC_RANGE |

---

## 12.2 Integration

### 12.2.1 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Wakeup Domain |
| Clock Domain | PD_WKUP_L4_WKUP_GCLK (OCP), PD_WKUP_ADC_FCLK (ADC) |
| Reset | WKUP_DOM_RST_N |
| Idle/Wakeup | Smart Idle + Wakeup |
| Interrupt | 1 to MPU (ADC_TSC_GENINT), PRU-ICSS (gen_intr_pend), WakeM3 |
| DMA Requests | 2 (tsc_adc_FIFO0, tsc_adc_FIFO1) to EDMA |
| Physical Address | L3 Slow (DMA port), L4 Wakeup (MMR port) |

### 12.2.2 Clock Signals

| Clock | Max Freq | Source | Notes |
|-------|----------|--------|-------|
| ocp_clk (OCP/Functional) | 100 MHz | CORE_CLKOUTM4 / 2 | pd_wkup_l4_wkup_gclk |
| adc_clk | 24 MHz | CLK_M_OSC | pd_wkup_adc_fclk |

> **Note**: adc_clk must be ≤ 24 MHz for maximum sample rate. For CLK_M_OSC > 24 MHz (25 or 26 MHz), use ADC_CLKDIV to divide down; this reduces max sample rate.

### 12.2.3 Pin List

| Pin | Type | Description |
|-----|------|-------------|
| AN[7:0] | I | Analog inputs (AIN0–AIN7) |
| VREFP | Power | Analog Reference Positive |
| VREFN | Power | Analog Reference Negative |

> In 4-wire mode: XPUL=AN0, XNUR=AN1, YPUL=AN2, YNLR=AN3
> In 5-wire mode: XPUL=AN0, XNUR=AN1, YPUL=AN2, YNLR=AN3, AN4=fifth wire

---

## 12.3 Functional Description

### 12.3.1 Sequencer FSM

The sequencer iterates Steps 1–16 in order, skipping disabled steps. For each active step, it applies the step configuration and:

1. **IDLE**: Apply IDLECONFIG; wait for step enable or HW event
2. For each enabled step:
   - Apply STEPCONFIGx (AFE inputs, channel select, mode, averaging, FIFO target)
   - Wait OpenDelay[N] cycles (can be 0)
   - Wait SampleDelay[N] cycles (minimum 1 cycle)
   - ADC conversion: 13 ADC clock cycles to produce ADCOUT[11:0]
   - If averaging > 1: repeat ADC conversion up to 16× and average results
   - If one-shot: clear step enable bit
3. After last HW step: apply Charge step, then check Pen-up
4. Generate END_OF_SEQUENCE interrupt

**Timing**: Minimum 15 ADC clock cycles per sample with no delays and no averaging.

### 12.3.2 Step types

| Mode | Trigger Condition |
|------|-------------------|
| SW-enabled | Step starts when STEPENABLE[n] is set by software |
| HW-synchronized | Step waits for Pen-down event or ext_hw_event input |

Only one HW event source (Pen or ext_hw_event) per step, not both.

### 12.3.3 HW Preemption

When the CTRL register's HW preemption bit is enabled:
- A Pen-down during SW steps causes the sequencer to pause, complete all HW steps + charge step, then resume from the next SW step
- If preemption is disabled, touch events are ignored until all SW steps complete

### 12.3.4 DMA Operation

- Set DMAENABLE_SET to enable DMA for FIFO0 or FIFO1
- Set DMA0REQ or DMA1REQ with the desired FIFO level to trigger DMA
- When FIFO level ≥ DMAx threshold, DMA request fires
- DMA reads from FIFO0DATA (offset 100h) or FIFO1DATA (offset 200h)
- Lower address bits ignored (FIFO pointer advances internally)

---

## 12.4 Register Map

### 12.4.1 TSC_ADC_SS Registers

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | REVISION | 47300001h | IP revision |
| 10h | SYSCONFIG | 0h | IdleMode[3:2]: 00=Force, 01=No, 10=Smart, 11=Smart+Wakeup |
| 24h | IRQSTATUS_RAW | 0h | Raw interrupt status (unmasked); W1 to set for debug |
| 28h | IRQSTATUS | 0h | Masked interrupt status; W1 to clear |
| 2Ch | IRQENABLE_SET | 0h | W1 to enable interrupt sources |
| 30h | IRQENABLE_CLR | 0h | W1 to disable interrupt sources |
| 34h | IRQWAKEUP | 0h | Bit 0: enable Pen-down as wakeup source |
| 38h | DMAENABLE_SET | 0h | Bit 0=FIFO0 DMA enable, bit 1=FIFO1 DMA enable |
| 3Ch | DMAENABLE_CLR | 0h | W1 to disable DMA |
| 40h | CTRL | 0h | Enable[0], StepConfig_WriteProtect[1], AFE_Pen_Ctrl[6:5], HW_preempt_enable, TSC_ADC_SS_EN |
| 44h | ADCSTAT | 0h | Busy[0] — ADC converting; FSM step in bits [13:8] |
| 48h | ADCRANGE | 0h | High[27:16] / Low[11:0] — Out_of_Range comparison |
| 4Ch | ADC_CLKDIV | 0h | ADC clock divider: adc_clk = CLK_M_OSC / (ADC_CLKDIV + 1) |
| 50h | ADC_MISC | 0h | AFE_spare (debug) |
| 54h | STEPENABLE | 0h | Bits [16:1] = step enables (bit 1 = Step1, … bit 16 = Step16) |
| 58h | IDLECONFIG | 0h | AFE settings when FSM is IDLE: SEL_RFM, SEL_INP, SEL_INM, SEL_RFP, YPNN, YPNN, etc. |
| 5Ch | TS_CHARGE_STEPCONFIG | 0h | Charge step config (same fields as STEPCONFIGx) |
| 60h | TS_CHARGE_DELAY | 0h | OpenDelay[17:0] for charge step |
| 64h–E0h | STEPCONFIG1–16 | 0h | Step N config (64h + (N-1)×8h) |
| 68h–E4h | STEPDELAY1–16 | 0h | Step N delay (68h + (N-1)×8h) |
| E4h | FIFO0COUNT | 0h | Number of words in FIFO0 [6:0] |
| E8h | FIFO0THRESHOLD | 0h | Threshold for FIFO0 interrupt [5:0] |
| ECh | DMA0REQ | 0h | DMA0 threshold [5:0] — DMA fires when FIFO0 ≥ this |
| F0h | FIFO1COUNT | 0h | Number of words in FIFO1 [6:0] |
| F4h | FIFO1THRESHOLD | 0h | Threshold for FIFO1 interrupt [5:0] |
| F8h | DMA1REQ | 0h | DMA1 threshold [5:0] |
| 100h | FIFO0DATA | — | Read FIFO0 data [11:0] = sample; [19:16] = channel ID (if enabled) |
| 200h | FIFO1DATA | — | Read FIFO1 data [11:0] = sample; [19:16] = channel ID (if enabled) |

### 12.4.2 STEPCONFIGx Fields

| Bits | Field | Description |
|------|-------|-------------|
| 31 | FIFO_SELECT | 0=FIFO0, 1=FIFO1 |
| 30 | DIFF_CNTRL | 0=Single-ended, 1=Differential |
| 29–26 | SEL_RFP | Reference positive mux select |
| 25–23 | SEL_INM | Negative input mux select |
| 22–19 | SEL_INP | Positive input mux select (channel 0–7 → AIN0–AIN7) |
| 18–15 | SEL_RFM | Reference negative mux select |
| 14 | RANGER | 0=Normal, 1=enable ADCRANGE comparison |
| 26–24 | AVERAGING | 000=none, 001=2×, 010=4×, 011=8×, 100=16× |
| 2 | MODE | 0=SW-enabled, 1=HW-synchronized |
| 1 | (step carry bit) | SINGLE or CONTINUOUS |

### 12.4.3 STEPDELAYx Fields

| Bits | Field | Description |
|------|-------|-------------|
| 31–24 | SAMPLEDELAY | ADC sampling clock cycles (minimum 1) |
| 17–0 | OPENDELAY | Delay from driving AFE inputs to SOC signal (can be 0) |
