---
title: AM335x Chapter 6 Interrupts
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 6 Interrupts

## 6.1 Functional Description

The interrupt controller (INTC) processes incoming interrupts through masking and priority sorting to produce IRQ/FIQ signals for the processor.

> **NOTE:** FIQ is not available on general-purpose (GP) devices.

### 6.1.1 Input Selection

INTC supports only **level-sensitive** incoming interrupt detection. A peripheral asserting an interrupt maintains it until software handles it and instructs the peripheral to deassert.

**Software interrupts:** Set via `MPU_INTC.INTC_ISR_SETn`; cleared via `MPU_INTC.INTC_ISR_CLEARn`.

### 6.1.2 Masking

- **Individual masking:** Per-line enable/disable via `MPU_INTC.INTC_MIRn`.
- **IRQ/FIQ steering:** Determined by `MPU_INTC.INTC_ILRm[0] FIQNIRQ` bit.
- **Pre-mask status:** Readable from `MPU_INTC.INTC_ITRn`.
- **Post-mask status:** Readable from `MPU_INTC.INTC_PENDING_IRQn` / `INTC_PENDING_FIQn`.

**Priority masking:** `MPU_INTC.INTC_THRESHOLD[7:0] PRIORITYTHRESHOLD` — all interrupts of lower or equal priority than threshold are masked. Priority 0 can never be masked by threshold. Values 0x0 (highest) to 0x7F (lowest); 0xFF disables threshold (reset default).

### 6.1.3 Priority Sorting

Priority assigned via `MPU_INTC.INTC_ILRm`. Same-priority simultaneous interrupts: highest-numbered interrupt serviced first. Active interrupt number placed in `INTC_SIR_IRQ[6:0] ACTIVEIRQ` or `INTC_SIR_FIQ[6:0] ACTIVEFIQ`. Preserved until `INTC_CONTROL NEWIRQAGR` or `NEWFIQAGR` bit is written.

Priority sorting takes 10 functional clock cycles.

### 6.1.4 Interrupt Latency

- IRQ/FIQ generation: **4 functional clock cycles** (±1) when `INTC_IDLE[1] TURBO = 0`.
- When `TURBO = 1`: 6 cycles, lower power.
- Disabling functional clock auto-idle (`INTC_IDLE[0] FUNCIDLE = 1`) reduces latency by 1 cycle.

### 6.1.5 Register Protection

If `MPU_INTC.INTC_PROTECTION[0] PROTECTION = 1`, all register access is restricted to privileged mode. The PROTECTION register itself is always restricted to privileged mode.

### 6.1.6 Module Power Saving (Auto-idle)

| Clock              | Control bit                      | Default                                    |
| ------------------ | -------------------------------- | ------------------------------------------ |
| Interface clock    | `INTC_SYSCONFIG[0] AUTOIDLE = 1` | Disabled                                   |
| Functional clock   | `INTC_IDLE[0] FUNCIDLE = 0`      | Enabled (auto-gate)                        |
| Synchronizer clock | `INTC_IDLE[1] TURBO = 1`         | Disabled; when enabled, latency 4→6 cycles |

---

## 6.2 Basic Programming Model

### 6.2.1 Initialization Sequence

1. Program `INTC_SYSCONFIG` — optionally set `AUTOIDLE`.
2. Program `INTC_IDLE` — optionally set `FUNCIDLE` or `TURBO`.
3. Program `INTC_ILRm` for each line — set priority and `FIQNIRQ` (default: IRQ, priority 0x0).
4. Program `INTC_MIRn` — enable desired interrupt lines (all masked by default); use `INTC_MIR_SETn` / `INTC_MIR_CLEARn` for atomic mask manipulation.

### 6.2.2 INTC Processing Sequence (IRQ)

1. Unmasked `M_IRQ_n` received; INTC asserts `MPU_INTC_IRQ`.
2. ARM saves context, sets `CPSR[4:0] = 0b10010` (IRQ mode), jumps to `0x00000018` (or `0xFFFF0018` high vectors).
3. ISR reads `INTC_SIR_IRQ[6:0] ACTIVEIRQ` to identify source.
4. Subroutine handler services peripheral and deasserts interrupt.
5. ISR writes `INTC_CONTROL NEWIRQAGR = 1`; issues Data Synchronization Barrier (`MCR P15, #0, R0, C7, C10, #4`).
6. ISR restores context; returns with `SUBS PC, LR, #4`.

**Key addresses:**

- `INTC_SIR_IRQ`: `0x48200040`
- `INTC_SIR_FIQ`: `0x48200044`
- `INTC_CONTROL`: `0x48200048`
- `ACTIVEIRQ_MASK`: `0x7F`
- `NEWIRQAGR_MASK`: `0x01`, `NEWFIQAGR_MASK`: `0x02`

### 6.2.3 Preemptive (Nested) IRQ Sequence

At the beginning of ISR:

1. Save ARM critical context and `INTC_THRESHOLD`.
2. Read current priority from `INTC_IRQ_PRIORITY IRQPRIORITY`; write to `INTC_THRESHOLD`.
3. Read `INTC_SIR_IRQ ACTIVEIRQ`.
4. Write `INTC_CONTROL NEWIRQAGR` (and `NEWFIQAGR` if handling FIQ) = 1.
5. Issue Data Synchronization Barrier.
6. Enable IRQ at ARM (`BIC CPSR, #0x80`).
7. Jump to handler.

At the end of ISR:

1. Disable IRQ at ARM (`ORR CPSR, #0x80`).
2. Restore `INTC_THRESHOLD` from saved value.
3. Restore ARM critical context; return with `SUBS PC, LR, #4`.

> **Note (FIQ with threshold):** Both `NEWFIQAGR` and `NEWIRQAGR` must be written simultaneously. All FIQ priorities must be set higher than all IRQ priorities when threshold mechanism is in use.

### 6.2.4 Spurious Interrupt Handling

The sorting result (10-cycle window after interrupt assertion) is invalid if the triggering interrupt deasserts or mask changes during sorting. Invalid condition flagged by `SPURIOUSIRQFLAG` / `SPURIOUSFIQFLAG` bits in `INTC_SIR_IRQ[31:7]` and `INTC_IRQ_PRIORITY[31:7]` (0 = valid, 1 = invalid). Do not modify `INTC_MIRn`, `INTC_ILRm`, or `INTC_MIR_SETn` while corresponding interrupt is asserted.

---

## 6.3 ARM Cortex-A8 Interrupts (Table 6-1)

128 interrupt lines supported.

> (2) `pr1_host_intr[0:7]` corresponds to Host-2 to Host-9 of the PRU-ICSS interrupt controller.

| Int # | Acronym            | Source                    | Signal Name               |
| ----- | ------------------ | ------------------------- | ------------------------- |
| 0     | EMUINT             | MPU Subsystem Internal    | EMUICINTR                 |
| 1     | COMMTX             | MPU Subsystem Internal    | CortexA8 COMMTX           |
| 2     | COMMRX             | MPU Subsystem Internal    | CortexA8 COMMRX           |
| 3     | BENCH              | MPU Subsystem Internal    | NPMUIRQ                   |
| 4     | ELM_IRQ            | ELM                       | Sinterrupt                |
| 7     | NMI                | External Pin (active low) | nmi_int                   |
| 9     | L3DEBUG            | L3                        | l3_FlagMux_top_FlagOut1   |
| 10    | L3APPINT           | L3                        | l3_FlagMux_top_FlagOut0   |
| 11    | PRCMINT            | PRCM                      | irq_mpu                   |
| 12    | EDMACOMPINT        | TPCC (EDMA)               | tpcc_int_pend_po0         |
| 13    | EDMAMPERR          | TPCC (EDMA)               | tpcc_mpint_pend_po        |
| 14    | EDMAERRINT         | TPCC (EDMA)               | tpcc_errint_pend_po       |
| 16    | ADC_TSC_GENINT     | ADC_TSC                   | gen_intr_pend             |
| 17    | USBSSINT           | USBSS                     | usbss_intr_pend           |
| 18    | USBINT0            | USBSS                     | usb0_intr_pend            |
| 19    | USBINT1            | USBSS                     | usb1_intr_pend            |
| 20–27 | PRU_ICSS_EVTOUT0–7 | PRU-ICSS pr1_host[0–7]    | pr1_host_intrN_intr_pend  |
| 28    | MMCSD1INT          | MMCSD1                    | SINTERRUPTN               |
| 29    | MMCSD2INT          | MMCSD2                    | SINTERRUPTN               |
| 30    | I2C2INT            | I2C2                      | POINTRPEND                |
| 31    | eCAP0INT           | eCAP0                     | ecap_intr_intr_pend       |
| 32    | GPIOINT2A          | GPIO 2                    | POINTRPEND1               |
| 33    | GPIOINT2B          | GPIO 2                    | POINTRPEND2               |
| 36    | LCDCINT            | LCDC                      | lcd_irq                   |
| 37    | GFXINT             | SGX530                    | THALIAIRQ                 |
| 39    | ePWM2INT           | eHRPWM2                   | epwm_intr_intr_pend       |
| 40    | 3PGSWRXTHR0        | CPSW                      | c0_rx_thresh_pend         |
| 41    | 3PGSWRXINT0        | CPSW                      | c0_rx_pend                |
| 42    | 3PGSWTXINT0        | CPSW                      | c0_tx_pend                |
| 43    | 3PGSWMISC0         | CPSW                      | c0_misc_pend              |
| 44    | UART3INT           | UART3                     | niq                       |
| 45    | UART4INT           | UART4                     | niq                       |
| 46    | UART5INT           | UART5                     | niq                       |
| 47    | eCAP1INT           | eCAP1                     | ecap_intr_intr_pend       |
| 52    | DCAN0_INT0         | DCAN0                     | dcan_intr0_intr_pend      |
| 53    | DCAN0_INT1         | DCAN0                     | dcan_intr1_intr_pend      |
| 54    | DCAN0_PARITY       | DCAN0                     | dcan_uerr_intr_pend       |
| 55    | DCAN1_INT0         | DCAN1                     | dcan_intr0_intr_pend      |
| 56    | DCAN1_INT1         | DCAN1                     | dcan_intr1_intr_pend      |
| 57    | DCAN1_PARITY       | DCAN1                     | dcan_uerr_intr_pend       |
| 58    | ePWM0_TZINT        | eHRPWM0 TZ                | epwm_tz_intr_pend         |
| 59    | ePWM1_TZINT        | eHRPWM1 TZ                | epwm_tz_intr_pend         |
| 60    | ePWM2_TZINT        | eHRPWM2 TZ                | epwm_tz_intr_pend         |
| 61    | eCAP2INT           | eCAP2                     | ecap_intr_intr_pend       |
| 62    | GPIOINT3A          | GPIO 3                    | POINTRPEND1               |
| 63    | GPIOINT3B          | GPIO 3                    | POINTRPEND2               |
| 64    | MMCSD0INT          | MMCSD0                    | SINTERRUPTN               |
| 65    | McSPI0INT          | McSPI0                    | SINTERRUPTN               |
| 66    | TINT0              | Timer0                    | POINTR_PEND               |
| 67    | TINT1_1MS          | DMTIMER_1ms               | POINTR_PEND               |
| 68    | TINT2              | DMTIMER2                  | POINTR_PEND               |
| 69    | TINT3              | DMTIMER3                  | POINTR_PEND               |
| 70    | I2C0INT            | I2C0                      | POINTRPEND                |
| 71    | I2C1INT            | I2C1                      | POINTRPEND                |
| 72    | UART0INT           | UART0                     | niq                       |
| 73    | UART1INT           | UART1                     | niq                       |
| 74    | UART2INT           | UART2                     | niq                       |
| 75    | RTCINT             | RTC                       | timer_intr_pend           |
| 76    | RTCALARMINT        | RTC                       | alarm_intr_pend           |
| 77    | MBINT0             | Mailbox0 (mail_u0_irq)    | initiator_sinterrupt_q_n0 |
| 78    | M3_TXEV            | Wake M3 Subsystem         | TXEV                      |
| 79    | eQEP0INT           | eQEP0                     | eqep_intr_intr_pend       |
| 80    | MCATXINT0          | McASP0                    | mcasp_x_intr_pend         |
| 81    | MCARXINT0          | McASP0                    | mcasp_r_intr_pend         |
| 82    | MCATXINT1          | McASP1                    | mcasp_x_intr_pend         |
| 83    | MCARXINT1          | McASP1                    | mcasp_r_intr_pend         |
| 86    | ePWM0INT           | eHRPWM0                   | epwm_intr_intr_pend       |
| 87    | ePWM1INT           | eHRPWM1                   | epwm_intr_intr_pend       |
| 88    | eQEP1INT           | eQEP1                     | eqep_intr_intr_pend       |
| 89    | eQEP2INT           | eQEP2                     | eqep_intr_intr_pend       |
| 90    | DMA_INTR_PIN2      | xdma_event_intr2          | pi_x_dma_event_intr2      |
| 91    | WDT1INT            | WDTIMER1                  | PO_INT_PEND               |
| 92    | TINT4              | DMTIMER4                  | POINTR_PEND               |
| 93    | TINT5              | DMTIMER5                  | POINTR_PEND               |
| 94    | TINT6              | DMTIMER6                  | POINTR_PEND               |
| 95    | TINT7              | DMTIMER7                  | POINTR_PEND               |
| 96    | GPIOINT0A          | GPIO 0                    | POINTRPEND1               |
| 97    | GPIOINT0B          | GPIO 0                    | POINTRPEND2               |
| 98    | GPIOINT1A          | GPIO 1                    | POINTRPEND1               |
| 99    | GPIOINT1B          | GPIO 1                    | POINTRPEND2               |
| 100   | GPMCINT            | GPMC                      | gpmc_sinterrupt           |
| 101   | DDRERR0            | EMIF                      | sys_err_intr_pend         |
| 108   | SHA_IRQ_S          | SHA2 secure               | SHA_SINTREQUEST_S         |
| 109   | SHA_IRQ_P          | SHA2 public               | SHA_SINTREQUEST_P         |
| 110   | FPKA_SINTREQUEST_S | PKA                       | PKA_SINTREQUEST_S         |
| 111   | RNG_IRQ            | RNG                       | TRNG_intr_pend            |
| 112   | TCERRINT0          | TPTC0                     | tptc_erint_pend_po        |
| 113   | TCERRINT1          | TPTC1                     | tptc_erint_pend_po        |
| 114   | TCERRINT2          | TPTC2                     | tptc_erint_pend_po        |
| 115   | ADC_TSC_PENINT     | ADC_TSC                   | pen_intr_pend             |
| 120   | SMRFLX_MPU         | Smart Reflex 0            | intrpend                  |
| 121   | SMRFLX_Core        | Smart Reflex 1            | intrpend                  |
| 123   | DMA_INTR_PIN0      | xdma_event_intr0          | pi_x_dma_event_intr0      |
| 124   | DMA_INTR_PIN1      | xdma_event_intr1          | pi_x_dma_event_intr1      |
| 125   | McSPI1INT          | McSPI1                    | SINTERRUPTN               |

---

## 6.4 Crypto DMA Events (Table 6-2)

| Event# | Event Name                       | Source                                     |
| ------ | -------------------------------- | ------------------------------------------ |
| 1      | AES0_s_dma_ctx_in_req            | AES0: New context on Secured HIB           |
| 2      | AES0_s_dma_data_in_req           | AES0: Input data on Secured HIB            |
| 3      | AES0_s_dma_data_out_req          | AES0: Output data read on Secured HIB      |
| 4      | AES0_p_dma_ctx_in_req            | AES0: New context on Public HIB            |
| 5      | AES0_p_dma_data_in_req           | AES0: Input data on Public HIB             |
| 6      | AES0_p_dma_data_out_req          | AES0: Output data read on Public HIB       |
| 7–12   | AES1_s/p_dma_ctx/data_in/out_req | AES1 Secured/Public HIB (same pattern)     |
| 15     | DES_s_dma_ctx_in_req             | DES: New context on secure HIB             |
| 16     | DES_s_dma_data_in_req            | DES: Input data on secure HIB              |
| 17     | DES_s_dma_data_out_req           | DES: Output data read on secure HIB        |
| 18     | DES_p_dma_ctx_in_req             | DES: New context on public HIB             |
| 19     | DES_p_dma_data_in_req            | DES: Input data on public HIB              |
| 20     | DES_p_dma_data_out_req           | DES: Output data read on public HIB        |
| 21     | SHA2_dma_ctxin_s                 | SHA2MD5: Context on secure HIB             |
| 22     | SHA2_dma_din_s                   | SHA2MD5: Input data on secure HIB          |
| 23     | SHA2_dma_ctxout_s                | SHA2MD5: Output data/context on secure HIB |
| 24     | SHA2_dma_ctxin_p                 | SHA2MD5: Context on public HIB             |
| 25     | SHA2_dma_din_p                   | SHA2MD5: Input data on public HIB          |
| 26     | SHA2_dma_ctxout_p                | SHA2MD5: Output data/context on public HIB |
| 27     | AES0_s_dma_context_out_req       | AES0: TAG/result IV read on Secured HIB    |
| 28     | AES0_p_dma_context_out_req       | AES0: TAG/result IV read on Public HIB     |
| 29     | AES1_s_dma_context_out_req       | AES1: TAG/result IV read on Secured HIB    |
| 30     | AES1_p_dma_context_out_req       | AES1: TAG/result IV read on Public HIB     |

---

## 6.5 PWM / Timer Event Capture (Table 6-3, selected entries)

| Event # | IP                      | Interrupt/Pin                                     |
| ------- | ----------------------- | ------------------------------------------------- |
| 0       | Timer 5/6/7, eCAP 0/1/2 | Respective IO pins (MUX inputs)                   |
| 1–6     | UART0–UART5             | UARTxINT                                          |
| 7–10    | 3PGSW                   | 3PGSWRXTHR0, 3PGSWRXINT0, 3PGSWTXINT0, 3PGSWMISC0 |
| 11–14   | McASP0/1                | MCATXINT0/1, MCARXINT0/1                          |
| 17–24   | GPIO 0–3                | GIOINTxA/B                                        |
| 25–30   | DCAN0/1                 | DCAN0/1_INT0/1/PARITY                             |

---

## 6.6 INTC Register Map

**Base address:** `0x48200000`

| Offset      | Register                      | Reset      | Description                                            |
| ----------- | ----------------------------- | ---------- | ------------------------------------------------------ |
| 0x00        | INTC_REVISION                 | 0x50       | IP revision [7:4] major, [3:0] minor                   |
| 0x10        | INTC_SYSCONFIG                | 0x0        | [1] SoftReset, [0] Autoidle                            |
| 0x14        | INTC_SYSSTATUS                | 0x0        | [0] ResetDone                                          |
| 0x40        | INTC_SIR_IRQ                  | 0xFFFFFF80 | [31:7] SpuriousIRQ, [6:0] ActiveIRQ                    |
| 0x44        | INTC_SIR_FIQ                  | 0xFFFFFF80 | [31:7] SpuriousFIQ, [6:0] ActiveFIQ                    |
| 0x48        | INTC_CONTROL                  | 0x0        | [1] NewFIQAgr (W), [0] NewIRQAgr (W)                   |
| 0x4C        | INTC_PROTECTION               | 0x0        | [0] Protection (privileged access only)                |
| 0x50        | INTC_IDLE                     | 0x0        | [1] Turbo, [0] FuncIdle                                |
| 0x60        | INTC_IRQ_PRIORITY             | 0xFFFFFFC0 | [31:7] SpuriousIRQflag, [6:0] IRQPriority              |
| 0x64        | INTC_FIQ_PRIORITY             | 0xFFFFFFC0 | [31:7] SpuriousFIQflag, [6:0] FIQPriority              |
| 0x68        | INTC_THRESHOLD                | 0xFF       | [7:0] PriorityThreshold (0xFF = disabled)              |
| 0x80        | INTC_ITR0                     | 0x0        | [31:0] Raw interrupt status before masking             |
| 0x84        | INTC_MIR0                     | 0xFFFFFFFF | [31:0] Interrupt mask (1 = masked)                     |
| 0x88        | INTC_MIR_CLEAR0               | —          | Write 1 clears mask bit                                |
| 0x8C        | INTC_MIR_SET0                 | —          | Write 1 sets mask bit                                  |
| 0x90        | INTC_ISR_SET0                 | 0x0        | Read: active SW interrupts; Write 1: sets SW interrupt |
| 0x94        | INTC_ISR_CLEAR0               | —          | Write 1 clears SW interrupt                            |
| 0x98        | INTC_PENDING_IRQ0             | 0x0        | IRQ status after masking                               |
| 0x9C        | INTC_PENDING_FIQ0             | 0x0        | FIQ status after masking                               |
| 0xA0–0xBC   | INTC_ITR1 … INTC_PENDING_FIQ1 | —          | Bank 1 (same pattern, interrupts 32–63)                |
| 0xC0–0xDC   | INTC_ITR2 … INTC_PENDING_FIQ2 | —          | Bank 2 (interrupts 64–95)                              |
| 0xE0–0xFC   | INTC_ITR3 … INTC_PENDING_FIQ3 | —          | Bank 3 (interrupts 96–127)                             |
| 0x100–0x2FC | INTC_ILR_0 … INTC_ILR_127     | 0x0        | [7:2] Priority, [0] FIQnIRQ                            |

**INTC_ILR_m fields:**

- `[7:2] Priority` — interrupt priority level (0x0 = highest)
- `[0] FIQnIRQ` — 0 = IRQ, 1 = FIQ (FIQ reserved on GP devices)
