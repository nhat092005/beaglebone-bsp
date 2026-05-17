---
name: device-tree-reasoning
description: "Use for BeagleBone Black DTS or DT binding work: missing node, probe deferred, compatible mismatch, pinctrl, clocks, address cells, or overlay behavior."
---

Reason through this chain:

1. Node exists in the active DTB.
2. `compatible` matches the driver `of_match_table`.
3. `reg`, `#address-cells`, and `#size-cells` match parent bus rules.
4. Pinctrl mux and pad config match AM335x TRM/control module facts.
5. Clocks, regulators, interrupts, and GPIOs are present and named correctly.
6. `status = "okay"` is on the intended node and disabled where needed.
7. Kernel logs show bind/probe success or a concrete deferred-probe reason.

Verify with `dtc`, `/proc/device-tree`, `dmesg`, `/sys/bus/*/devices`, and the relevant wiki page under `vault/wiki/dts/`.
