---
title: Python Scripting
last_updated: 2026-04-18
category: learning
---

# Python Scripting — Embedded / BSP

## Read / Write File

```python
# Read all
with open("build.log") as f:
    content = f.read()

# Read by line
with open("dmesg.log") as f:
    for line in f:
        if "error" in line.lower():
            print(line.strip())

# Write
with open("report.txt", "w") as f:
    f.write("Build OK\n")

# Append
with open("test.log", "a") as f:
    f.write(f"[PASS] GPIO test\n")

# Binary — read firmware, flash image
with open("firmware.bin", "rb") as f:
    data = f.read()
    print(hex(int.from_bytes(data[:4], "little")))
```

## subprocess — Run Shell Commands

```python
import subprocess

# Run and get output
result = subprocess.run(
    ["arm-linux-gnueabihf-size", "firmware.elf"],
    capture_output=True, text=True
)
print(result.stdout)
print(result.returncode)  # 0 = success

# Run via shell (pipe, wildcard)
subprocess.run("make 2>&1 | tee build.log", shell=True)

# Raise exception on failure
subprocess.run(["make", "clean"], check=True)

# Stream output realtime
proc = subprocess.Popen(["dmesg", "-w"], stdout=subprocess.PIPE, text=True)
for line in proc.stdout:
    if "error" in line:
        print(line.strip())
```

## argparse — CLI Arguments

```python
import argparse

parser = argparse.ArgumentParser(description="Flash firmware to board")
parser.add_argument("firmware", help="Path to .bin file")
parser.add_argument("--port", default="/dev/ttyUSB0", help="Serial port")
parser.add_argument("--baud", type=int, default=115200)
parser.add_argument("--verify", action="store_true", help="Verify after flash")
parser.add_argument("--board", choices=["bbb", "rpi"], default="bbb")

args = parser.parse_args()

# Usage:
# python flash.py firmware.bin --port /dev/ttyUSB1 --baud 9600 --verify
# python flash.py --help
```

## json — Config and Structured Log

```python
import json

# Read config
with open("board_config.json") as f:
    cfg = json.load(f)
print(cfg["board"])       # "beaglebone"
print(cfg["uart"]["baud"])  # 115200

# Write test results
results = {
    "board": "bbb",
    "tests": [
        {"name": "gpio", "status": "PASS"},
        {"name": "i2c", "status": "FAIL", "error": "timeout"},
    ]
}
with open("test_report.json", "w") as f:
    json.dump(results, f, indent=2)

# Parse from string
data = json.loads('{"status": "ok", "temp": 45}')
```

## Real Script — Build & Flash

```python
#!/usr/bin/env python3
import argparse, subprocess, json, sys
from pathlib import Path

parser = argparse.ArgumentParser(description="Build and flash BBB firmware")
parser.add_argument("--board",  default="bbb")
parser.add_argument("--flash",  action="store_true")
parser.add_argument("--report", default="report.json")
args = parser.parse_args()

# Build
print("[*] Building...")
result = subprocess.run(
    ["make", f"BOARD={args.board}", "-j4"],
    capture_output=True, text=True
)

report = {"board": args.board, "build": "PASS" if result.returncode == 0 else "FAIL"}

if result.returncode != 0:
    print(result.stderr)
    report["error"] = result.stderr[-500:]
else:
    # Get firmware size
    size = subprocess.run(
        ["arm-linux-gnueabihf-size", "firmware.elf"],
        capture_output=True, text=True
    )
    report["size"] = size.stdout.splitlines()[-1]

    # Flash if needed
    if args.flash and Path("firmware.bin").exists():
        subprocess.run(["st-flash", "write", "firmware.bin", "0x8000000"], check=True)
        report["flash"] = "DONE"

# Save report
with open(args.report, "w") as f:
    json.dump(report, f, indent=2)

print(json.dumps(report, indent=2))
sys.exit(0 if report["build"] == "PASS" else 1)
```

## Quick Reference

| Task            | Code                                                     |
| --------------- | -------------------------------------------------------- |
| Read file       | `open(f).read()` / `for line in f`                       |
| Run command     | `subprocess.run([...], capture_output=True)`             |
| Realtime output | `subprocess.Popen` + iterate stdout                      |
| CLI args        | `argparse` — `add_argument`, `parse_args()`              |
| JSON load/save  | `json.load(f)` / `json.dump(obj, f, indent=2)`           |
| Path handling   | `from pathlib import Path` `Path("dir/file").exists()` |
| Exit code       | `sys.exit(0)` success, `sys.exit(1)` fail                |
