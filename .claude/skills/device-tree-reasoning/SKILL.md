---
name: device-tree-reasoning
description: Systematic reasoning scaffold for device-tree work. Covers node layout, compatible-string matching, pinctrl, clocks, reg addresses, probe flow, and overlay vs upstream rules. Use when writing a DT node, diagnosing probe failure, or reviewing DTS changes.
origin: custom-bsp
---

# Device Tree Reasoning — AM335x / BeagleBone Black

A reasoning scaffold, not a reference. For addresses, consult `.claude/rules/bsp-context.md` + `vault/wiki/kernel/`.

## The 7-step DT chain

When a driver fails to bind, work this chain in order. Each step is a checkpoint; a failure at step N means the problem is at step N, not later.

```
1. compatible    → matches driver's of_match_table exactly?
2. reg           → base address + size from the TRM?
3. status        → "okay" (not "disabled")?
4. clocks        → phandle resolves? clock-names strings match driver's devm_clk_get()?
5. pinctrl       → group defined? pin mux mode correct? iopad ctrl bits?
6. interrupts    → IRQ number correct? interrupt-parent points at intc?
7. sub-resources → GPIOs, regulators, IOMMU, DMA if driver uses them
```

## Project-specific overlay rule

- **NEVER** modify `linux/arch/arm/boot/dts/am33xx.dtsi`, `am33xx-clocks.dtsi`, `am335x-boneblack.dts`, or `am335x-bone-common.dtsi`. These are upstream, read-only.
- **ONLY** edit `linux/dts/am335x-boneblack-custom.dts`.
- To enable a node: `&<label> { status = "okay"; };` in the overlay. Don't duplicate the full node.
- Custom DTB output: `linux/arch/arm/boot/dts/am335x-boneblack-custom.dtb`.

## Probe-flow mental model

```
of_platform_populate()
  → parses DT, creates platform_device per node
     → kernel finds driver with matching compatible
        → driver->probe() called
           → devm_clk_get()               ← needs DT `clocks` + `clock-names`
           → devm_ioremap_resource()      ← needs DT `reg`
           → pinctrl_get_select_default() ← needs DT `pinctrl-names` + `pinctrl-0`
           → devm_request_irq()           ← needs DT `interrupts`
           → registers subsystem char/misc/input/etc device
```

If probe returns `-EPROBE_DEFER` (-517), a dependency (regulator, clock provider, gpio chip) is not yet ready. Wait for the deferred-probe queue to drain; if it stays deferred at late_initcall, real bug.

## Compatible string pitfalls

- Strings are matched byte-for-byte. "ti,tmp102" ≠ "TI,TMP102" ≠ "ti,tmp-102".
- Multi-string `compatible` arrays: the kernel picks the first driver whose `of_match_table` has ANY match. Ordering matters for fallback.
- Use `grep compatible /proc/device-tree/**/*` on the board to see what the kernel parsed.

## Pinctrl recipe (AM335x)

```dts
&am33xx_pinmux {
    my_device_pins: my-device-pins {
        pinctrl-single,pins = <
            AM33XX_IOPAD(0x<offset>, PIN_INPUT_PULLUP | MUX_MODE<N>)
        >;
    };
};

&my_device {
    pinctrl-names = "default";
    pinctrl-0 = <&my_device_pins>;
    status = "okay";
};
```

Offsets come from AM335x TRM §9.3 (Control Module pad control). `MUX_MODE<N>` selects peripheral (0–7). Pullup/pulldown bits are OR'd into the value.

## Verify on target

```bash
# Node visible to kernel?
find /proc/device-tree -name "compatible" | xargs grep -l "<compat-string>"

# Driver bound?
ls /sys/bus/platform/drivers/<driver>/ | grep <reg-addr>

# Probe status?
dmesg | grep -iE "<driver>|probe.*failed"

# Pinmux applied?
cat /sys/kernel/debug/pinctrl/44e10800.pinmux/pins | grep <pin-N>

# Clock enabled?
cat /sys/kernel/debug/clk/clk_summary | grep <clock-name>
```

## See also

- `.claude/rules/bsp-context.md` — AM335x DT file list.
- `.claude/rules/coding-standards.md` §"Device Tree" — DT coding rules.
- `vault/wiki/kernel/_index.md` — per-peripheral DT examples.
- `skills/bsp-debugging/` — runtime debug techniques when probe fails.
- `skills/karpathy-discipline/` — think-before-coding scaffold.
