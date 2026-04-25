---
title: AM335x Chapter 13 — LCD Controller (LCDC)
tags:
  - am335x
  - lcdc
  - display
  - reference
source: "AM335x TRM Chapter 13"
---

# 13 LCD Controller (LCDC)

## 13.1 Introduction

The LCD Controller contains two independent controllers — only one is active at a time:

| Controller | Interface Type | Typical Use |
|-----------|---------------|-------------|
| **Raster Controller** | Synchronous (pixel clock, HSYNC, VSYNC) | TFT / STN / DSTN passive matrix panels |
| **LIDD Controller** | Asynchronous (CS, WE, OE, ALE) | Character LCD panels, smart panels (Hitachi, 6800, 8080) |

### 13.1.1 Features

- Up to 24-bit color output (8 bpp per channel, RGB888)
- Maximum resolution: 2048 × 2048
- Built-in DMA engine — no CPU needed for frame refresh
- 512-word deep internal FIFO with programmable threshold
- Ping-pong (double) buffering: two frame buffers (FB0 and FB1)
- Palette support: 2, 4, 8, 12, 16, or 24 BPP modes
- STN (passive): 4-bit, 8-bit mono/color; DSTN; C-DSTN
- TFT (active): TN TFT, up to 16-bit or 24-bit color
- OLED (PM-OLED and AM-OLED via LIDD)
- LIDD: 2 chip selects (CS0, CS1) with independent timing

> **Silicon bug**: Pin mapping for RGB888 and RGB565 is not as designed. See AM335x Silicon Errata (SPRZ360) for correct pin mapping.

---

## 13.2 Integration

### 13.2.1 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | Peripheral Domain |
| Clock Domain | PD_PER_LCD_L3_GCLK (OCP Master/Slave), PD_PER_LCD_GCLK (Functional) |
| Reset | PER_DOM_RST_N |
| Idle/Wakeup | Standby + Smart Idle |
| Interrupt | 1 to MPU Subsystem (LCDCINT) |
| DMA Requests | None (internal DMA engine) |
| Physical Address | L4 Peripheral slave port (MMR), L3 Fast master (DMA) |

### 13.2.2 Clock Signals

| Clock | Max Freq | Source | Notes |
|-------|----------|--------|-------|
| l3_clk (Master Interface) | 200 MHz | CORE_CLKOUTM4 | pd_per_lcd_l3_gclk |
| l4_clk (Slave Interface) | 100 MHz | CORE_CLKOUTM4 / 2 (internal divider) | pd_per_lcd_l3_gclk |
| lcd_clk (Functional) | 200 MHz | Display PLL CLKOUT | pd_per_lcd_gclk |

LCD_PCLK formula: `LCD_PCLK = lcd_clk / CLKDIV` (CLKDIV ≠ 0 or 1; field in LCD_CTRL register)

### 13.2.3 Pin List

| Pin | Type | Raster Mode | LIDD Mode |
|-----|------|-------------|-----------|
| LCD_PCLK (lcd_cp) | O | Pixel Clock | Read Strobe |
| LCD_HSYNC (lcd_lp) | O | Horizontal Sync / Line Clock | Write Strobe / Direction |
| LCD_VSYNC (lcd_fp) | O | Vertical Sync / Frame Clock | Address Latch Enable |
| LCD_AC_BIAS_EN (lcd_ac) | O | AC Bias (STN) / Output Enable (TFT) | Primary Chip Select / Enable |
| LCD_MCLK (lcd_mclk) | O | Not used | Memory Clock / Secondary CS |
| LCD_D[23:0] | O | Pixel data | Data bus |
| LCD_D[15:0] | I | — | LIDD read data |

---

## 13.3 Functional Description

### 13.3.1 Clock Signals

| Signal | Behavior |
|--------|----------|
| LCD_PCLK | STN: transitions only when valid data available; TFT: continuous toggle |
| LCD_HSYNC | Toggles after all pixels in a line transmitted + programmable front/back porch |
| LCD_VSYNC | Toggles after all lines in a frame transmitted + programmable front/back porch |
| LCD_AC_BIAS_EN | STN: periodic polarity switch pulses; TFT: output enable (data valid) |

HSYNC and VSYNC polarity and edge (rising/falling) programmable via RASTER_TIMING_2[25:24].

### 13.3.2 DMA Engine

The integrated DMA engine continuously transfers frame buffer data to the input FIFO:

| Register | Purpose |
|----------|---------|
| LCDDMA_CTRL | DMA data format, burst size, endianness |
| LCDDMA_FB0_BASE | Frame buffer 0 start address |
| LCDDMA_FB0_CEILING | Frame buffer 0 end address |
| LCDDMA_FB1_BASE | Frame buffer 1 start address |
| LCDDMA_FB1_CEILING | Frame buffer 1 end address |

Enable: Set `LCDEN` bit in RASTER_CTRL (Raster) or `LIDD_DMA_EN` in LIDD_CTRL (LIDD).

> **CAUTION**: Do not write to frame buffer memory while DMA is actively reading from it. Use ping-pong (double-buffer) approach: render to FB0 while DMA reads FB1, swap at EOF interrupt.

### 13.3.3 DMA Interrupts

| Name | Register Bit | Description |
|------|-------------|-------------|
| EOF0 | IRQSTATUS_RAW[EOF0] | DMA completed reading frame buffer 0 |
| EOF1 | IRQSTATUS_RAW[EOF1] | DMA completed reading frame buffer 1 |
| DONE | IRQSTATUS_RAW[DONE] | Full frame transferred |
| FUF | IRQSTATUS_RAW[FUF] | Output FIFO underrun (DMA can't keep up) |
| SYNC | IRQSTATUS_RAW[SYNC] | Frame sync lost (invalid buffer address or BPP) |
| PL | IRQSTATUS_RAW[PL] | Palette loaded |
| ACB | IRQSTATUS_RAW[ACB] | AC bias transition count reached ACB_I value |

Clear: Write 1 to the corresponding bit in IRQSTATUS.

### 13.3.4 LIDD Controller

Enabled by clearing `MODESEL` bit in LCD_CTRL.

| LIDD_CTRL[2:0] | Interface |
|----------------|-----------|
| 000 | Synchronous Motorola 6800 |
| 001 | Asynchronous Motorola 6800 |
| 010 | Synchronous Intel 8080 |
| 011 | Asynchronous Intel 8080 |
| 100 | Hitachi HD44780 (asynchronous) |

Timing reference clock: `MCLK = lcd_clk / CLKDIV` (or = lcd_clk when CLKDIV = 0)

LIDD timing registers: LIDD_CS0_CONF and LIDD_CS1_CONF define W_SU, W_STROBE, W_HOLD, R_SU, R_STROBE, R_HOLD, CS_DELAY (field name TA).

### 13.3.5 Raster Controller Operation Modes

| Interface | Bus Width | RASTER_CTRL[9,7,1] | Data Signals | Signals |
|-----------|-----------|---------------------|-------------|---------|
| STN Mono 4-bit | 4 | 001 | LCD_DATA[3:0] | PCLK, HSYNC, VSYNC, AC_BIAS |
| STN Mono 8-bit | 8 | 101 | LCD_DATA[7:0] | PCLK, HSYNC, VSYNC, AC_BIAS |
| STN Color 8-bit | 8 | 100 | LCD_DATA[7:0] | PCLK, HSYNC, VSYNC, AC_BIAS |
| TFT Active 16-bit | 16 | x10 | LCD_DATA[15:0] | PCLK, HSYNC, VSYNC, OE (AC_BIAS) |
| TFT Active 24-bit | 24 | x10 | LCD_DATA[23:0] | PCLK, HSYNC, VSYNC, OE (AC_BIAS) |

### 13.3.6 Frame Buffer Structure

| BPP Mode | Palette Size | Pixel Data |
|----------|-------------|-----------|
| 1 bpp | 32 bytes (2 entries × 2B) | Index into palette |
| 2 bpp | 32 bytes (4 entries × 2B) | Index into palette |
| 4 bpp | 32 bytes (16 entries × 2B) | Index into palette |
| 8 bpp | 512 bytes (256 entries × 2B) | Index into palette |
| 12 bpp | 32 bytes (first entry = 4000h, rest = 0) | Direct RGB data |
| 16 bpp | 32 bytes (first entry = 4000h, rest = 0) | Direct RGB data |
| 24 bpp | 32 bytes (first entry = 4000h, rest = 0) | Direct RGB data |

Palette entry 0 bit 14 must be 1 for 12/16/24 BPP modes (signals no-palette to DMA).

---

## 13.4 Key Register Summary

| Register | Offset | Description |
|----------|--------|-------------|
| LCD_PID | 0x00 | Revision |
| LCD_CTRL | 0x04 | MODESEL[0]=1 Raster / 0 LIDD; CLKDIV[15:8] |
| LCD_LIDD_CTRL | 0x0C | LIDD interface type[2:0]; LIDD_DMA_EN; DONE_INT_EN |
| LCD_LIDD_CS0_CONF | 0x10 | CS0 timing: W_SU, W_STROBE, W_HOLD, R_SU, R_STROBE, R_HOLD, TA |
| LCD_LIDD_CS1_CONF | 0x14 | CS1 timing (same fields) |
| LCD_LIDD_CS0_DATA | 0x18 | Write/Read CS0 (LIDD) |
| LCD_LIDD_CS1_DATA | 0x1C | Write/Read CS1 (LIDD) |
| RASTER_CTRL | 0x28 | LCDEN[0], STN/TFT select, BPP, PAlette load mode |
| RASTER_TIMING_0 | 0x2C | PPL (pixels per line), HSW (sync width), HFP, HBP |
| RASTER_TIMING_1 | 0x30 | LPP (lines per panel), VSW, VFP, VBP |
| RASTER_TIMING_2 | 0x34 | ACB_I, PHSVS (polarity), IVS, IHS, IPC, ACB, ACO |
| LCDDMA_CTRL | 0x40 | DMA burst size, big/little endian, FIFO threshold |
| LCDDMA_FB0_BASE | 0x44 | Frame buffer 0 base address |
| LCDDMA_FB0_CEILING | 0x48 | Frame buffer 0 end address |
| LCDDMA_FB1_BASE | 0x4C | Frame buffer 1 base address |
| LCDDMA_FB1_CEILING | 0x50 | Frame buffer 1 end address |
| IRQSTATUS_RAW | 0x58 | Raw interrupt status |
| IRQSTATUS | 0x5C | Masked status; W1 to clear |
| IRQENABLE_SET | 0x60 | W1 to enable interrupts |
| IRQENABLE_CLEAR | 0x64 | W1 to disable interrupts |
