---
title: AM335x Chapter 8 Power, Reset, and Clock Management (PRCM)
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 8 Power, Reset, and Clock Management (PRCM)

## 8.1 Architecture Overview

Three-level hierarchy: **Clock Management** → **Power Management** → **Voltage Management**, all organized around **domains** (groups sharing a common clock source, power switch, or voltage source).

---

## 8.2 Clock Management

### 8.2.1 Clock Types

| Type             | Suffix  | Purpose                                                   |
| ---------------- | ------- | --------------------------------------------------------- |
| Interface Clock  | `_ICLK` | Interconnect interface and module registers               |
| Functional Clock | `_FCLK` | Module functional operation; may be mandatory or optional |

### 8.2.2 Module Clock Protocols

**Master Standby Protocol** (initiator modules) — configured via `<Module>_SYSCONFIG.MIDLEMODE` or `STANDBYMODE`:

| Value | Mode                         | Description                                         |
| ----- | ---------------------------- | --------------------------------------------------- |
| 0x0   | Force-standby                | Unconditionally asserts standby; risk of data loss  |
| 0x1   | No-standby                   | Never asserts standby; not power-efficient          |
| 0x2   | Smart-standby                | Asserts standby only when all transactions complete |
| 0x3   | Smart-standby wakeup-capable | Smart-standby + can generate wakeup events          |

Standby status: `CM_<domain>_<Module>_CLKCTRL.STBYST` (0=functional, 1=standby).

**Slave Idle Protocol** (target modules) — configured via `<Module>_SYSCONFIG.SIDLEMODE` or `IDLEMODE`:

| Value | Mode                      | Description                                              |
| ----- | ------------------------- | -------------------------------------------------------- |
| 0x0   | Force-idle                | Unconditionally acknowledges idle; risk of data loss     |
| 0x1   | No-idle                   | Never acknowledges idle; not power-efficient             |
| 0x2   | Smart-idle                | Acknowledges idle only when internal operations complete |
| 0x3   | Smart-idle wakeup-capable | Smart-idle + can generate wakeup events                  |

Idle status: `CM_<domain>_<Module>_CLKCTRL.IDLEST` (0x0=Functional, 0x1=Transition, 0x2=Idle, 0x3=Disabled).

**Module Mode:** `CM_<domain>_<Module>_CLKCTRL.MODULEMODE` — 0x0=Disabled, 0x2=Enabled (0x1, 0x3 reserved).

### 8.2.3 Clock Domain States

| State           | Description                                                                           |
| --------------- | ------------------------------------------------------------------------------------- |
| ACTIVE          | All non-disabled modules out of IDLE; all clocks active                               |
| IDLE_TRANSITION | All master modules in STANDBY; idle request to slaves; functional clocks still active |
| INACTIVE        | All clocks gated; all slaves IDLE                                                     |

Clock transition control: `CM_<domain>_CLKSTCTRL.CLKTRCTRL` — 0x0=NO_SLEEP, 0x1=SW_SLEEP, 0x2=SW_WKUP.

---

## 8.3 Power Management

### 8.3.1 Power Domain States

**Logic area:** ON, OFF.  
**Memory area:** ON, RETENTION (reduced voltage, contents preserved), OFF (contents lost).

**Control:** `PM_<domain>_PWRSTCTRL[1:0].POWERSTATE` — 0x0=OFF, 0x1=RETENTION, 0x3=ON.  
**Status:** `PM_<domain>_PWRSTST[1:0].POWERSTATEST`, `.LOGICSTATEST`, `.MEMSTATEST`.

### 8.3.2 AM335x Power Domains

| Domain  | Description                        |
| ------- | ---------------------------------- |
| PD_WKUP | Wakeup domain — always ON          |
| PD_MPU  | MPU subsystem (Cortex-A8)          |
| PD_PER  | Peripheral domain                  |
| PD_RTC  | RTC domain                         |
| PD_GFX  | Graphics domain (SGX530; optional) |

### 8.3.3 Adaptive Voltage Scaling (AVS)

Smart Reflex-based automatic voltage control adapts supply voltage to silicon performance, reducing active power. Can operate statically (predefined performance points) or dynamically (real-time temperature/performance).

---

## 8.4 Power Modes

| Mode       | Main Osc              | PD_MPU | PD_PER  | DDR          | Context Loss   | Wakeup Latency                  |
| ---------- | --------------------- | ------ | ------- | ------------ | -------------- | ------------------------------- |
| Active     | ON (all DPLLs locked) | ON     | ON      | Active       | None           | N/A                             |
| Standby    | ON (DPLLs bypass)     | OFF    | ON      | Self-refresh | MPU only       | Low                             |
| DeepSleep1 | **OFF**               | OFF    | ON      | Self-refresh | MPU only       | Medium                          |
| DeepSleep0 | OFF                   | OFF    | **OFF** | Self-refresh | All except DDR | High                            |
| RTC-Only   | OFF                   | OFF    | OFF     | **OFF**      | All            | Extremely high (full cold boot) |

**Voltages in low-power modes:** VDD_MPU = VDD_CORE = 0.95 V (OPP50); RTC-Only: VDD_MPU = VDD_CORE = 0 V.

**DeepSleep0 specifics:** All power domains off except PD_WKUP and PD_RTC. OCMC RAM powered to preserve internal information. VDD_CORE to DPLLs turned off via `dpll_pwr_sw_ctrl` (PG 2.x). Boot ROM checks DeepSleep0 resume state on wakeup.

**RTC-Only wakeup sources:** `ext_wakeup0` signal only; RTC Alarm only. Device drives `pmic_pwr_enable` to initiate PMIC power-up; full cold boot required.

---

## 8.5 Wakeup Sources (PD_WKUP, always ON)

GPIO0 bank, dmtimer1_1ms, USB2PHY (both ports), TSC, UART0, I2C0, RTC alarm.

### 8.5.1 USB Wakeup

Two wakeup event types:

- **PHY WKUP:** Internal wakeup to Cortex-M3 based on USB signaling.
- **VBUS2GPIO:** External wakeup from VBUS level change on GPIO (requires board-level routing with level shifting).

| State       | USB Ctrl State | Mode   | Supported | Event                                                     |
| ----------- | -------------- | ------ | --------- | --------------------------------------------------------- |
| DS0         | POWER OFF      | Device | Yes       | VBUS2GPIO                                                 |
| DS1/Standby | Clock Gated    | Host   | Yes       | PHY WKUP                                                  |
| DS1/Standby | Clock Gated    | Device | Yes       | PHY WKUP (suspend/resume), VBUS2GPIO (connect/disconnect) |

**DeepSleep1 is the minimum sleep mode required for USB wakeup scenarios.**

### 8.5.2 Main Oscillator Control (Deep Sleep)

`DEEPSLEEP_CTRL.DSENABLE = 1` activates oscillator control. `DEEPSLEEP_CTRL.DSCOUNT` sets delay before re-enabling oscillator after wakeup. Oscillator disabled when Cortex-M3 enters WFI; re-enabled by any async wakeup event after DSCOUNT delay.

---

## 8.6 Cortex-M3 Power Management Role

**Architecture:** Cortex-A8 runs application; Cortex-M3 (in PD_WKUP) handles low-level power sequencing. Not expected to be active simultaneously.

**IPC Registers (Control Module base 0x44E10400):**

| Register             | Offset | Direction | Purpose         |
| -------------------- | ------ | --------- | --------------- |
| IPC_MSG_REG0 [15:0]  | 0x400  | MPU→CM3   | CMD_STAT        |
| IPC_MSG_REG0 [31:16] | 0x400  | MPU→CM3   | CMD_ID          |
| IPC_MSG_REG1         | 0x404  | MPU→CM3   | CMD param1      |
| IPC_MSG_REG2         | 0x408  | MPU→CM3   | CMD param2      |
| IPC_MSG_REG3         | 0x40C  | CM3→MPU   | Response/status |
| IPC_MSG_REG7         | 0x41C  | Both      | Customer use    |

**CMD_STAT values:** 0x0=PASS, 0x1=FAIL, 0x2=WAIT4OK.

**CMD_ID values:**

- 0x1 = CMD_RTC — force sleep on clocks; turn off MPU+PER; program RTC alarm to deassert `pmic_pwr_enable`.
- 0x2 = CMD_RTC_FAST — program RTC alarm only.
- 0x3 = CMD_DS0 — force sleep; turn off MPU+PER; configure MOSC disable.
- 0x5 = CMD_DS1 — force sleep; turn off MPU only; configure MOSC disable.

### 8.6.1 Sleep Sequence (Summary)

1. Save peripheral context to DDR (required for DeepSleep0).
2. Turn off unused power domains; save contexts to `L3_OCMC_RAM`.
3. Execute WFI from SRAM.
4. Peripheral interrupt → wakeup to Cortex-M3 via MPU WKUP signal.
5. Cortex-M3 performs low-level sequencing (power-down domains, configure oscillator control) → executes WFI.
6. Hardware disables oscillator.

### 8.6.2 Wakeup Sequence (Summary)

1. Wakeup event → oscillator re-enabled (if OFF) → interrupt to Cortex-M3.
2. Cortex-M3: restores voltages → enables PLL locking → switches ON PD_PER → switches ON PD_MPU → executes WFI.
3. Cortex-A8 starts from ROM reset vector; restores application context (DeepSleep0 only).

---

## 8.7 Reset Management

### 8.7.1 Reset Types

| Type       | Description                                                            |
| ---------- | ---------------------------------------------------------------------- |
| Cold Reset | All logic and memories reset; full boot; SYSBOOT pins re-latched       |
| Warm Reset | Subset reset; PLLs/dividers/clocks intact; SYSBOOT pins NOT re-latched |

### 8.7.2 Reset Sources

| Source             | Type      | Description                                                                                             |
| ------------------ | --------- | ------------------------------------------------------------------------------------------------------- |
| PORz               | Cold      | External pin; all supplies stable → internal reset; `nRESETIN_OUT` driven after RSTTIME1+RSTTIME2 delay |
| nRESETIN_OUT       | Warm      | Bidirectional; all IOs tri-state immediately on assertion                                               |
| GLOBAL_COLD_SW_RST | Cold      | `PRM_RSTCTRL.RST_GLOBAL_COLD_SW` (self-clearing)                                                        |
| GLOBAL_WARM_SW_RST | Warm      | `PRM_RSTCTRL.RST_GLOBAL_WARM_SW` (self-clearing)                                                        |
| WDT1_RST           | Warm      | Watchdog Timer 1 timeout                                                                                |
| ICEPICK_RST        | Cold/Warm | ICEPick emulation module reset                                                                          |
| Bad Device Reset   | Cold      | Unsupported `DEVICE_TYPE` encoding                                                                      |

**Note:** All IPs with local CPUs have local reset asserted by default at Warm Reset. Deassertion requires host processor to write respective PRCM registers.

**Reset deassertion timing:** `PRM_RSTTIME[9:0] RSTTIME1` — RSTTIME1 delay in 32 kHz clock cycles; `PRM_RSTTIME[14:10] RSTTIME2` — remaining peripherals released.

---

## 8.8 Clock Generation

### 8.8.1 DPLL Types

- **ADPLLS:** Core PLL, MPU PLL, Display PLL, DDR PLL
- **ADPLLLJ:** Peripheral PLL (low jitter; used for peripheral functional clocks)

All PLLs come up in **bypass mode** at reset. Software must program all PLL settings and wait for lock.

**Reference clocks:** Main oscillator `CLK_M_OSC`; 32 kHz crystal oscillator (RTC); on-chip RC oscillator (always on).

### 8.8.2 ADPLLS Output Frequencies (REGM4XEN='0', locked)

| Clock                        | Frequency                         |
| ---------------------------- | --------------------------------- |
| CLKOUT                       | [M / (N+1)] × CLKINP × [1/M2]     |
| CLKOUTX2                     | 2 × [M / (N+1)] × CLKINP × [1/M2] |
| CLKDCOLDO                    | 2 × [M / (N+1)] × CLKINP          |
| CLKOUTHIF (CLKINPHIFSEL='0') | 2 × [M / (N+1)] × CLKINP × [1/M3] |

When `REGM4XEN='1'`: multiply M by 4 in all formulas above.

Before lock / bypass: `CLKOUT = CLKINP / (N2+1)` (ULOWCLKEN='0') or `CLKOUT = CLKINPULOW` (ULOWCLKEN='1').

### 8.8.3 Core PLL Typical Frequencies

| Clock                       | Source          | OPP100 Div | OPP100 Freq (MHz) | OPP50 Freq (MHz) |
| --------------------------- | --------------- | ---------- | ----------------- | ---------------- |
| CLKDCOLDO                   | ADPLLS          | —          | 2000              | 100              |
| CORE_CLKOUTM4 (L3F_CLK)     | HSDIVIDER-M4    | /10        | 200               | 100              |
| CORE_CLKOUTM5 (MHZ_250_CLK) | HSDIVIDER-M5    | /8         | 250               | 100              |
| CORE_CLKOUTM6               | HSDIVIDER-M6    | /4         | 500               | 100              |
| L4_PER / L4_WKUP            | CORE_CLKOUTM4/2 | /2         | 100               | 50               |

Derived from MHZ_250_CLK (M5): MHZ_125_CLK=/2, MHZ_50_CLK=/5, MHZ_5_CLK=/50.

**Core PLL configuration sequence:**

1. `CM_CLKMODE_DPLL_CORE.DPLL_EN = 0x4` (MN bypass).
2. Wait `CM_IDLEST_DPLL_CORE.ST_MN_BYPASS = 1`.
3. Set `CM_CLKSEL_DPLL_CORE.DPLL_MULT` and `DPLL_DIV`.
4. Set M4/M5/M6 dividers in `CM_DIV_M4/M5/M6_DPLL_CORE`.
5. `CM_CLKMODE_DPLL_CORE.DPLL_EN = 0x7` (lock).
6. Wait `CM_IDLEST_DPLL_CORE.ST_DPLL_CLK = 1`.

Note: M4, M5, M6 dividers can be changed on-the-fly without bypassing PLL.

### 8.8.4 Peripheral PLL Typical Frequencies

Locked at 960 MHz.

| Clock                                       | OPP100 (MHz) |
| ------------------------------------------- | ------------ |
| USB_PHY_CLK (CLKDCOLDO)                     | 960          |
| PER_CLKOUTM2 (M2=5)                         | 192          |
| MMC_CLK (PER_CLKOUTM2/2)                    | 96           |
| SPI_CLK, UART_CLK, I2C_CLK (PER_CLKOUTM2/4) | 48           |
| PRU_ICSS_UART_CLK                           | 96           |
| CLK_32KHZ (48 MHz / ~1464.8)                | 32.768 kHz   |

### 8.8.5 Bus Interface Clock Assignments

| Clock       | Key Modules                                                                             |
| ----------- | --------------------------------------------------------------------------------------- |
| L3F_CLK     | SGX530, LCDC, MPUSS, CPSW, EMIF, TPTC, TPCC, OCMC RAM, AES, SHA                         |
| L3S_CLK     | USB, TSC, GPMC, MMCHS2, McASP0/1                                                        |
| L4_PER_CLK  | DCAN0/1, DMTIMER2–7, eCAP/eQEP/ePWM0–2, ELM, GPIO1–3, I2C1/2, MMCHS0/1, SPI0/1, UART1–5 |
| L4_WKUP_CLK | ADC_TSC, Control Module, DMTIMER0/1, GPIO0, I2C0, SmartReflex0/1, UART0, WDT0/1         |

### 8.8.6 Spread Spectrum Clocking (SSC)

Enabled via `CM_CLKMODE_DPLL_xxx.DPLL_SSC_EN`.

Peak power reduction (dB) = 10 × log((Deviation × fc) / fm)  
where Deviation = Δf/fc, fc = original clock frequency (MHz), fm = spreading frequency (MHz).

**Constraints:** M − ΔM ≥ 20; M + ΔM ≤ 2045; fm < Fref/70.  
Downspread (`DPLL_SSC_DOWNSPREAD=1`): lower-side spread = 2× programmed value, upper side = 0; M − 2×ΔM ≥ 20.

---

## 8.9 PRCM Register Summary

### 8.9.1 Clock Module Register Groups

| Group     | Base Address | Purpose                        |
| --------- | ------------ | ------------------------------ |
| CM_PER    | 0x44E00000   | Peripheral clock management    |
| CM_WKUP   | 0x44E00400   | Wakeup domain clock management |
| CM_DPLL   | 0x44E00500   | DPLL configuration and control |
| CM_MPU    | 0x44E00600   | MPU clock management           |
| CM_DEVICE | 0x44E00700   | Device-level clock control     |
| CM_RTC    | 0x44E00800   | RTC clock management           |
| CM_GFX    | 0x44E00900   | Graphics clock management      |
| CM_CEFUSE | 0x44E00A00   | eFuse clock management         |

### 8.9.2 Common Clock Register Fields

**CLKSTCTRL registers:**

- `CLKACTIVITY_*` [31:8] (R): 0=Gated, 1=Active.
- `CLKTRCTRL` [1:0] (R/W): 0x0=NO_SLEEP, 0x1=SW_SLEEP, 0x2=SW_WKUP.

**CLKCTRL registers:**

- `STBYST` [18] (R): 0=Functional, 1=Standby.
- `IDLEST` [17:16] (R): 0x0=Functional, 0x1=Transition, 0x2=Idle, 0x3=Disabled.
- `MODULEMODE` [1:0] (R/W): 0x0=Disabled, 0x2=Enabled.

### 8.9.3 Key CM_PER Registers (Base: 0x44E00000, selected)

| Offset | Register                | Purpose                 |
| ------ | ----------------------- | ----------------------- |
| 0x00   | CM_PER_L4LS_CLKSTCTRL   | L4LS clock domain       |
| 0x14   | CM_PER_CPGMAC0_CLKCTRL  | CPSW clock              |
| 0x1C   | CM_PER_USB0_CLKCTRL     | USB0 clock              |
| 0x28   | CM_PER_EMIF_CLKCTRL     | EMIF (DDR) clock        |
| 0x2C   | CM_PER_OCMCRAM_CLKCTRL  | On-chip RAM clock       |
| 0x30   | CM_PER_GPMC_CLKCTRL     | GPMC clock              |
| 0x3C   | CM_PER_MMC0_CLKCTRL     | MMC0 clock              |
| 0x40   | CM_PER_ELM_CLKCTRL      | ELM clock               |
| 0x60   | CM_PER_L4LS_CLKCTRL     | L4LS interconnect clock |
| 0xBC   | CM_PER_TPCC_CLKCTRL     | EDMA TPCC clock         |
| 0xE8   | CM_PER_PRU_ICSS_CLKCTRL | PRU-ICSS clock          |
| 0xF4   | CM_PER_MMC1_CLKCTRL     | MMC1 clock              |
| 0xF8   | CM_PER_MMC2_CLKCTRL     | MMC2 clock              |
| 0x110  | CM_PER_MAILBOX0_CLKCTRL | Mailbox0 clock          |
| 0x144  | CM_PER_CPSW_CLKSTCTRL   | CPSW clock domain       |

### 8.9.4 Key CM_WKUP Registers (Base: 0x44E00400, selected)

| Offset | Register                | Purpose                      |
| ------ | ----------------------- | ---------------------------- |
| 0x00   | CM_WKUP_CLKSTCTRL       | Wakeup clock domain          |
| 0x08   | CM_WKUP_GPIO0_CLKCTRL   | GPIO0 clock                  |
| 0x20   | CM_IDLEST_DPLL_MPU      | MPU DPLL lock status         |
| 0x2C   | CM_CLKSEL_DPLL_MPU      | MPU DPLL M/N config          |
| 0x34   | CM_IDLEST_DPLL_DDR      | DDR DPLL lock status         |
| 0x40   | CM_CLKSEL_DPLL_DDR      | DDR DPLL M/N config          |
| 0x5C   | CM_IDLEST_DPLL_CORE     | Core DPLL lock status        |
| 0x68   | CM_CLKSEL_DPLL_CORE     | Core DPLL M/N config         |
| 0x70   | CM_IDLEST_DPLL_PER      | PER DPLL lock status         |
| 0x80   | CM_DIV_M4_DPLL_CORE     | Core DPLL M4 (L3F_CLK)       |
| 0x84   | CM_DIV_M5_DPLL_CORE     | Core DPLL M5 (MHZ_250_CLK)   |
| 0x88   | CM_CLKMODE_DPLL_MPU     | MPU DPLL mode                |
| 0x90   | CM_CLKMODE_DPLL_CORE    | Core DPLL mode               |
| 0xA8   | CM_DIV_M2_DPLL_MPU      | MPU DPLL M2 divider          |
| 0xB0   | CM_WKUP_WKUP_M3_CLKCTRL | Cortex-M3 clock              |
| 0xB4   | CM_WKUP_UART0_CLKCTRL   | UART0 clock                  |
| 0xD8   | CM_DIV_M6_DPLL_CORE     | Core DPLL M6 (CORE_CLKOUTM6) |

### 8.9.5 CM_DPLL CLKSEL Registers (Base: 0x44E00500)

| Offset     | Register                | Reset | Description                                                    |
| ---------- | ----------------------- | ----- | -------------------------------------------------------------- |
| 0x04       | CLKSEL_TIMER7_CLK       | 0x1   | 0=TCLKIN, 1=CLK_M_OSC, 2=CLK_32KHZ                             |
| 0x08–0x10  | CLKSEL_TIMER2–4_CLK     | 0x1   | Same as Timer7                                                 |
| 0x18, 0x1C | CLKSEL_TIMER5/6_CLK     | 0x1   | Same as Timer7                                                 |
| 0x28       | CLKSEL_TIMER1MS_CLK     | 0x0   | 0=CLK_RC32K, 1=CLK_32K_RTC, 2=TCLKIN, 3=CLK_M_OSC, 4=CLK_32KHZ |
| 0x2C       | CLKSEL_GFX_FCLK         | —     | [1] CLKSEL, [0] CLKDIV_SEL                                     |
| 0x30       | CLKSEL_PRU_ICSS_OCP_CLK | —     | 0=L3F clock, 1=DISP DPLL clock                                 |
| 0x34       | CLKSEL_LCDC_PIXEL_CLK   | —     | 0=DISP DPLL, 1=Core M5, 2=PER M2                               |
| 0x38       | CLKSEL_WDT1_CLK         | —     | 0=CLK_RC32K, 1=CLK_32KHZ                                       |
| 0x3C       | CLKSEL_GPIO0_DBCLK      | —     | 0=CLK_RC32K, 1=CLK_32K_RTC, 2=CLK_32KHZ                        |

### 8.9.6 CM_CLKMODE_DPLL_xxx Key Fields

| Bits  | Field               | Description                                      |
| ----- | ------------------- | ------------------------------------------------ |
| [23]  | DPLL_SSC_ACK        | SSC acknowledgment                               |
| [22]  | DPLL_SSC_DOWNSPREAD | 0=Center spread, 1=Downspread                    |
| [12]  | DPLL_SSC_EN         | SSC enable                                       |
| [6]   | DPLL_DRIFTGUARD_EN  | Drift guard / recalibration enable               |
| [2:0] | DPLL_EN             | 0x4=MN bypass, 0x5=Idle bypass LP, 0x7=Lock mode |

### 8.9.7 CM_IDLEST_DPLL_xxx Key Fields

| Bits | Field        | Description                  |
| ---- | ------------ | ---------------------------- |
| [8]  | ST_MN_BYPASS | 0=Not in bypass, 1=In bypass |
| [0]  | ST_DPLL_CLK  | 0=Unlocked, 1=Locked         |

### 8.9.8 CM_CLKSEL_DPLL_xxx Key Fields

| Bits   | Field     | Description           |
| ------ | --------- | --------------------- |
| [22:8] | DPLL_MULT | Multiplier M [2–2047] |
| [6:0]  | DPLL_DIV  | Divider N [0–127]     |

Fref = Finp / (N+1); Fdpll = Fref × M; Fout = Fdpll / M2.

**M2 divider:** `CM_DIV_M2_DPLL_xxx[4:0] DPLL_CLKOUT_DIV` — actual divisor = value + 1. Can be changed on-the-fly.

---

### 8.10 Power Management Register Groups

| Group      | Base Address | Purpose                            |
| ---------- | ------------ | ---------------------------------- |
| PRM_IRQ    | 0x44E00B00   | PRM interrupt status/enable        |
| PRM_PER    | 0x44E00C00   | Peripheral power domain            |
| PRM_WKUP   | 0x44E00D00   | Wakeup power domain                |
| PRM_MPU    | 0x44E00E00   | MPU power domain                   |
| PRM_DEVICE | 0x44E00F00   | Device-level power (reset control) |
| PRM_RTC    | 0x44E01000   | RTC power domain                   |
| PRM_GFX    | 0x44E01100   | Graphics power domain              |
| PRM_CEFUSE | 0x44E01200   | eFuse power domain                 |

### 8.10.1 PM_xxx_PWRSTCTRL Key Fields

| Bits                     | Field               | Description                    |
| ------------------------ | ------------------- | ------------------------------ |
| [1:0]                    | POWERSTATE          | 0x0=OFF, 0x1=RETENTION, 0x3=ON |
| [3]                      | LogicRETState       | 0=Logic off, 1=Logic retention |
| [4]                      | LowPowerStateChange | Low power state change request |
| [5:4] or domain-specific | MEM_x_RETSTATE      | 0=OFF, 1=RETENTION             |
| [3:2] or domain-specific | MEM_x_ONSTATE       | 0x3=ON                         |

### 8.10.2 PM_xxx_PWRSTST Key Fields

| Bits    | Field         | Description                          |
| ------- | ------------- | ------------------------------------ |
| [1:0]   | POWERSTATEST  | 0=OFF, 1=RETENTION, 2=INACTIVE, 3=ON |
| [5]     | INTRANSITION  | 0=No transition, 1=Ongoing           |
| [9:8]   | MEM_STATEST_x | 0=OFF, 1=RETENTION, 3=ON             |
| [11:10] | LOGICSTATEST  | 0=OFF, 1=RETENTION, 3=ON             |

### 8.10.3 PRM_DEVICE Registers (Base: 0x44E00F00)

| Offset | Register    | Key Fields                                                                                                                          |
| ------ | ----------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 0x00   | PRM_RSTCTRL | [1] RST_GLOBAL_COLD_SW, [0] RST_GLOBAL_WARM_SW                                                                                      |
| 0x04   | PRM_RSTTIME | [14:10] RSTTIME2, [9:0] RSTTIME1 (32 kHz cycles)                                                                                    |
| 0x08   | PRM_RSTST   | [9] ICEPICK_RST, [6] EXTERNAL_WARM_RST, [5] WDT1_RST, [4] GLOBAL_COLD_RST, [1] GLOBAL_WARM_SW_RST, [0] POWER_ON_RST (all R/W1toClr) |

### 8.10.4 PRM_PER Key Registers (Base: 0x44E00C00)

| Offset | Register         | Reset      | Description                             |
| ------ | ---------------- | ---------- | --------------------------------------- |
| 0x00   | RM_PER_RSTCTRL   | —          | [1] PRU_ICSS_LRST: 0=Released, 1=Assert |
| 0x08   | PM_PER_PWRSTST   | 0x1E60007  | Power/memory/logic status               |
| 0x0C   | PM_PER_PWRSTCTRL | 0xEE0000EB | Target power/memory states              |

### 8.10.5 PRM_WKUP Key Registers (Base: 0x44E00D00)

| Offset | Register          | Description                                         |
| ------ | ----------------- | --------------------------------------------------- |
| 0x00   | RM_WKUP_RSTCTRL   | [3] WKUP_M3_LRST: 0=Released, 1=Assert (held by A8) |
| 0x04   | PM_WKUP_PWRSTCTRL | [4] LowPowerStateChange, [3] LogicRETState          |

### 8.10.6 DEEPSLEEP_CTRL (Control Module: 0x44E10470)

| Bits   | Field    | Description                                       |
| ------ | -------- | ------------------------------------------------- |
| [15:3] | DSCOUNT  | Oscillator restart delay                          |
| [0]    | DSENABLE | 0=Disable, 1=Enable deep sleep oscillator control |

---

## 8.11 Common Pitfalls

1. Forgetting to enable clock domain before module access.
2. Accessing DPLL outputs before `ST_DPLL_CLK = 1`.
3. Accessing module registers before `IDLEST = Functional (0x0)`.
4. Incorrect power domain sequencing (hangs system).
5. Not saving context before entering low-power modes with memory OFF.
6. Setting `AUTO_DPLL_MODE` — **not supported on AM335x, must be 0x0**.
