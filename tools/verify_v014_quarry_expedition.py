#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path.home() / ".luca_toolchain" / "Godot-4.7.2" / "Godot_v4.7.2-stable_win64_console.exe"
BAD_MARKERS = ("SCRIPT ERROR", "ERROR:", "Parse Error", "Invalid call", "Failed to load script")


def fail(message: str, output: str = "") -> None:
    if output:
        print(output)
    raise SystemExit(f"[FAIL] {message}")


def run(command: list[str], label: str, timeout: int = 240) -> str:
    result = subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    output = result.stdout + "\n" + result.stderr
    if result.returncode != 0:
        fail(f"{label}: rc={result.returncode}", output)
    print(f"[PASS] {label}")
    return output


def run_godot(script: str, label: str) -> str:
    output = run(
        [str(GODOT), "--headless", "--path", str(ROOT), "--script", script],
        label,
    )
    markers = [marker for marker in BAD_MARKERS if marker.lower() in output.lower()]
    if markers:
        fail(f"{label}: error markers={markers}", output)
    return output


def main() -> int:
    if not GODOT.exists():
        fail(f"locked Godot executable missing: {GODOT}")

    unit = run(
        [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"],
        "Python regression suite",
    )
    if "Ran 18 tests" not in unit or "OK" not in unit:
        fail("Python regression count/result changed", unit)

    contract = run([sys.executable, "tools/check_engineering_contract.py"], "engineering contract")
    if "[ALL ENGINEERING CONTRACT GATES PASSED]" not in contract:
        fail("engineering contract completion marker missing", contract)

    legacy = run([sys.executable, "tools/verify_v013_terrain_slice.py"], "v0.13 terrain regression")
    if "[ALL V0.13 TERRAIN SLICE GATES PASSED]" not in legacy:
        fail("v0.13 terrain completion marker missing", legacy)

    quarry = run_godot("res://tests/quarry_expedition_acceptance.gd", "Quarry Expedition runtime acceptance")
    if "[ALL ENG-007 QUARRY EXPEDITION GATES PASSED]" not in quarry:
        fail("Quarry Expedition completion marker missing", quarry)

    print("[ALL V0.14 QUARRY EXPEDITION GATES PASSED]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
