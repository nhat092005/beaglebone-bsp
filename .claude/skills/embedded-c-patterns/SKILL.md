---
name: embedded-c-patterns
description: C coding patterns and best practices for BeagleBone BSP. Covers kernel driver patterns, FreeRTOS idioms, interrupt safety, MMIO access, DMA patterns, and Yocto recipe writing.
origin: custom-bsp
---

# Embedded C Patterns — BeagleBone BSP

Reference patterns for writing correct, safe embedded C code in this project.

## Kernel Driver Patterns

### Resource-Managed Allocation (devm_*)
```c
// GOOD: devm_* auto-freed on driver detach
struct my_dev *dev = devm_kzalloc(&pdev->dev, sizeof(*dev), GFP_KERNEL);
if (!dev)
    return -ENOMEM;

void __iomem *base = devm_ioremap_resource(&pdev->dev, res);
if (IS_ERR(base))
    return PTR_ERR(base);

int irq = devm_request_irq(&pdev->dev, irq_num, my_irq_handler,
                            IRQF_SHARED, "my-driver", dev);

// BAD: manual alloc without devm — easy to leak on error path
struct my_dev *dev = kzalloc(sizeof(*dev), GFP_KERNEL);
// requires manual kfree in every error path and .remove()
```

### Error Path Pattern (goto cleanup)
```c
static int my_probe(struct platform_device *pdev)
{
    struct my_dev *dev;
    int ret;

    dev = devm_kzalloc(&pdev->dev, sizeof(*dev), GFP_KERNEL);
    if (!dev)
        return -ENOMEM;

    dev->clk = devm_clk_get(&pdev->dev, "fck");
    if (IS_ERR(dev->clk)) {
        ret = PTR_ERR(dev->clk);
        goto err_clk;
    }

    ret = clk_prepare_enable(dev->clk);
    if (ret)
        goto err_clk;

    /* success */
    platform_set_drvdata(pdev, dev);
    return 0;

err_clk:
    dev_err(&pdev->dev, "Failed to get clock: %d\n", ret);
    return ret;
}
```

### MMIO Register Access
```c
// GOOD: Use ioread/iowrite for proper barriers
u32 val = ioread32(dev->base + REG_CTRL);
iowrite32(val | BIT(0), dev->base + REG_CTRL);

// Use BIT() and GENMASK() for register bits
#define CTRL_ENABLE     BIT(0)
#define CTRL_MODE_MASK  GENMASK(3, 1)
#define CTRL_MODE(x)    (((x) << 1) & CTRL_MODE_MASK)

// BAD: direct pointer dereference of MMIO
*(volatile u32 *)(dev->base + REG_CTRL) = val;  // missing barriers
```

### Spinlock for IRQ-shared data
```c
struct my_dev {
    spinlock_t lock;
    u32 shared_data;
};

/* In process context */
static void update_data(struct my_dev *dev, u32 val)
{
    unsigned long flags;
    spin_lock_irqsave(&dev->lock, flags);
    dev->shared_data = val;
    spin_unlock_irqrestore(&dev->lock, flags);
}

/* In IRQ handler */
static irqreturn_t my_irq_handler(int irq, void *data)
{
    struct my_dev *dev = data;
    unsigned long flags;

    spin_lock_irqsave(&dev->lock, flags);
    /* access dev->shared_data safely */
    spin_unlock_irqrestore(&dev->lock, flags);

    return IRQ_HANDLED;
}
```

### Device Tree Matching
```c
static const struct of_device_id my_of_match[] = {
    { .compatible = "mycompany,my-device-v1", .data = &my_v1_data },
    { .compatible = "mycompany,my-device-v2", .data = &my_v2_data },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, my_of_match);

static int my_probe(struct platform_device *pdev)
{
    const struct of_device_id *match;
    match = of_match_device(my_of_match, &pdev->dev);
    if (!match)
        return -ENODEV;
    /* use match->data for version-specific config */
}
```

## FreeRTOS Patterns

### Task with proper stack and priority
```c
#define MY_TASK_STACK_SIZE  (configMINIMAL_STACK_SIZE * 4)
#define MY_TASK_PRIORITY    (tskIDLE_PRIORITY + 2)

static TaskHandle_t my_task_handle = NULL;

void my_task(void *pvParameters)
{
    my_task_config_t *cfg = (my_task_config_t *)pvParameters;

    for (;;) {
        /* Wait for event with timeout */
        if (xSemaphoreTake(cfg->sem, pdMS_TO_TICKS(1000)) == pdTRUE) {
            /* process event */
        } else {
            /* timeout handling */
        }
    }
    vTaskDelete(NULL);  /* should not reach here */
}

/* Create task */
xTaskCreate(my_task, "MyTask", MY_TASK_STACK_SIZE,
            &task_config, MY_TASK_PRIORITY, &my_task_handle);
```

### Queue from ISR (interrupt-safe)
```c
/* From ISR — use FromISR variants */
static void ICACHE_RAM_ATTR my_hw_irq_handler(void)
{
    BaseType_t higher_prio_task_woken = pdFALSE;
    uint32_t event = read_hw_event();

    xQueueSendFromISR(event_queue, &event, &higher_prio_task_woken);
    portYIELD_FROM_ISR(higher_prio_task_woken);
}
```

## Yocto Recipe Patterns

### Kernel module recipe
```bitbake
SUMMARY = "BeagleBone custom kernel module"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=abc123"

inherit module

SRC_URI = "file://Makefile \
           file://my_driver.c \
           file://my_driver.h \
          "

S = "${WORKDIR}"

KERNEL_MODULE_AUTOLOAD += "my_driver"
KERNEL_MODULE_PROBECONF += "my_driver"
module_conf_my_driver = "options my_driver param=1"
```

### bbappend for kernel config
```bitbake
# meta-bbb/recipes-kernel/linux/linux-bbb_%.bbappend
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://0001-add-my-driver.patch \
            file://my_driver.cfg \
           "
```

## Common Anti-Patterns to Avoid

```c
/* BAD: sleeping function in IRQ context */
irqreturn_t bad_irq(int irq, void *data) {
    msleep(10);           // WRONG: can sleep
    mutex_lock(&m);       // WRONG: can sleep
    kmalloc(sz, GFP_KERNEL); // WRONG: can sleep
    return IRQ_HANDLED;
}

/* BAD: no timeout in busy wait */
while (!(ioread32(base + STATUS) & READY_BIT));  // can hang forever

/* GOOD: with timeout */
int timeout = 1000;
while (!(ioread32(base + STATUS) & READY_BIT) && --timeout)
    udelay(1);
if (!timeout)
    return -ETIMEDOUT;
```
