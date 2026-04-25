---
title: Remote Debugging — GDB
last_updated: 2026-04-18
category: learning
---

# Remote Debugging — GDB + gdbserver

## Architecture

```
Host (x86)                     Target (BeagleBone)
┌───────────────┐              ┌───────────────┐
│ arm-linux-    │  TCP/IP      │               │
│ gnueabihf-gdb │◄────────────►│  gdbserver    │
│               │  :2345       │               │
│ Send commands │              │ Run + inspect │
└───────────────┘              └───────────────┘
```

## Setup

**Compile with debug symbols:**

```bash
arm-linux-gnueabihf-gcc -g -O0 -o hello hello.c
scp hello root@192.168.7.2:/tmp/
```

**Target — run gdbserver:**

```bash
# New process
gdbserver :2345 /tmp/hello arg1 arg2

# Attach to running process
gdbserver :2345 --attach <PID>
```

**Host — connect GDB:**

```bash
arm-linux-gnueabihf-gdb hello

(gdb) set sysroot /path/to/rootfs
(gdb) target remote 192.168.7.2:2345
(gdb) break main
(gdb) continue
```

## Common GDB Commands

```bash
# Breakpoint
break main              # Break at function
break uart.c:45         # Break at file:line
break *0x80001a0        # Break at address
info breakpoints
delete 2                # Delete breakpoint #2

# Execution
continue                # Run to next breakpoint
next                    # Step over (step over)
step                    # Step into
finish                  # Run until function returns
until 60                # Run to line 60

# Display
print var               # Print variable
print /x reg_val        # Print in hex
display gpio_state      # Auto-display each step
info locals
info registers          # All CPU registers (r0-r15, pc, sp)

# Memory
x/10x 0x20000000        # 10 words hex at address
x/10i $pc               # Disassemble 10 instructions
x/s 0x80012a0           # String at address

# Stack
backtrace               # Call stack
frame 2                 # Switch to frame #2
```

## KGDB (Kernel Debug)

```bash
# Target — enable via sysfs
echo ttyO0 > /sys/module/kgdboc/parameters/kgdboc
echo g > /proc/sysrq-trigger      # Stop kernel, wait for GDB

# Host
arm-linux-gnueabihf-gdb vmlinux
(gdb) target remote /dev/ttyUSB0
(gdb) continue
```

## Core Dump Analysis

```bash
# Target — enable core dump
ulimit -c unlimited
echo "/tmp/core.%p" > /proc/sys/kernel/core_pattern
./hello                            # Crash to /tmp/core.<PID>

# Host
scp root@192.168.7.2:/tmp/core.* .
arm-linux-gnueabihf-gdb hello core.1234
(gdb) backtrace
(gdb) info registers
```

## .gdbinit

```bash
~/.gdbinit
set architecture arm
set sysroot /home/user/bbb-rootfs
target remote 192.168.7.2:2345

define hook-stop
  info registers pc sp
end
```

## Quick Reference

| Task              | Command                   |
| ----------------- | ------------------------- |
| Connect           | `target remote <ip>:2345` |
| Break at function | `break uart_init`         |
| Break at address  | `break *0x80001a0`        |
| Show crash stack  | `backtrace`               |
| Show memory       | `x/10x <addr>`            |
| Show registers    | `info registers`          |
| Exit              | `disconnect` to `quit`    |
