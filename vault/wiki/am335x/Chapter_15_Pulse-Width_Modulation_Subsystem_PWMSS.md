---
title: AM335x Chapter 15 — Pulse-Width Modulation Subsystem (PWMSS)
tags:
  - am335x
  - pwm
  - pwmss
  - ehrpwm
  - ecap
  - eqep
  - reference
source: "AM335x TRM Chapter 15"
---

# 15 Pulse-Width Modulation Subsystem (PWMSS)

## 15.1 Introduction

The AM335x contains **3 identical PWMSS instances** (PWMSS0, PWMSS1, PWMSS2). Each instance bundles:

| Submodule | Full Name | Key Capability |
|-----------|-----------|----------------|
| eHRPWM | Enhanced High-Resolution PWM | 2 PWM outputs (EPWMxA/B), 16-bit time-base, dead-band, trip-zone, HRPWM |
| eCAP | Enhanced Capture | 32-bit counter, 4 capture registers, APWM output mode |
| eQEP | Enhanced Quadrature Encoder Pulse | Position/speed measurement from incremental encoder |

### 15.1.1 Features

#### eHRPWM

| Feature | Detail |
|---------|--------|
| Time-base counter | 16-bit; period/frequency control |
| PWM outputs | EPWMxA + EPWMxB |
| Output modes | 2 independent single-edge; 2 independent dual-edge symmetric; 1 dual-edge asymmetric |
| Dead-band | Independent rising/falling edge delay |
| Trip zone | One-shot and cycle-by-cycle; force high/low/hi-Z on fault |
| ADC SOC | Trigger ADC start-of-conversion (SOCA, SOCB) from ET submodule |
| Chopper | High-frequency carrier, pulse-transformer gate drive |
| HRPWM | Programmable delay line, per-period, rising/falling edge or both |
| Sync | Daisy-chain sync in/out with other ePWM modules |

#### eCAP

| Feature | Detail |
|---------|--------|
| Counter | 32-bit |
| Capture regs | CAP1–CAP4 (32-bit each) |
| Sequencer | 4-stage Mod4 counter, triggered by external ECAPx pin edges |
| Edge polarity | Independent rising/falling selection per event |
| Pre-scale | Input capture signal pre-scaling 1–16 |
| One-shot | Freeze captures after 1–4 timestamp events |
| Continuous | 4-deep circular buffer |
| APWM mode | Use eCAP as auxiliary PWM output |

#### eQEP

| Feature | Detail |
|---------|--------|
| Decoder | Quadrature decoder unit |
| Position counter | 32-bit, with control |
| Edge capture | Low-speed measurement |
| Unit timer | Speed/frequency measurement |
| Watchdog | Stall detection |

### 15.1.2 Unsupported Features

| Feature | Reason |
|---------|--------|
| ePWM inputs (EPWMxA/B as inputs) | Not pinned out |
| ePWM tripzone inputs TZ1–TZ5 | Only TZ0 is pinned out per instance |
| ePWM digital comparators | Inputs not connected |
| eQEP quadrature outputs | Only input signals connected |
| eCAP3–5 | Module instances not used |
| eQEP3–5 | Module instances not used |

---

## 15.2 Integration

### 15.2.1 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | PD_PER_L4LS_GCLK |
| Reset | PER_DOM_RST_N |
| Idle | Smart Idle |
| Physical Address | L4 Peripheral slave port |

**Interrupts per instance:**

| Interrupt | Signal | Destination |
|-----------|--------|-------------|
| ePWM event | epwm_intr_intr_pend | MPU (ePWMxINT) + PRU-ICSS |
| ePWM trip zone | epwm_tz_intr (1 for all 3 inst) | MPU (ePWMx_TZINT) + PRU-ICSS |
| eCAP event | ecap_intr_intr_pend | MPU (eCAPxINT) + PRU-ICSS |
| eQEP event (eQEP0 only to PRU) | eqep_intr_intr_pend | MPU (eQEPxINT) + PRU-ICSS |

**DMA requests:** 1 per submodule per instance → ePWMEVTx, eCAPEVTx, eQEPEVTx

### 15.2.2 Clock Signals

| Clock Signal | Max Freq | Source | Domain |
|-------------|----------|--------|--------|
| PWMSS_ocp_clk (Interface/Functional) | 100 MHz | CORE_CLKOUTM4 / 2 | pd_per_l4ls_gclk |

### 15.2.3 Pin List

| Pin | Dir | Description |
|-----|-----|-------------|
| EPWMxA | O | PWM output A |
| EPWMxB | O | PWM output B |
| EPWM_SYNCIN | I | PWM Sync input (from chip) |
| EPWM_SYNCOUT | O | PWM Sync output (to chip) |
| EPWM_TRIPZONE[5:0] | I | Trip-zone inputs (only [0] pinned out) |
| ECAP_CAPIN_APWMOUT | I/O | eCAP capture input / APWM output |
| EQEP_A | I/O | Quadrature A input |
| EQEP_B | I/O | Quadrature B input |
| EQEP_INDEX | I/O | Index/Z input |
| EQEP_STROBE | I/O | Strobe input |

### 15.2.4 Synchronization Daisy Chain

```
External SYNCIN ──► eHRPWM0.syncin ──► eHRPWM0.syncout ──► eCAP0.syncin ──► eCAP0.syncout
                    (PWMSS0, INPUT_SYNC = 1)                (PWMSS0, INPUT_SYNC = 0)

eCAP0.syncout ──► eHRPWM1.syncin ──► eHRPWM1.syncout ──► eCAP1.syncin ──► eCAP1.syncout
                  (PWMSS1, INPUT_SYNC = 0)                (PWMSS1, INPUT_SYNC = 0)

eCAP1.syncout ──► eHRPWM2.syncin ──► eHRPWM2.syncout ──► eCAP2.syncin ──► eCAP2.syncout
                  (PWMSS2, INPUT_SYNC = 0)                (PWMSS2, INPUT_SYNC = 0)
```

eCAP capture event input is selected via `ECAPx_EVTCAPT` field in `ECAP_EVT_CAP` register of the Control Module (mux from 31 chip events or internal interrupt signals).

---

## 15.3 PWMSS Wrapper Registers

Base address per instance: PWMSS0=48300000h, PWMSS1=48302000h, PWMSS2=48304000h

### 15.3.1 Register Map

| Offset | Register | Reset | Description |
|--------|----------|-------|-------------|
| 0h | IDVER | 40000000h | IP revision: SCHEME[31:30], FUNC[27:16], R_RTL[15:11], X_MAJOR[10:8], CUSTOM[7:6], Y_MINOR[5:0] |
| 4h | SYSCONFIG | 28h | STANDBYMODE[5:4], IDLEMODE[3:2], FREEEMU[1], SOFTRESET[0] |
| 8h | CLKCONFIG | 111h | Per-submodule clock enable and stop request control |
| Ch | CLKSTATUS | 0h | Per-submodule clock enable ack and stop ack status (read-only) |

### 15.3.2 CLKCONFIG Register (offset = 8h, reset = 111h)

| Bit | Field | Reset | Description |
|-----|-------|-------|-------------|
| 9 | ePWMCLKSTOP_REQ | 0h | clkstop_req to ePWM |
| 8 | ePWMCLK_EN | 1h | clk_en to ePWM (1=enabled) |
| 5 | eQEPCLKSTOP_REQ | 0h | clkstop_req to eQEP |
| 4 | eQEPCLK_EN | 1h | clk_en to eQEP (1=enabled) |
| 1 | eCAPCLKSTOP_REQ | 0h | clkstop_req to eCAP |
| 0 | eCAPCLK_EN | 1h | clk_en to eCAP (1=enabled) |

### 15.3.3 CLKSTATUS Register (offset = Ch, reset = 0h)

| Bit | Field | Description |
|-----|-------|-------------|
| 9 | ePWM_CLKSTOP_ACK | clkstop_req_ack from ePWM (read-only) |
| 8 | ePWM_CLK_EN_ACK | clk_en ack from ePWM (read-only) |
| 5 | eQEP_CLKSTOP_ACK | clkstop_req_ack from eQEP (read-only) |
| 4 | eQEP_CLK_EN_ACK | clk_en ack from eQEP (read-only) |
| 1 | eCAP_CLKSTOP_ACK | clkstop_req_ack from eCAP (read-only) |
| 0 | eCAP_CLK_EN_ACK | clk_en ack from eCAP (read-only) |

---

## 15.4 eHRPWM Submodule

Base offset within PWMSS: +200h (eHRPWM registers start at PWMSS_BASE + 200h)

### 15.4.1 Submodule Architecture

```
Time-Base (TB) ──► Counter-Compare (CC) ──► Action-Qualifier (AQ) ──► Dead-Band (DB)
                                                                         │
                                                                         ▼
Trip-Zone (TZ) ──────────── Force override ──────────────────────► PWM-Chopper (PC) ──► EPWMxA/B
                                                                    
Event-Trigger (ET) triggers: CPU interrupt (EPWM_INT) + ADC SOC (SOCA/SOCB)
```

### 15.4.2 Time-Base (TB) Submodule

**Counter modes:**

| Mode | TBCTL.CTRMODE[1:0] | Behavior |
|------|-------------------|----------|
| Up-count | 00 | Count 0→TBPRD, reload at TBPRD |
| Down-count | 01 | Count TBPRD→0 |
| Up-down-count | 10 | Count 0→TBPRD→0 (symmetric) |
| Stop-freeze | 11 | Counter stopped |

**Period/Frequency calculation:**

```
TBCLK = SYSCLKOUT / (HSPCLKDIV × CLKDIV)
T_pwm = (TBPRD + 1) × TBCLK          ← up/down count
T_pwm = 2 × TBPRD × TBCLK            ← up-down count
```

**Sync:** `TBCTL.PHSEN` + `TBPHS` enable phase load on sync event. `TBCTL.SYNCOSEL` selects syncout source: CTR=0 (0h), CTR=CMPB (1h), syncin (2h), disable (3h).

**Key TB registers:**

| Offset | Register | Description |
|--------|----------|-------------|
| 0h | TBCTL | Counter mode, clock div, phase enable, syncout sel |
| 2h | TBSTS | Synch flag, direction |
| 4h | TBPHSHR | HRPWM phase MSBs |
| 6h | TBPHS | Phase register (loaded on sync) |
| 8h | TBCNT | Live 16-bit counter value |
| Ah | TBPRD | Period register (shadow) |

### 15.4.3 Counter-Compare (CC) Submodule

**Compare registers:** CMPA, CMPB (16-bit each). Shadow loading controlled by `CMPCTL.LOADAMODE` / `LOADBMODE`:

| Code | Load on |
|------|---------|
| 00 | CTR=0 |
| 01 | CTR=TBPRD |
| 10 | Either (first event) |
| 11 | Freeze (no shadow) |

**Key CC registers:**

| Offset | Register | Description |
|--------|----------|-------------|
| Ch | CMPCTL | Shadow/load mode for CMPA, CMPB |
| Eh | CMPAHR | HRPWM compare A high-res extension |
| 10h | CMPA | Counter-compare A value |
| 12h | CMPB | Counter-compare B value |

### 15.4.4 Action-Qualifier (AQ) Submodule

Determines EPWMxA and EPWMxB pin actions on time-base and compare events.

**Actions per event:** 0=Do nothing, 1=Force low, 2=Force high, 3=Toggle

**Event priority (highest to lowest):** SW force > TZ > AQ_CTR=PRD > AQ_CTR=0 > AQ_CMPB_D > AQ_CMPB_U > AQ_CMPA_D > AQ_CMPA_U

**Key AQ registers:**

| Offset | Register | Description |
|--------|----------|-------------|
| 14h | AQCTLA | Actions on EPWMxA for TB/CC events |
| 16h | AQCTLB | Actions on EPWMxB for TB/CC events |
| 18h | AQSFRC | SW force output (immediate) on EPWMxA/B |
| 1Ah | AQCSFRC | Continuous SW force on EPWMxA/B |

### 15.4.5 Dead-Band (DB) Submodule

Inserts rising-edge delay (RED) and/or falling-edge delay (FED) between EPWMxA and EPWMxB.

**Key DB registers:**

| Offset | Register | Description |
|--------|----------|-------------|
| 1Ch | DBCTL | Input/output mode, polarity select |
| 1Eh | DBRED | Rising-edge delay count |
| 20h | DBFED | Falling-edge delay count |

### 15.4.6 Trip-Zone (TZ) Submodule

On TZx assertion: force EPWMxA/EPWMxB to hi/lo/hi-Z. Two modes: one-shot (latch, requires SW clear) and cycle-by-cycle (auto-reset each cycle).

**Key TZ registers:**

| Offset | Register | Description |
|--------|----------|-------------|
| 22h | TZSEL | Trip-zone select (TZ1–TZ6 enable for CBC/OST) |
| 24h | TZCTL | Action on EPWMxA/B for trip event |
| 26h | TZEINT | Enable trip zone interrupts |
| 28h | TZFLG | Trip flag status (latch) |
| 2Ah | TZCLR | W1 to clear TZFLG bits |
| 2Ch | TZFRC | SW force trip-zone event |

### 15.4.7 Event-Trigger (ET) Submodule

Generates CPU interrupt and/or ADC SOC on configurable time-base events.

**Key ET registers:**

| Offset | Register | Description |
|--------|----------|-------------|
| 34h | ETSEL | Select event for INT, SOCA, SOCB (CTR=0, CTR=TBPRD, CTR=CMPA_U, etc.) |
| 36h | ETPS | Prescale: generate int/SOC every 1/2/3 events |
| 38h | ETFLG | Pending flags (INT, SOCA, SOCB) [read-only] |
| 3Ah | ETCLR | W1 to clear ETFLG bits |
| 3Ch | ETFRC | SW force interrupt/SOC |

### 15.4.8 HRPWM Submodule

Provides sub-cycle resolution by controlling a delay line on EPWMxA (rising or falling edge).

**Key HR registers:**

| Offset | Register | Description |
|--------|----------|-------------|
| Eh | CMPAHR | MEP value for rising edge (8-bit, bits [7:0] = MEP step count) |
| 4h | TBPHSHR | HR extension for phase |

MEP (Micro Edge Positioner) step = `T_STEP = T_SYSCLK / (MEP_ScaleFactor)`. Calibrated via SFO algorithm.

---

## 15.5 eCAP Submodule

Base offset within PWMSS: +100h

### 15.5.1 Operating Modes

| Mode | Description |
|------|-------------|
| Capture mode | Timestamp external events on ECAPx pin; store in CAP1–CAP4 FIFO |
| APWM mode | Use 32-bit counter as single PWM output (duty/period in CAP1/CAP2) |

### 15.5.2 Key eCAP Registers

| Offset | Register | Description |
|--------|----------|-------------|
| 0h | TSCTR | 32-bit time-stamp counter |
| 4h | CTRPHS | Counter phase for sync |
| 8h | CAP1 | Capture register 1 / APWM period |
| Ch | CAP2 | Capture register 2 / APWM compare |
| 10h | CAP3 | Capture register 3 |
| 14h | CAP4 | Capture register 4 |
| 28h | ECCTL1 | Capture control 1: prescale, edge select per event |
| 2Ah | ECCTL2 | Capture control 2: mode (cap/APWM), one-shot/continuous, sync |
| 2Ch | ECEINT | Interrupt enable |
| 2Eh | ECFLG | Interrupt flag |
| 30h | ECCLR | W1 to clear flags |
| 32h | ECFRC | SW force interrupt |

---

## 15.6 eQEP Submodule

Base offset within PWMSS: +180h

### 15.6.1 Key eQEP Registers

| Offset | Register | Description |
|--------|----------|-------------|
| 0h | QPOSCNT | Position counter (32-bit) |
| 4h | QPOSINIT | Position initialize value |
| 8h | QPOSMAX | Maximum position value |
| Ch | QPOSCMP | Position compare register |
| 10h | QIDC | Index event latch of QPOSCNT |
| 14h | QPOSIDX | eQEP index position counter |
| 18h | QPOSSR | Strobe event position counter latch |
| 1Ch | QPOSLAT | Position counter latch on unit time-out |
| 20h | QUTMR | QEP unit timer (32-bit) |
| 24h | QUPRD | QEP unit period (32-bit) |
| 28h | QWDTMR | Watchdog timer value |
| 2Ah | QWDPRD | Watchdog period |
| 2Ch | QDECCTL | Quadrature decoder control |
| 2Eh | QEPCTL | QEP control: position counter init, latch, unit timer enable |
| 30h | QCAPCTL | QEP capture control: UPPS, CCPS |
| 32h | QPOSCTL | Position compare control |
| 34h | QEINT | Interrupt enable |
| 36h | QFLG | Interrupt/status flags |
| 38h | QCLR | W1 to clear QFLG bits |
| 3Ah | QFRC | SW force |
| 3Ch | QEPSTS | QEP status (direction, overflow ...) |
| 3Eh | QCTMR | QEP capture timer (16-bit) |
| 40h | QCPRD | Capture period (16-bit) |
| 42h | QCTMRLAT | QCTMR latch |
| 44h | QCPRDLAT | QCPRD latch |

---

## 15.7 Software Operation

### 15.7.1 eHRPWM Initialization

1. **PRCM**: Enable PWMSS clock (`pd_per_l4ls_gclk`), de-assert reset
2. **CLKCONFIG**: Set `ePWMCLK_EN=1` (already reset=1), optionally `eQEPCLK_EN/eCAPCLK_EN`
3. **TBCTL**: Set `CTRMODE`, `HSPCLKDIV`, `CLKDIV`
4. **TBPRD**: Set period
5. **TBPHS**: Set phase if using sync
6. **CMPCTL**: Set `LOADAMODE`/`LOADBMODE`
7. **CMPA/CMPB**: Set duty cycle compare values
8. **AQCTLA/AQCTLB**: Set output actions
9. **DBCTL/DBRED/DBFED**: Configure dead-band if needed
10. **TZSEL**: Select trip zones if used; **TZCTL**: set fault actions
11. **ETSEL**: Select interrupt event; **ETPS**: set prescale
12. **TBCTL.CTRMODE**: Clear STOP-FREEZE to desired mode (start counting)

### 15.7.2 Proper Interrupt Initialization

> [!IMPORTANT]
> Clear any spurious interrupt flags before enabling the interrupt to the CPU:
> 1. Write `ETCLR.INT=1` to clear any pending ET flag
> 2. Then write `ETEINT.INTEN=1` to enable interrupt
> 3. Enable the peripheral interrupt in the MPU interrupt controller

### 15.7.3 eCAP Capture Initialization

1. Enable `eCAPCLK_EN` in CLKCONFIG
2. Configure `ECCTL1`: edge polarity per CAP1–4, prescale
3. Configure `ECCTL2`: capture mode or APWM mode, continuous/one-shot
4. Enable interrupts via `ECEINT`
5. Start counter: `ECCTL2.TST_STOP=0`
