---
title: Linux Commands
last_updated: 2026-04-18
category: learning
---

# Linux Commands — find, grep, sed, awk, xargs, tee, diff, patch

Essential for BSPbuild and automation.

## find — File Search

```bash
find . -name "*.c"
find . -name "*.c" -newer main.c
find . -type f -size +100k
find . -name "*.o" -delete
find . -name "Makefile" -exec grep -l "CROSS_COMPILE" {} \;
find /sys/class/gpio -name "value"
```

## grep — Content Search

```bash
grep "UART" file.c
grep -r "IRQHandler" ./drivers/
grep -n "TODO" *.c
grep -l "platform_driver" *.c
grep -v "^#" config.h
grep -E "uint(8|16|32)_t" *.h
grep -A3 -B3 "panic" dmesg.log
```

## sed — Text Editing

```bash
sed 's/foo/bar/' file.c
sed 's/foo/bar/g' file.c
sed -i 's/foo/bar/g' file.c
sed -i 's/BAUD_115200/BAUD_9600/g' *.c
sed '/^#/d' config.h
sed -n '10,20p' file.c
sed 's/\r//' file.c  # Remove Windows CRLF
```

## awk — Structured Text

```bash
awk '{print $1}' file
awk -F: '{print $1, $3}' /etc/passwd
awk '/ERROR/ {print NR, $0}' dmesg.log
awk '{sum += $2} END {print sum}' data
awk '/MemFree/ {print $2}' /proc/meminfo
arm-linux-gnueabihf-nm firmware.elf | awk '{print $1, $3}'
```

## xargs — Output as Arguments

```bash
find . -name "*.o" | xargs rm -f
find . -name "*.c" | xargs grep -l "malloc"
find . -name "*.c" | xargs wc -l
find . -name "*.c" | xargs -P4 -I{} arm-linux-gnueabihf-gcc -c {}
find . -name "*.c" -print0 | xargs -0 grep "TODO"
```

## tee — Display + Write

```bash
make 2>&1 | tee build.log
dmesg | tee dmesg.log
./run_test.sh | tee -a test_report.log
dmesg | tee full.log | grep "error" > error.log
```

## diff — Compare Files/Dirs

```bash
diff old.c new.c
diff -u old.c new.c
diff -r old_dir/ new_dir/
diff -u old.c new.c > fix.patch
diff -uw old.c new.c  # Ignore whitespace
```

## patch — Apply Patch

```bash
patch -p1 < fix.patch
patch -p0 < fix.patch
patch -p1 --dry-run < fix.patch
patch -R -p1 < fix.patch
```

## Real BSP Workflows

```bash
# Find all TODOs in kernel drivers
find drivers/tty/ -name "*.c" | xargs grep -n "TODO"

# Replace CROSS_COMPILE in all Makefiles
find . -name "Makefile" | xargs sed -i 's/arm-none-eabi-/arm-linux-gnueabihf-/g'

# Build and log, show errors on terminal
make 2>&1 | tee build.log | grep -E "error:|warning:"

# Create and apply kernel patch
diff -u drivers/net/old.c drivers/net/new.c > net-fix.patch
patch -p0 < net-fix.patch

# Check all .ko module sizes
find . -name "*.ko" | xargs ls -lh | awk '{print $5, $9}' | sort -h
```
