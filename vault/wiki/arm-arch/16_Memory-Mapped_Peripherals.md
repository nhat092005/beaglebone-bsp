---
title: ARM Architecture Chapter 16 Memory-Mapped Peripherals
tags:
  - arm-arch
  - reference
date: 2026-04-18
---

# Chapter 16: Memory-Mapped Peripherals

## 16.1 Memory-Mapped I/O

Peripherals (Timers, UARTs, ADCs, GPIOs) are controlled via registers that are mapped into the processor's memory address space. Accessing these peripherals is done using standard `LDR` and `STR` instructions.

*Note: You must typically enable the clock to a peripheral before attempting to read/write its registers, otherwise a Fault exception may occur.*

## 16.2 UART Example (LPC2104)

### Pin Configuration
Most microcontroller pins are multiplexed. You must configure the pin to act as a UART pin instead of a standard GPIO pin.
```asm
PINSEL0 EQU 0xE002C000        ; Pin function select register

LDR     r5, =PINSEL0
LDR     r6, [r5]              ; Read-modify-write to preserve other pins
BIC     r6, r6, #0xF          ; Clear lower nibble (P0.0 and P0.1)
ORR     r6, r6, #0x5          ; Set P0.0 to Tx0 and P0.1 to Rx0
STR     r6, [r5]
```

### UART Configuration
```asm
U0START EQU 0xE000C000        ; UART0 Base
LCR0    EQU 0x0C              ; Line Control Register offset

LDR     r5, =U0START
MOV     r6, #0x83             ; 8 bits, no parity, 1 stop bit, DLAB = 1 (to set baud)
STRB    r6, [r5, #LCR0]       
MOV     r6, #0x61             ; Divisor for 9600 baud @ 15 MHz
STRB    r6, [r5]              ; Write to divisor latch
MOV     r6, #3                ; DLAB = 0 (lock baud rate, enable Tx/Rx buffers)
STRB    r6, [r5, #LCR0]
```

### Transmitting Data (Polling)
```asm
LSR0    EQU 0x14              ; Line Status Register offset

Transmit
        LDR   r5, =U0START
wait    LDRB  r6, [r5, #LSR0] ; Get status
        CMP   r6, #0x20       ; Is bit 5 (THRE - Transmitter Holding Reg Empty) set?
        BEQ   wait            ; Spin until buffer is empty
        STRB  r0, [r5]        ; Write character in r0 to UART
        BX    lr
```

## 16.3 Digital-to-Analog Converter (DAC) Example (LPC2132)

Generates an analog voltage based on a 10-bit value (0 to 1023). Output voltage = `(value / 1024) * VREF`.

```asm
DACREG  EQU 0xE006C000        ; DAC Register
; ... Pin configuration omitted ...

; Assume r0 contains a Q31 sine value from -1.0 to +1.0
ASR   r0, r0, #16             ; Convert Q31 to Q15
LSL   r0, r0, #9              ; Multiply by 512 (amplitude)
ASR   r0, r0, #15             ; Keep integer part only
ADD   r0, r0, #512            ; Offset by 512 so range is 0 to 1024
LSL   r0, r0, #6              ; DAC register expects data in bits [15:6]
LDR   r8, =DACREG
STRH  r0, [r8]                ; Write to DAC
```

## 16.4 GPIO Example (Tiva TM4C123GH6PM / Cortex-M4)

Controlling an on-board RGB LED via GPIO Port F (Pins PF1, PF2, PF3).

### Enable Clock to GPIO Port F
```asm
MOVW  r0, #0xE000
MOVT  r0, #0x400F             ; System Control Base 0x400FE000
MOVW  r2, #0x608              ; RCGCGPIO register offset
LDR   r1, [r0, r2]
ORR   r1, r1, #0x20           ; Enable clock for Port F (bit 5)
STR   r1, [r0, r2]
; Note: Require 3 clock cycles delay before accessing GPIO registers
```

### Configure Pins as Outputs
```asm
MOVW  r0, #0x5000
MOVT  r0, #0x4002             ; GPIO Port F Base 0x40025000

; Set Direction (GPIODIR offset 0x400)
MOVW  r2, #0x400              
MOV   r1, #0xE                ; Pins 1, 2, 3 as outputs (0b1110)
STR   r1, [r0, r2]

; Enable Digital I/O (GPIODEN offset 0x51C)
MOVW  r2, #0x51C
STR   r1, [r0, r2]
```

### Writing to GPIO using Masked Addressing
The TM4C123 provides a hardware feature where bits `[9:2]` of the address act as a bit-mask for writing to the GPIO data register. This avoids software read-modify-write.

```asm
; We only want to alter pins 1, 2, 3.
; Mask value = 0b0011_1000 (0x38). 

MOV   r6, #2                  ; Turn on Red LED (PF1)
STR   r6, [r0, #0x38]         ; Base 0x40025000 + 0x38 mask. 
```
