#!/usr/bin/env python3
"""BeagleBone UART debug CLI — capture boot logs, send cmds, scan for errors.

Companion to .claude/agents/board-runner.md. See docs/09-debug-agent.md.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import uuid
from pathlib import Path

try:
    import serial
except ImportError:
    serial = None

import yaml

DEFAULT_PORT = "/dev/ttyUSB0"
DEFAULT_BAUD = 115200
BOOT_COMPLETE_MARKERS = (
    "login:",
    "Welcome to Poky",
    "Reached target Multi-User",
    "Reached target Login Prompts",
)
PROMPT_DEFAULT = re.compile(
    r"(root@[\w\-]+:[^\s]*\s*[#\$]|[\w\-]+@[\w\-]+:[^\s]*\s*[#\$])\s*$"
)


def _need_serial() -> None:
    if serial is None:
        sys.exit(
            "error: pyserial not installed — "
            "run `pip install -r scripts/requirements-debug.txt`"
        )


def _open_port(port: str, baud: int):
    _need_serial()
    return serial.Serial(
        port=port,
        baudrate=baud,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1.0,
        write_timeout=2.0,
    )


def cmd_capture_boot(args: argparse.Namespace) -> int:
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    ser = _open_port(args.port, args.baud)
    print(
        f"[bbb-uart] listening on {args.port} @ {args.baud} — "
        f"press BBB reset button now (timeout {args.timeout}s)",
        file=sys.stderr,
    )

    start = time.monotonic()
    lines: list[str] = []
    boot_complete = False
    last_activity = start

    with out.open("w", encoding="utf-8") as fh, ser:
        while (time.monotonic() - start) < args.timeout:
            raw = ser.readline()
            if not raw:
                if boot_complete and (time.monotonic() - last_activity) > 2.0:
                    break
                continue
            line = raw.decode("utf-8", errors="ignore").rstrip("\r\n")
            if not line:
                continue
            fh.write(line + "\n")
            fh.flush()
            lines.append(line)
            last_activity = time.monotonic()
            if any(m in line for m in BOOT_COMPLETE_MARKERS):
                boot_complete = True

    elapsed = time.monotonic() - start
    result = {
        "cmd": "capture-boot",
        "port": args.port,
        "out": str(out),
        "lines_captured": len(lines),
        "boot_complete": boot_complete,
        "elapsed_s": round(elapsed, 2),
        "status": "complete" if boot_complete else "timeout",
    }
    print(json.dumps(result, indent=2))
    return 0 if boot_complete else 2


def cmd_send(args: argparse.Namespace) -> int:
    prompt_re = re.compile(args.prompt_regex) if args.prompt_regex else PROMPT_DEFAULT
    sentinel = f"__DONE_{uuid.uuid4().hex[:8]}__"
    wrapped = f"{args.command}; echo {sentinel}\r\n"

    ser = _open_port(args.port, args.baud)
    start = time.monotonic()
    collected: list[str] = []
    matched_sentinel = False

    with ser:
        ser.reset_input_buffer()
        ser.write(wrapped.encode("utf-8"))
        ser.flush()
        while (time.monotonic() - start) < args.timeout:
            raw = ser.readline()
            if not raw:
                continue
            line = raw.decode("utf-8", errors="ignore").rstrip("\r\n")
            if not line:
                continue
            if sentinel in line:
                matched_sentinel = True
                break
            collected.append(line)

    if collected and args.command in collected[0]:
        collected = collected[1:]

    result = {
        "cmd": args.command,
        "output": collected,
        "sentinel_matched": matched_sentinel,
        "elapsed_s": round(time.monotonic() - start, 2),
        "prompt_matched": bool(
            collected and prompt_re.search(collected[-1]) is not None
        ),
    }
    print(json.dumps(result, indent=2))
    return 0 if matched_sentinel else 2


def _load_patterns(path: str) -> list[dict]:
    db = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    return db.get("patterns", [])


def _analyze(log_text: str, patterns: list[dict]) -> dict:
    compiled = [(p, re.compile(p["regex"], re.IGNORECASE)) for p in patterns]
    errors = []
    for lineno, line in enumerate(log_text.splitlines(), 1):
        for meta, rx in compiled:
            if rx.search(line):
                errors.append(
                    {
                        "line_number": lineno,
                        "line_content": line.strip(),
                        "name": meta["name"],
                        "severity": meta["severity"],
                        "category": meta["category"],
                        "description": meta["description"],
                    }
                )
    by_sev: dict[str, list] = {}
    by_cat: dict[str, list] = {}
    for e in errors:
        by_sev.setdefault(e["severity"], []).append(e)
        by_cat.setdefault(e["category"], []).append(e)
    return {
        "total_errors": len(errors),
        "errors": errors,
        "by_severity": by_sev,
        "by_category": by_cat,
        "has_critical": any(e["severity"] == "critical" for e in errors),
    }


def cmd_scan(args: argparse.Namespace) -> int:
    log_text = Path(args.logfile).read_text(encoding="utf-8", errors="ignore")
    patterns = _load_patterns(args.patterns)
    result = _analyze(log_text, patterns)
    result["logfile"] = args.logfile
    print(json.dumps(result, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="bbb-uart", description=__doc__)
    sub = p.add_subparsers(dest="subcommand", required=True)

    sp = sub.add_parser("capture-boot", help="Capture BBB boot log to file")
    sp.add_argument("--port", default=DEFAULT_PORT)
    sp.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    sp.add_argument("--out", required=True, help="Output log file")
    sp.add_argument("--timeout", type=float, default=60.0)
    sp.set_defaults(func=cmd_capture_boot)

    sp = sub.add_parser(
        "send", help="Send one command, read response via sentinel"
    )
    sp.add_argument("--port", default=DEFAULT_PORT)
    sp.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    sp.add_argument("--timeout", type=float, default=5.0)
    sp.add_argument("--prompt-regex", default=None)
    sp.add_argument("command", help="Shell command to run on BBB")
    sp.set_defaults(func=cmd_send)

    sp = sub.add_parser(
        "scan", help="Scan a log file with regex pattern DB (live or captured)"
    )
    sp.add_argument("logfile")
    sp.add_argument("--patterns", required=True, help="scripts/error-patterns.yaml path")
    sp.set_defaults(func=cmd_scan)

    sp = sub.add_parser(
        "replay", help="Alias of scan — replay captured log for CI / dry-run"
    )
    sp.add_argument("logfile")
    sp.add_argument("--patterns", required=True)
    sp.set_defaults(func=cmd_scan)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
