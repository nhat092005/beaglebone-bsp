---
title: AM335x Chapter 5 — Graphics Accelerator SGX530
tags:
  - am335x
  - sgx
  - graphics
  - reference
source: "AM335x TRM Chapter 5"
---

# 5 Graphics Accelerator SGX530

## 5.1 Introduction

The AM335x integrates an Imagination Technologies PowerVR SGX530 3D graphics engine. It supports OpenGL ES 1.1 and 2.0, and OpenVG 1.1. The SGX is a slave peripheral — it does not have independent access to external pins; all external display access is handled by the LCD Controller (Chapter 13).

### 5.1.1 Features

| Feature | Detail |
|---------|--------|
| GPU Core | PowerVR SGX530 |
| API Support | OpenGL ES 1.1, OpenGL ES 2.0, OpenVG 1.0.1 |
| Programmable Shaders | Universal Scalable Shader Engine (USSE) |
| Memory Architecture | Tile-based deferred rendering |
| Texture Compression | PVRTC, ETC1 |
| Anti-aliasing | Full-scene anti-aliasing (FSAA) |
| Display Output | Via LCD Controller — no direct external pins |

### 5.1.2 Unsupported Features

There are **no** unsupported SGX530 features for the AM335x device.

---

## 5.2 Integration

### 5.2.1 Connectivity Attributes

| Attribute | Value |
|-----------|-------|
| Power Domain | SGX Power Domain (PD_GFX) |
| Clock Domain | PD_GFX_L3_GCLK (OCP), PD_GFX_GCLK (core) |
| Max Clock | 200 MHz (L3 interface), 200 MHz (SGX core) |
| Reset | GFX_DOM_RST_N |
| Idle/Wakeup | Smart Idle, Smart Standby |
| Interrupt | THALIAIRQ (GFXINT) to MPU Subsystem |
| DMA Requests | None |
| Physical Address | L3 Main slave port (MMR) |

### 5.2.2 Clock Signals

| Clock Signal | Max Freq | Source | Domain / Notes |
|-------------|----------|--------|----------------|
| SYSCLK (Interface clock) | 200 MHz | CORE_CLKOUTM4 | pd_gfx_gfx_l3_gclk; L3F clock |
| MEMCLK (Memory clock) | 200 MHz | CORE_CLKOUTM4 | pd_gfx_gfx_l3_gclk; L3F clock |
| CORECLK (Functional clock) | 200 MHz | CORE_CLKOUTM4 **or** PER_CLKOUTM2 (192 MHz, optionally ÷2) | pd_gfx_gfx_fclk |

### 5.2.3 Pin List

The SGX530 has **no external interface pins**. All display output is routed through the LCD Controller.

---

## 5.3 Functional Description

### 5.3.1 USSE — Universal Scalable Shader Engine

The USSE is the programmable shader core inside SGX530. It executes vertex and fragment shader programs written in GLSL ES. The USSE delivers unified shader processing for both geometry and pixel pipelines.

### 5.3.2 Memory Architecture

The SGX uses a tile-based deferred rendering (TBDR) approach:
1. Geometry pass: all primitives are binned into screen tiles
2. Render pass: each tile is rendered fully in on-chip memory, then written back to the framebuffer in DDR

This approach minimizes bandwidth usage compared to immediate-mode renderers.

| Memory | Description |
|--------|-------------|
| Parameter Buffer | Stores tiled geometry data in system memory (DDR) |
| Pixel Back End Local Memory | On-chip tile buffer for color and depth |
| Framebuffer | System memory (DDR), accessed via L3 |

### 5.3.3 Interrupt

The SGX generates a single interrupt (`THALIAIRQ`, also referred to as `GFXINT`) to the ARM MPU subsystem. Software must read the SGX internal interrupt status registers to determine the source (rendering complete, page fault, etc.).

---

## 5.4 Register Access

The SGX MMR base address is at the SGX L3 slave port. Register access is through the SGX kernel driver (e.g., `pvrsrvkm.ko`). Direct register definitions are not publicly documented by Imagination Technologies; refer to the TI Graphics SDK for AM335x.

---

## 5.5 Software Notes

- The SGX requires TI's proprietary user-space graphics driver (provided in the AM335x Graphics SDK / SGX DDK).
- The kernel module is typically `pvrsrvkm.ko`.
- The framebuffer rendered by SGX is written to a region of DDR; the LCDC DMA engine then reads that region and drives the LCD panel.
- PRCM must enable `PD_GFX` power domain and `pd_gfx_gclk` / `pd_gfx_l3_gclk` before accessing the SGX.
