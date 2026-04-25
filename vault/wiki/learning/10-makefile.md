---
title: Makefile
last_updated: 2026-04-18
category: learning
---

# Makefile — Embedded C / BSP

## Basic Syntax

```makefile
target: dependency1 dependency2
<TAB>command          # MUST be TAB, not spaces
```

## Automatic Variables

| Variable | Meaning          | Example                |
| -------- | ---------------- | ---------------------- |
| `$@`     | Target name      | `main.o`               |
| `$<`     | First dependency | `main.c`               |
| `$^`     | All dependencies | `main.c utils.c`       |
| `$*`     | Stem of pattern  | `main` (from `main.c`) |

```makefile
main.o: main.c config.h
	$(CC) -c $< -o $@

firmware.elf: main.o uart.o gpio.o
	$(CC) $^ -o $@
```

## Pattern Rules — Batch Compile

```makefile
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@
```

## Phony Targets — Non-file Targets

```makefile
.PHONY: all clean flash

all: firmware.elf

clean:
	rm -f *.o *.elf

flash: firmware.bin
	st-flash write $< 0x8000000
```

## Complete Embedded Makefile

```makefile
# Toolchain
CROSS   = arm-linux-gnueabihf-
CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
SIZE    = $(CROSS)size

# Flags
CFLAGS  = -mcpu=cortex-a8 -mfpu=neon -O2 -Wall -Wextra
CFLAGS += -Iinclude
LDFLAGS = -T linker.ld -nostartfiles

# Sources & Objects
SRCS = main.c uart.c gpio.c i2c.c
OBJS = $(SRCS:.c=.o)

TARGET = firmware

# ── Rules ──────────────────────────────────────
.PHONY: all clean flash size

all: $(TARGET).elf $(TARGET).bin

$(TARGET).elf: $(OBJS)
	$(CC) $(LDFLAGS) $^ -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

size: $(TARGET).elf
	$(SIZE) $<

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin
```

## Automatic Dependencies

```makefile
CFLAGS += -MMD -MP
-include $(OBJS:.o=.d)

# main.d contains: main.o: main.c include/uart.h include/config.h
# uart.h changes main.o auto rebuild
```

## Common Patterns

```makefile
# Build for multiple boards
BOARD ?= beaglebone

ifeq ($(BOARD), beaglebone)
    CFLAGS += -DBOARD_BBB
    CROSS  = arm-linux-gnueabihf-
endif

# Verbose build: make V=1
ifeq ($(V),1)
    Q =
else
    Q = @        # Hide command, show output only
endif

%.o: %.c
	$(Q)$(CC) $(CFLAGS) -c $< -o $@

# Recursive build (subdirectories)
SUBDIRS = drivers/uart drivers/gpio

.PHONY: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@
```

## Quick Reference

```makefile
$(SRCS:.c=.o)        # Replace suffix: .c to .o
$(notdir path/file)  # Get filename without path
$(wildcard *.c)      # Glob all .c files
$(shell uname -m)    # Run shell command
$(info "msg")        # Debug: print message
```
