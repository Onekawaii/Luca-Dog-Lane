#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "engineering" / "TOOLCHAIN_LOCK.json").read_text(encoding="utf-8"))

DEFAULT_GODOT = (
    Path.home()
    / ".luca_toolchain"
    / "Godot-4.7.2"
    / "Godot_v4.7.2-stable_win64_console.exe"
)
GODOT = Path(os.environ.get("LUCA_V013_GODOT", str(DEFAULT_GODOT)))

BAD_MARKERS = (
    "SCRIPT ERROR",
    "Parse Error",
    "Failed to load script",
    "Invalid call",
    "Nonexistent function",
    "Cannot get class",
    "GDExtension library not found",
)


def fail(message: str) -> None:
    print(f"[FAIL] {message}")
    raise SystemExit(1)


def run(command: list[str], label: str, timeout: int = 120) -> str:
    result = subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    combined = result.stdout + "\n" + result.stderr
    found = [marker for marker in BAD_MARKERS if marker.lower() in combined.lower()]
    if result.returncode != 0 or found:
        print(combined)
        fail(f"{label}: rc={result.returncode}, bad_markers={found}")
    print(f"[PASS] {label}")
    return combined


def verify_exact_engine() -> None:
    if not GODOT.exists():
        fail(f"locked Godot binary missing: {GODOT}")
    version = run([str(GODOT), "--version"], "locked Godot executable").strip()
    if not version.startswith("4.7.2"):
        fail(f"expected Godot 4.7.2, got {version!r}")
    if LOCK["engine"]["version"] != "4.7.2-stable":
        fail("toolchain lock changed unexpectedly")
    print(f"[PASS] engine version = {version}")


def verify_python_contracts() -> None:
    run(
        [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"],
        "Python contract suite",
    )


def verify_project_compatibility() -> None:
    run(
        [str(GODOT), "--headless", "--path", str(ROOT), "--editor", "--quit"],
        "Godot 4.7.2 import/parse",
        180,
    )
    runtime = run(
        [str(GODOT), "--headless", "--path", str(ROOT), "--quit-after", "120"],
        "Godot 4.7.2 runtime smoke",
        180,
    )
    if "LUCA_SANDBOX_READY" not in runtime:
        fail("runtime never reached LUCA_SANDBOX_READY")
    print("[PASS] runtime reached LUCA_SANDBOX_READY")

    playability = run(
        [
            str(GODOT),
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            "tests/runtime_playability.gd",
        ],
        "Godot 4.7.2 live playability regression",
        180,
    )
    if "[ALL PLAYABILITY GATES PASSED]" not in playability:
        fail("playability harness did not report all gates passed")
    print("[PASS] live playability behavior preserved under 4.7.2")


def main() -> int:
    verify_exact_engine()
    verify_python_contracts()
    verify_project_compatibility()
    print("[ALL V0.13 MIGRATION BASELINE GATES PASSED]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
