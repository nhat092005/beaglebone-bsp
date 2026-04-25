---
title: "AM335x Ch.3 — ARM MPU Subsystem"
tags:
  - am335x
  - reference
source: SPRUH73Q — Chapter 3 (Revised December 2019)
---

# AM335x — ARM MPU Subsystem

## 1. Overview

The MPU subsystem is a hard macro that integrates the ARM Cortex-A8 Processor with additional logic for protocol conversion, emulation, interrupt handling, and debug enhancements. It handles transactions between the ARM core, the L3 interconnect, and the interrupt controller (INTC).

**Signal interface:**

| Signal         | Direction   | Description                          |
| -------------- | ----------- | ------------------------------------ |
| `MPU_CLK`      | In (PRCM)   | Clock input                          |
| `MPU_RST`      | In (PRCM)   | MPU reset                            |
| `CORE_RST`     | In (PRCM)   | Core / INTC reset                    |
| `NEON_RST`     | In (PRCM)   | NEON reset                           |
| `EMU_RST`      | In (PRCM)   | Emulation reset                      |
| `sys_nirq`     | In (System) | System interrupts                    |
| `MPU_MSTANDBY` | Out         | Standby status to PRCM               |
| OCP Master 0/1 | Out         | To L3 Interconnect (128-bit, 64-bit) |

**Integrated submodules:**

| Submodule       | Description                                                               |
| --------------- | ------------------------------------------------------------------------- |
| ARM Cortex-A8   | ARMv7 core with NEON, VFPv3; communicates via AXI to AXI2OCP bridge       |
| AXI2OCP Bridge  | Converts AXI (ARM side) ↔ OCP L3; also interfaces INTC via OCP            |
| AINTC           | ARM Interrupt Controller; handles module interrupts                       |
| I2Async Bridge  | Asynchronous OCP-to-OCP between AXI2OCP (MPU side) and T2Async (external) |
| Clock Generator | Derives divided clocks for internal modules from `MPU_CLK`                |
| ICECrusher      | CoreSight Architecture compliant debug interface controller               |
| ROM             | 176 KB on-chip                                                            |
| RAM (OCM)       | 64 KB on-chip SRAM                                                        |

---

## 2. ARM Cortex-A8 Core

### 2.1 Architecture & Instruction Sets

| Feature              | Value                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------- |
| ISA                  | ARM Architecture version 7; backward compatible with previous ARM ISA versions              |
| Execution            | 2-issue, in-order pipeline                                                                  |
| Instruction sets     | Standard ARM; Thumb-2 (code density); Jazelle-X (Java accelerator); Media extensions (NEON) |
| Coprocessors         | NEON — Advanced SIMD; VFP — VFPv3, IEEE 754 compliant                                       |
| Branch prediction    | Branch Target Address Cache (BTAC): 512 entries; Hardware return stack                      |
| External interface   | AXI protocol, 128-bit data width                                                            |
| External coprocessor | Not supported                                                                               |

### 2.2 Cache Hierarchy

| Level      | Size   | Associativity | Line length | Interface     | Error protection                                          |
| ---------- | ------ | ------------- | ----------- | ------------- | --------------------------------------------------------- |
| L1 I-cache | 32 KB  | 4-way set     | 16-word     | 128-bit       | SED (Single Error Detection)                              |
| L1 D-cache | 32 KB  | 4-way set     | 16-word     | 128-bit       | SED (Single Error Detection)                              |
| L2 Cache   | 256 KB | 8-way set     | 16-word     | 128-bit to L1 | ECC / Parity; hardware or software clearing of valid bits |

> **⚠ CAUTION — L1 Cache Retention:** The MPU L1 cache memory does **not** support retention mode. Its array switch is controlled together with MPU logic. L1 retention control signals exist at the PRCM boundary but are **not used**. ARM L2 **can** be put into retention independently.

### 2.3 Memory Management Unit

| Parameter     | Value                            |
| ------------- | -------------------------------- |
| MMU type      | Enhanced MMU with TLB            |
| ITLB          | Fully associative, 32 entries    |
| DTLB          | Fully associative, 32 entries    |
| Page sizes    | 4 KB, 64 KB, 1 MB, 16 MB         |
| Address range | Extended physical address ranges |

### 2.4 On-chip Memory

| Type      | Size   | Notes       |
| --------- | ------ | ----------- |
| ROM       | 176 KB | Flat memory |
| RAM (OCM) | 64 KB  | Flat SRAM   |

### 2.5 AXI Bus Interface

- Performs L2 cache fills and handles non-cacheable accesses for instructions and data
- 128-bit and 64-bit wide input/output data buses
- Multiple outstanding requests support
- Wide range of bus clock to core clock ratios; synchronous bus clock with core clock
- Memory region attributes determine: Ordering, Posting, Pipeline synchronization

### 2.6 Debug Support

| Component  | Description                                                             |
| ---------- | ----------------------------------------------------------------------- |
| ETM        | Embedded Trace Macrocell — non-invasive debugging; embedded in ARM core |
| ETB        | 32 KB Embedded Trace Buffer at chip level (DebugSS)                     |
| DAP        | Debug Access Port — JTAG-based debug                                    |
| TPIU       | Trace Port Interface Unit — trace support                               |
| ICECrusher | CoreSight Architecture compliant debug interface controller             |
| APB slave  | 32-bit Advanced Peripheral Bus slave interface                          |
| ATB        | Advanced Trace Bus for trace data                                       |

All CoreSight Architecture compatible. ARMv7 debug with watchpoint and breakpoint registers.

### 2.7 Complete Feature Summary

| Feature                | Description                                                         |
| ---------------------- | ------------------------------------------------------------------- |
| ARM ISA Version        | ARMv7 with Thumb-2, Jazelle-X, Media extensions                     |
| Backward Compatibility | Previous ARM ISA versions supported                                 |
| L1 I-cache             | 32KB, 4-way, 16-word line, 128-bit interface                        |
| L1 D-cache             | 32KB, 4-way, 16-word line, 128-bit interface                        |
| L2 Cache               | 256KB, 8-way, 16-word line, 128-bit to L1, ECC/Parity               |
| L2 Valid Bits          | Software loop or hardware clearing                                  |
| TLB                    | Fully associative, separate ITLB (32 entries) and DTLB (32 entries) |
| CoreSight ETM          | Embedded with ARM core, 32KB ETB at chip level                      |
| Branch Target Cache    | 512 entries                                                         |
| MMU                    | Enhanced with 4KB, 64KB, 1MB, 16MB mapping sizes                    |
| NEON                   | Enhanced throughput for media workloads, VFP-Lite support           |
| ROM                    | 176KB flat memory                                                   |
| RAM                    | 64KB flat memory                                                    |
| Internal Bus           | 128-bit AXI from Cortex-A8 via AXI2OCP bridge                       |
| OCP Ports              | 128-bit and 64-bit asynchronous                                     |
| Low Interrupt Latency  | Closely coupled INTC with 128 interrupt lines                       |
| Vectored Interrupt     | Controller port present                                             |
| Debug                  | JTAG-based via DAP                                                  |
| Trace                  | Supported via TPIU                                                  |
| External Coprocessor   | Not supported                                                       |

---

## 3. AXI2OCP Bridge

- OCP 2.2 compliant
- Single Request Multiple Data (SRMD) Protocol
- Two ports support
- Three OCP port widths: 128-bit, 64-bit, 32-bit

---

## 4. Interrupt Controller (AINTC)

The Host ARM Interrupt Controller (AINTC) prioritizes service requests from system peripherals and generates nIRQ or nFIQ to the ARM processor.

- Connects to ARM via AXI port through AXI2OCP bridge; runs at half the processor speed
- Up to **128 level-sensitive** interrupt inputs
- Individual priority for each interrupt input
- Each interrupt steerable to nFIQ or nIRQ
- Independent priority sorting for nFIQ and nIRQ
- Interrupt type (nIRQ or nFIQ), priority level, enable/disable: all programmable per interrupt

> **Note:** In debug mode, ICECrusher can prevent the MPU subsystem from entering IDLE mode.

For detailed interrupt handling, see Chapter 6 (Interrupts).

---

## 5. Clock Distribution

```
MPU_DPLL → MPU_CLK → Clock Generator
                           │
                           ├── ARM_FCLK        = MPU_CLK          ARM core, NEON, L2 cache, ETM, internal RAMs
                           ├── AXI2OCP_FCLK    = ARM_FCLK / 2    OCP interface bridge
                           ├── INTC_FCLK       = ARM_FCLK / 2    Interrupt controller
                           ├── ICECRUSHER_FCLK = ARM_FCLK / 2    Debug APB interface
                           ├── I2ASYNC_FCLK    = ARM_FCLK / 2    Async bridge (MPU side)
                           └── EMU_CLOCKS      = max ARM_FCLK / 3 Emulation (async to ARM core)
```

`T2ASYNC` (device side) is clocked by **Core Clock** sourced from PRCM.

**Clock divider register:** `CM_DIV_M2_DPLL_MPU.DPLL_CLKOUT_DIV` — configures the output clock divider; frequencies relative to ARM core. See Chapter 8 (PRCM) for details.

---

## 6. Reset Distribution

All resets provided by PRCM, controlled by the clock generator module.

| Signal         | Source | Target                                  |
| -------------- | ------ | --------------------------------------- |
| `MPU_RSTPWRON` | PRCM   | MPU power-on reset (Clock Generator)    |
| `MPU_RST`      | PRCM   | MPU subsystem modules: AXI2OCP, I2Async |
| `CORE_RST`     | PRCM   | INTC, ARM core                          |
| `NEON_RST`     | PRCM   | NEON coprocessor                        |
| `EMU_RSTPWRON` | PRCM   | Emulation power-on reset                |
| `EMU_RST`      | PRCM   | Emulation modules: ICECrusher, ETM      |

---

## 7. Power Management

### 7.1 Power Domains (four domains, controlled by PRCM)

| Domain | Contents                                                                                        |
| ------ | ----------------------------------------------------------------------------------------------- |
| MPU    | ARM Core, AXI2OCP, I2Async Bridge, ARM L1 and L2 periphery logic, ICE-Crusher, ETM, APB modules |
| NEON   | ARM NEON accelerator                                                                            |
| CORE   | MPU Interrupt Controller (INTC)                                                                 |
| EMU    | ETB (Embedded Trace Buffer), DAP (Debug Access Port)                                            |

> Emulation and core domains are not fully embedded in the MPU subsystem. L1 and L2 array memories have separate control signals controlled by PRCM. For physical power domains and voltage domains, see Chapter 8 (PRCM).

### 7.2 Power States (per domain)

| State    | Logic Power | Memory Power | Clocks                  |
| -------- | ----------- | ------------ | ----------------------- |
| Active   | On          | On or Off    | On (at least one clock) |
| Inactive | On          | On or Off    | Off                     |
| Off      | Off         | Off          | Off (all clocks)        |

### 7.3 Supported Operation Modes

| Mode | MPU & ARM Logic | ARM L2 RAM | NEON    | INTC   | Device Core         |
| ---- | --------------- | ---------- | ------- | ------ | ------------------- |
| 1    | Active          | Active     | Active  | Active | Disabled or enabled |
| 2    | Active          | Active     | OFF     | Active | Disabled or enabled |
| 3    | Active          | RET        | Active  | Active | Disabled or enabled |
| 4    | Active          | RET        | OFF     | Active | Disabled or enabled |
| 5    | Active          | OFF        | Active  | Active | Disabled or enabled |
| 6    | Active          | OFF        | OFF     | Active | Disabled or enabled |
| 7    | OFF             | RET        | OFF     | OFF    | Disabled or enabled |
| 8    | Standby         | Active     | Standby | Active | Disabled or enabled |
| 9    | Standby         | Active     | OFF     | Active | Disabled or enabled |
| 10   | Standby         | RET        | Standby | Active | Disabled or enabled |
| 11   | Standby         | RET        | OFF     | Active | Disabled or enabled |
| 12   | Standby         | OFF        | Standby | Active | Disabled or enabled |
| 13   | Standby         | OFF        | OFF     | Active | Disabled or enabled |
| 14   | OFF             | OFF        | OFF     | OFF    | Disabled or enabled |

**Key:** RET = Retention; OFF = Powered off; Active = Fully operational.

**Power management dependencies:**

- MPU must be on when core power is on
- Device power management prevents INTC OFF state when MPU domain is on
- NEON has independent power-off mode when not in use
- PRCM manages all transitions by controlling: domain clocks, domain resets, domain logic power switches, memory power switches

**Check MPU standby status:** `CM_MPU_MPU_CLKCTRL.STBYST`

---

## 8. Power Mode Transition Sequences

### Basic Power-On Reset

1. Reset INTC (`CORE_RST`) and MPU subsystem modules (`MPU_RST`)
2. Clocks must be active during MPU reset and CORE reset

Applies to: initial power-up; wakeup from device off mode.

### MPU Into Standby Mode

1. ARM core initiates standby via software (CP15 — WFI instruction)
2. MPU modules requested internally to enter idle (after ARM standby detected)
3. MPU standby output asserted to PRCM (all outputs guaranteed at reset values)
4. PRCM requests INTC to enter idle mode
5. INTC acknowledges to PRCM

> `INTC SWAKEUP` output is a hardware signal to PRCM for IDLE request/acknowledge handshake status.

### MPU Out of Standby Mode

1. PRCM starts clocks through DPLL programming
2. Detect active clocking via DPLL status output
3. Initiate interrupt through INTC to wake up ARM core from STANDBYWFI mode

Applies to: exit from standby; wakeup from device off mode.

### MPU Power On From Powered-Off State

1. **Power-Up Order** (minimize current peaking): MPU Power On → NEON Power On → Core Power On (INTC). Follow ordered sequence per power switch daisy chain.
2. **Reset Sequence:** Core domain must be on and reset **before** MPU reset. Then follow Basic Power-On Reset sequence.

> **Important:** Core domain must be on and reset before the MPU can be reset.

---

## 9. Register Reference

### Clock Management

| Register             | Field             | Purpose                                   |
| -------------------- | ----------------- | ----------------------------------------- |
| `CM_DIV_M2_DPLL_MPU` | `DPLL_CLKOUT_DIV` | Configure clock divider for MPU subsystem |
| `CM_MPU_MPU_CLKCTRL` | `STBYST`          | Check MPU standby status                  |

For complete register map and detailed descriptions, see Chapter 8 (PRCM).

### CP15 Registers — Secure Monitor Access

**Procedure:** Write service ID to R12, load value to write in R0, perform barrier operations, execute `SMC #1` (or `SMI #1`). **Must be executed in ARM privileged mode.**

| Service ID (R12) | Function                                                 |
| ---------------- | -------------------------------------------------------- |
| `0x100`          | Write value in R0 to Auxiliary Control Register          |
| `0x101`          | Write value in R0 to Non-Secure Access Control Register  |
| `0x102`          | Write value in R0 to L2 Cache Auxiliary Control Register |

**Example — Enabling ECC on L2 Cache** (set bits 21 and 28):

```assembly
_enableL2ECC:
    STMFD sp!, {r0 - r4}          ; Save context of R0-R4
    MRC p15, #1, r0, c9, c0, #2   ; Read L2 Cache Aux Control Reg into R0
    MOV r1, #0                     ; Clear R1
    MOVT r1, #0x1020               ; Enable mask for ECC (bits 21 and 28)
    ORR r0, r0, r1                 ; OR with original register value
    MOV r12, #0x0102               ; Setup service ID in R12
    MCR p15,#0x0,r1,c7,c5,#6      ; Invalidate entire branch predictor array
    DSB                            ; Data synchronization barrier
    ISB                            ; Instruction synchronization barrier
    DMB                            ; Data memory barrier
    SMC #1                         ; Secure monitor call
    LDMFD sp!, {r0 - r4}          ; Restore R0-R4
    MOV pc, lr                     ; Return
```

---

## 10. L3 Interconnect Interface

- Connection via I2Async → T2Async bridge pair
- OCP Master 0: 128-bit
- OCP Master 1: 64-bit
- Protocol: OCP 2.2, SRMD (Single Request Multiple Data)
- Asynchronous operation via I2Async / T2Async bridges

---

## 11. Cross-References

| Topic                             | Reference                                |
| --------------------------------- | ---------------------------------------- |
| Clock, reset, power domain detail | Chapter 8 — PRCM                         |
| Interrupt assignment map          | Chapter 6 — Interrupts                   |
| ARM core programming model        | ARM Cortex-A8 Technical Reference Manual |
| AXI bus protocol                  | AMBA AXI Protocol Specification          |
| OCP protocol                      | OCP-IP Protocol Specification 2.2        |
| Debug / trace                     | ARM CoreSight Architecture Specification |
