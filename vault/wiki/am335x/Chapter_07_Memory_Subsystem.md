---
title: AM335x Chapter 7 Memory Subsystem
tags:
  - am335x
  - reference
date: 2026-04-18
---

# 7 Memory Subsystem

Three main components: **EMIF** (DDR SDRAM controller), **ELM** (BCH error location), **GPMC** (general-purpose external memory controller).

---

## 1. EMIF (External Memory Interface)

**Base address:** `0x4C000000`

### 1.1 Key Features

- Supports DDR2, DDR3, LPDDR1 (mDDR) SDRAM; 16-bit data bus
- Maximum DDR3: 400 MHz (800 MT/s); Maximum DDR2: 266 MHz (533 MT/s)
- Self-refresh, power-down, clock-stop (LPDDR1) power management
- Hardware write leveling and DQS gate training (DDR3)

### 1.2 Address Mapping Configuration Fields

| Field                     | Description                      |
| ------------------------- | -------------------------------- |
| `SDRAM_TYPE` [31:29]      | 0=DDR1, 1=LPDDR1, 2=DDR2, 3=DDR3 |
| `IBANK` [6:4]             | Number of internal banks         |
| `EBANK`                   | Number of chip selects (1 or 2)  |
| `PAGESIZE` [2:0]          | Column address bits (8/9/10/11)  |
| `RSIZE` / `ROWSIZE` [9:7] | Row address bits (9–16)          |
| `REG_IBANK_POS`           | Internal bank position (0–3)     |
| `REG_EBANK_POS`           | External bank position (0–1)     |

When `REG_IBANK_POS=0`, `REG_EBANK_POS=0`: `[Row | Chip Select | Bank | Column]`. Maximum interleaving: 16 banks (8 internal × 2 chip selects).

### 1.3 Power Management Modes

| Mode                          | Description                                                      |
| ----------------------------- | ---------------------------------------------------------------- |
| Self-Refresh                  | SDRAM maintains data; lowest power preserving data               |
| Power-Down                    | Active or precharge power-down; faster wake-up than self-refresh |
| Clock Stop (LPDDR1 only)      | Stops clocks after idle period; auto-restart on access           |
| Deep Power-Down (LPDDR1 only) | Data lost; requires re-initialization                            |

`PWR_MGMT_CTRL.LP_MODE [10:8]`: 1=Clock Stop, 2=Self-Refresh, 4=Power-Down.

### 1.4 SDRAM Initialization Sequences

**DDR2:** Drive CKE low → wait 16 refresh intervals → PRECHARGE all → load mode registers (EMR2, EMR3, EMR1, MR) → DLL reset → issue refreshes → OCD calibration → idle.

**DDR3:** Drive CKE low → wait 16 refresh intervals → load mode registers (MR0–MR2) → ZQ calibration (ZQCL) → auto refresh → idle.

**LPDDR1:** Drive CKE high, issue NOPs → wait 16 refresh intervals → PRECHARGE all → 2 auto refreshes → load mode registers (MR, EMR) → idle.

### 1.5 DDR3 Leveling Modes

- **Full leveling:** Complete calibration triggered by software (`RDWRLVLFULL_START = 1`).
- **Incremental leveling:** Periodic runtime updates.
- **Write leveling:** Aligns DQS with CLK at SDRAM.
- **Read DQS gate training:** Compensates board delays.
- **Read data eye training:** Optimizes read data sampling.

### 1.6 Key EMIF Registers

| Offset | Register       | Key Fields                                                                                                                               |
| ------ | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 0x08   | SDRAM_CONFIG   | SDRAM_TYPE[31:29], IBANK_POS[28:27], DDR_TERM[26:24], CWL[17:16], NARROW_MODE[15:14], CL[13:10], ROWSIZE[9:7], IBANK[6:4], PAGESIZE[2:0] |
| 0x10   | SDRAM_REF_CTRL | INITREF_DIS[31], SRT[29], ASR[28], PASR[26:24], REFRESH_RATE[15:0]                                                                       |
| 0x18   | SDRAM_TIM_1    | T_RP[28:25], T_RCD[24:21], T_WR[20:17], T_RAS[16:12], T_RC[11:6], T_RRD[5:3], T_WTR[2:0]                                                 |
| 0x20   | SDRAM_TIM_2    | T_XP[30:28], T_XSNR[24:16], T_XSRD[15:6], T_RTP[5:3], T_CKE[2:0]                                                                         |
| 0x28   | SDRAM_TIM_3    | T_PDLL_UL[31:28], ZQ_ZQCS[20:15], T_RFC[12:4], T_RAS_MAX[3:0]                                                                            |
| 0x38   | PWR_MGMT_CTRL  | PD_TIM[15:12], DPD_EN[11], LP_MODE[10:8], SR_TIM[7:4], CS_TIM[3:0]                                                                       |
| 0xDC   | RDWR_LVL_CTRL  | Leveling control                                                                                                                         |
| 0xE4   | DDR_PHY_CTRL_1 | PHY_ENABLE_DYNAMIC_PWRDN[20], PHY_RST_N[15], PHY_IDLE_LOCAL_ODT[13:12], PHY_RD_LOCAL_ODT[9:8], READ_LATENCY[4:0]                         |

### 1.7 DDR PHY Registers (Base: `0x44E12000`)

**Command Macros (CMD0/1/2):**

| Register                       | Key Field                                  | Default |
| ------------------------------ | ------------------------------------------ | ------- |
| CMD_REG_PHY_CTRL_SLAVE_RATIO_0 | CMD_SLAVE_RATIO[9:0] — 1/256th cycle units | 0x80    |
| CMD_REG_PHY_INVERT_CLKOUT_0    | INVERT_CLK_SEL[0]: 0=Normal, 1=Inverted    | —       |

**Data Macros (DATA0/1):**

| Register                           | Purpose                                                     | Default    |
| ---------------------------------- | ----------------------------------------------------------- | ---------- |
| DATA_REG_PHY_RD_DQS_SLAVE_RATIO_0  | Read DQS timing, CS0[9:0]                                   | 0x40       |
| DATA_REG_PHY_WR_DQS_SLAVE_RATIO_0  | Write DQS timing                                            | —          |
| DATA_REG_PHY_FIFO_WE_SLAVE_RATIO_0 | DQS gate timing                                             | —          |
| DATA_REG_PHY_WR_DATA_SLAVE_RATIO_0 | Write data relative to DQS                                  | 0x40       |
| DATA_REG_PHY_DQ_OFFSET_0           | DQ offset from DQS                                          | 0x40 (90°) |
| DATA_REG_PHY_USE_RANK0_DELAYS      | 0=Each rank own delays (DDR3), 1=All use rank 0 (DDR2/mDDR) | —          |

### 1.8 Basic DDR3 Setup Sequence

1. Configure PRCM to enable EMIF clock.
2. Configure DDR PHY control registers.
3. Set `SDRAM_TIM_1/2/3` timing parameters.
4. Set `SDRAM_REF_CTRL` refresh rate.
5. Write `SDRAM_CONFIG` (triggers initialization).
6. Poll `STATUS.PHY_DLL_READY`.
7. Perform leveling if required.

**DDR3-1600 timing example (400 MHz, 2.5 ns/cycle):**

| Field | Value |
| ----- | ----- |
| T_RP  | 10    |
| T_RCD | 10    |
| T_WR  | 11    |
| T_RAS | 27    |
| T_RC  | 38    |
| T_RRD | 5     |
| T_WTR | 5     |

**Typical PHY values for DDR3-800:** `CMD_SLAVE_RATIO=0x80`, `RD_DQS_SLAVE_RATIO=0x40`, `WR_DATA_SLAVE_RATIO=0x80`.

---

## 2. ELM (Error Location Module)

**Base address:** `0x48080000`

### 2.1 Key Features

- BCH error correction: 4-bit, 8-bit, 16-bit modes
- 8 simultaneous processing contexts (0–7)
- Continuous mode (interrupt per syndrome) and page mode (single interrupt for all contexts)

### 2.2 Processing Flow

1. Configure `ELM_LOCATION_CONFIG`: set `ECC_BCH_LEVEL[1:0]` (0=4-bit, 1=8-bit, 2=16-bit) and `ECC_SIZE[26:16]` (buffer size in nibbles).
2. Set `ELM_PAGE_CTRL`: all 0 = continuous mode; any bit set = page mode.
3. Write syndrome fragments 0–5 in any order, then fragment 6 last (sets `SYNDROME_VALID[16]`).
4. Wait for `LOC_VALID_i` (continuous) or `PAGE_VALID[8]` (page) interrupt in `ELM_IRQSTATUS`.
5. Read `ELM_LOCATION_STATUS_i`: `ECC_CORRECTABLE[8]`, `ECC_NB_ERRORS[4:0]`.
6. Read `ELM_ERROR_LOCATION_[0–15]_i[12:0]` for each error bit position.

### 2.3 Key ELM Registers

| Offset | Register            | Key Fields                                  |
| ------ | ------------------- | ------------------------------------------- |
| 0x10   | ELM_SYSCONFIG       | SOFTRESET[1], SIDLEMODE[4:3], AUTOGATING[0] |
| 0x18   | ELM_IRQSTATUS       | PAGE*VALID[8], LOC_VALID*[7:0]              |
| 0x1C   | ELM_IRQENABLE       | PAGE*MASK[8], LOCATION_MASK*[7:0]           |
| 0x20   | ELM_LOCATION_CONFIG | ECC_SIZE[26:16], ECC_BCH_LEVEL[1:0]         |
| 0x80   | ELM_PAGE_CTRL       | SECTOR\_[7:0] — 0=continuous, 1=page mode   |

**Syndrome fragment registers (context i, fragment j):**

- Context 0: `0x400 + j×4` (j=0–6); context stride = `0x40`.
- Fragment 6 bit [16] = `SYNDROME_VALID`. Writing this bit last triggers computation.

**Error location status registers:**

- `ELM_LOCATION_STATUS_i` @ `0x800 + i×0x100`: `ECC_CORRECTABLE[8]`, `ECC_NB_ERRORS[4:0]`.

**Error location output registers:**

- `ELM_ERROR_LOCATION_[0–15]_i` @ `0x880 + i×0x100 + k×4`: `ECC_ERROR_LOCATION[12:0]` — bit position in data buffer.
- Only read the first `ECC_NB_ERRORS` registers.

### 2.4 Common Pitfalls

**EMIF:** Not waiting for `PHY_DLL_READY`; incorrect timing calculations; forgetting PRCM clock enables; wrong `IBANK_POS`/`EBANK_POS`.

**ELM:** Reading error locations before checking `ECC_CORRECTABLE`; not writing fragment 6 last; reading more `ERROR_LOCATION` registers than `ECC_NB_ERRORS`; mixing page and continuous mode.

---

## 3. DDR3 / DDR2 AC Timing Reference

### DDR3 (ns)

| Param | -800E | -1066F | -1333H | -1600K |
| ----- | ----- | ------ | ------ | ------ |
| tCK   | 2.5   | 1.875  | 1.5    | 1.25   |
| tRCD  | 13.75 | 13.125 | 13.5   | 13.75  |
| tRP   | 13.75 | 13.125 | 13.5   | 13.75  |
| tRAS  | 37.5  | 36     | 36     | 35     |
| tRC   | 50    | 49.125 | 49.5   | 48.75  |
| tRRD  | 10    | 7.5    | 6      | 7.5    |
| tWR   | 15    | 15     | 15     | 15     |
| tWTR  | 7.5   | 7.5    | 7.5    | 7.5    |

### DDR2 (ns)

| Param | -533 | -667 | -800 |
| ----- | ---- | ---- | ---- |
| tCK   | 3.75 | 3.0  | 2.5  |
| tRCD  | 15   | 15   | 15   |
| tRP   | 15   | 15   | 15   |
| tRAS  | 40   | 40   | 45   |
| tRC   | 55   | 55   | 60   |
| tWR   | 15   | 15   | 15   |
| tWTR  | 7.5  | 7.5  | 10   |
