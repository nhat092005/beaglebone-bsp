---
name: bsp-debugging
description: Debugging techniques for BeagleBone BSP. Covers kernel crash analysis (oops/panic), JTAG/GDB, serial console, dynamic debug, FreeRTOS task inspection, U-Boot debug, and Yocto build issue diagnosis.
origin: custom-bsp
---

# BSP Debugging Guide — BeagleBone Black

Systematic debugging techniques for all layers of the BSP stack.

## Serial Console (First Line of Defense)

```bash
# Connect to BeagleBone serial console (USB-to-UART on J1)
picocom -b 115200 /dev/ttyUSB0

# Or minicom
minicom -D /dev/ttyUSB0 -b 115200
```

## Kernel Debugging

### Dynamic Debug (printk)
```bash
# Enable debug messages for a driver at runtime (no recompile)
echo "module my_driver +p" > /sys/kernel/debug/dynamic_debug/control
echo "file drivers/misc/my_driver.c +p" > /sys/kernel/debug/dynamic_debug/control

# In driver code
dev_dbg(&dev->dev, "register val: 0x%08x\n", val);  // activated by dynamic_debug
pr_debug("module level debug: %d\n", val);
```

### Kernel Oops Analysis
```
# Typical oops format — read this:
Unable to handle kernel NULL pointer dereference at virtual address 00000000
PC is at my_irq_handler+0x24/0x80 [my_driver]
LR is at __irq_enter_raw+0x10/0x20

# Decode with addr2line:
arm-linux-gnueabihf-addr2line -e vmlinux -s 0xc0<address>

# Or use faddr2line script:
scripts/faddr2line vmlinux my_irq_handler+0x24/0x80
```

### DebugFS Inspection
```bash
# Mount debugfs (usually auto-mounted)
mount -t debugfs none /sys/kernel/debug

# Check pinctrl
cat /sys/kernel/debug/pinctrl/44e10800.pinmux/pins
cat /sys/kernel/debug/pinctrl/44e10800.pinmux/pingroups

# Check clocks
cat /sys/kernel/debug/clk/clk_summary

# Check regmap registers (if driver uses regmap)
cat /sys/kernel/debug/regmap/*/registers
```

### Driver & Device Inspection
```bash
# Check if driver is loaded
lsmod | grep my_driver
dmesg | grep my_driver

# Check device binding
ls -la /sys/bus/platform/drivers/my_driver/
cat /sys/bus/platform/devices/48300000.my_device/uevent

# GPIO state
gpioinfo                          # all GPIO state
gpioget gpiochip0 14              # read GPIO

# I2C scan
i2cdetect -y 1

# SPI test
spidev_test -D /dev/spidev0.0 -v
```

## U-Boot Debugging

```bash
# In U-Boot prompt — inspect environment
printenv
printenv bootargs

# Memory read (check register)
md.l 0x44e07000 0x10    # read 16 words from UART0 base

# Memory write (set register)
mw.l 0x44e07000 0x7FF

# Test DT loading
fdt addr ${fdtaddr}
fdt print /

# Load and boot manually
load mmc 0:2 ${loadaddr} /boot/zImage
load mmc 0:2 ${fdtaddr} /boot/am335x-boneblack.dtb
bootz ${loadaddr} - ${fdtaddr}
```

## FreeRTOS Debugging

### Task State Inspection
```c
/* In your FreeRTOS app — print task list */
char task_buf[512];
vTaskList(task_buf);
printf("Task Name\tState\tPrio\tStack\tNum\r\n");
printf("%s\r\n", task_buf);

/* Check runtime stats */
char stats_buf[512];
vTaskGetRunTimeStats(stats_buf);
printf("%s\r\n", stats_buf);
```

### Stack Overflow Detection
```c
/* In FreeRTOSConfig.h */
#define configCHECK_FOR_STACK_OVERFLOW  2
#define configUSE_MALLOC_FAILED_HOOK    1
#define configUSE_TRACE_FACILITY        1
#define configGENERATE_RUN_TIME_STATS   1

/* Hook implementations */
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    printf("STACK OVERFLOW in task: %s\r\n", pcTaskName);
    taskDISABLE_INTERRUPTS();
    for (;;);
}
```

### RPMsg/OpenAMP Debug
```bash
# Linux side — check remoteproc
ls /sys/class/remoteproc/
cat /sys/class/remoteproc/remoteproc0/state

# Load FreeRTOS firmware
echo "freertos_app.elf" > /sys/class/remoteproc/remoteproc0/firmware
echo start > /sys/class/remoteproc/remoteproc0/state

# Check RPMsg device created
ls /dev/rpmsg*
cat /dev/rpmsg0  # read messages from FreeRTOS
```

## Yocto/BitBake Debugging

```bash
# Verbose build
bitbake -v my_recipe

# Interactive shell in recipe work dir
bitbake -c devshell my_recipe

# Show all variables for a recipe
bitbake -e my_recipe | grep "^VAR_NAME"

# Check do_compile log
cat tmp/work/<arch>/my_recipe/*/temp/log.do_compile

# Dependency graph
bitbake -g my_recipe && cat pn-depends.dot | grep my_recipe

# Find which recipe provides a file
oe-pkgdata-util find-path /usr/lib/libmy.so
```

## GDB Remote Debug

```bash
# Target side: start gdbserver
gdbserver :1234 ./my_app

# Host side: cross-gdb
arm-linux-gnueabihf-gdb ./my_app
(gdb) target remote <bbb_ip>:1234
(gdb) break main
(gdb) continue

# Kernel debugging via KGDB (serial)
# Add to bootargs: kgdboc=ttyO0,115200 kgdbwait
arm-linux-gnueabihf-gdb vmlinux
(gdb) target remote /dev/ttyUSB0
```

## Quick Checklist When Something Doesn't Work

```
1. Serial console → Any kernel errors/oops?
2. dmesg | grep -i error → Error messages from driver?
3. ls /sys/bus/platform/devices/ → Device detected by kernel?
4. cat /sys/bus/platform/drivers/ → Driver loaded?
5. /sys/kernel/debug/pinctrl → Pins configured correctly?
6. /sys/kernel/debug/clk → Required clocks enabled?
7. i2cdetect / spidev_test → Hardware responding?
8. dmesg | grep <driver_name> → Probe success/fail?
```
