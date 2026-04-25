---
title: AM335x Hardware Reference
last_updated: 2026-04-18
category: references
---

# AM335x Hardware Reference

TI AM335x (Cortex-A8) Technical Reference Manual — chapter summaries for BSP development.

## Chapters

| #   | Topic                                           | File                                                                                                    |
| --- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 02  | Memory Map — L3/L4 interconnect, address ranges | [[Chapter_02_Memory_Map.md]]                                                                            |
| 03  | ARM MPU — Cortex-A8 core, MMU, cache            | [[Chapter_03_ARM_MPU_Subsystem.md]]                                                                     |
| 04  | PRU-ICSS — Programmable Real-Time Unit          | [[Chapter_04_Programmable_Real-Time_Unit_Subsystem_and_Industrial_Communication_Subsystem_PRU-ICSS.md]] |
| 05  | SGX — Graphics accelerator (not used on BBB)    | [[Chapter_05_Graphics_Accelerator_SGX.md]]                                                              |
| 06  | Interrupts — GIC, INTC, interrupt routing       | [[Chapter_06_Interrupts.md]]                                                                            |
| 07  | Memory Subsystem — DDR, EMIF, GPMC              | [[Chapter_07_Memory_Subsystem.md]]                                                                      |
| 08  | PRCM — Power, reset, clock management           | [[Chapter_08_Power_Reset_and_Clock_Management_PRCM.md]]                                                 |
| 09  | Control Module — Pin multiplexing (MUX)         | [[Chapter_09_Control_Module.md]]                                                                        |
| 10  | Interconnects — L3, L4, OCP                     | [[Chapter_10_Interconnects.md]]                                                                         |
| 11  | EDMA — Enhanced DMA controller                  | [[Chapter_11_Enhanced_Direct_Memory_Access_EDMA.md]]                                                    |
| 12  | Touchscreen — TSC helper ADC                    | [[Chapter_12_Touchscreen_Controller.md]]                                                                |
| 13  | LCD Controller — Display output                 | [[Chapter_13_LCD_Controller.md]]                                                                        |
| 14  | Ethernet — CPSW, MDIO                           | [[Chapter_14_Ethernet_Subsystem.md]]                                                                    |
| 15  | PWMSS — EHRPWM, eCAP, eQEP                      | [[Chapter_15_Pulse-Width_Modulation_Subsystem_PWMSS.md]]                                                |
| 16  | USB — OTG, host, peripheral                     | [[Chapter_16_Universal_Serial_Bus_USB.md]]                                                              |
| 17  | IPC — Mailbox, Spinlock                         | [[Chapter_17_Interprocessor_Communication.md]]                                                          |
| 18  | MMC/SD — eMMC, microSD host                     | [[Chapter_18_Multimedia_Card_MMC.md]]                                                                   |
| 19  | UART — Serial console (ttyO0)                   | [[Chapter_19_Universal_Asynchronous_ReceiverTransmitter_UART.md]]                                       |
| 20  | Timers — DMTimer, GPTimer                       | [[Chapter_20_Timers.md]]                                                                                |
| 21  | I2C — I2C0 (PMIC), I2C1, I2C2                   | [[Chapter_21_I2C.md]]                                                                                   |
| 22  | McASP — Audio serial port                       | [[Chapter_22_Multichannel_Audio_Serial_Port_McASP.md]]                                                  |
| 23  | CAN — CAN bus controller                        | [[Chapter_23_Controller_Area_Network_CAN.md]]                                                           |
| 24  | McSPI — SPI controller                          | [[Chapter_24_Multichannel_Serial_Port_Interface_McSPI.md]]                                              |
| 25  | GPIO — GPIO1, GPIO2, GPIO3                      | [[Chapter_25_General-Purpose_InputOutput.md]]                                                           |
| 26  | Initialization — Boot flow                      | [[Chapter_26_Initialization.md]]                                                                        |
| 27  | Debug — JTAG, Trace                             | [[Chapter_27_Debug_Subsystem.md]]                                                                       |

## Quick Access

**BBB常用Peripheral:**

| Peripheral     | Address    | Chapter |
| -------------- | ---------- | ------- |
| GPIO0 (wakeup) | 0x44E07000 | 25      |
| GPIO1          | 0x4804C000 | 25      |
| GPIO2          | 0x481AC000 | 25      |
| UART0          | 0x44E09000 | 19      |
| I2C0 (PMIC)    | 0x44E0B000 | 21      |
| I2C1           | 0x4802A000 | 21      |

## References

- AM335x TRM: https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
- BBB SRM: https://github.com/beagleboard/beaglebone-black/wiki/System-Reference-Manual
