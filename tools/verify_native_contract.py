#!/usr/bin/env python3
"""Unified Contract & Parity Verifier for Hive-Lattice Native Godot Client.

Verifies:
1. Python engine campaign validation & legacy test discovery
2. Exported campaign data integrity and provenance hash
3. Headless Godot acceptance suite execution and parity vectors:
   - Initial Breakroom state
   - Inspect Wetberry
   - Talk Keith -> Obtain Evidence Bag
   - Talk Darla -> Fridge hint
   - Call HR -> Tammy conditional appearance
   - Use Evidence Bag on Wetberry -> Wetberry contained
   - NPC memory and relationships delta
   - Save / Load persistence
4. Offline assets and no runtime remote network dependencies
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


def find_godot_binary() -> Path | None:
    env_bin = os.environ.get("GODOT_BIN")
    if env_bin and Path(env_bin).exists():
        return Path(env_bin)

    # Check ~/.godot_bin
    home_bin = Path.home() / ".godot_bin"
    for candidate in [
        home_bin / "Godot_v4.3-stable_win64_console.exe",
        home_bin / "Godot_v4.3-stable_win64.exe",
        home_bin / "godot.exe",
        home_bin / "godot",
        home_bin / "Godot_v4.3-stable_linux.x86_64",
        Path("/usr/local/bin/godot"),
        Path("/usr/bin/godot"),
    ]:
        if candidate.exists() and candidate.is_file():
            return candidate

    which = shutil.which("godot") or shutil.which("godot4") or shutil.which("godot-headless")
    if which:
        return Path(which)
    return None


def run_command(cmd: list[str], desc: str, cwd: Path = Path("."), timeout: int = 180) -> bool:
    print(f"\n[GATE] {desc}...")
    print(f"       Running: {' '.join(str(c) for c in cmd)}")
    try:
        res = subprocess.run(cmd, cwd=cwd, timeout=timeout)
    except subprocess.TimeoutExpired:
        print(f"[FAIL] {desc} timed out after {timeout} seconds", file=sys.stderr)
        return False
    if res.returncode != 0:
        print(f"[FAIL] {desc} exited with code {res.returncode}", file=sys.stderr)
        return False
    print(f"[PASS] {desc}")
    return True


def main() -> int:
    print("============================================================")
    print("HIVE-LATTICE // FULL STACK CONTRACT VERIFICATION")
    print("============================================================")

    # 1. Content Lint & Python Validation
    if not run_command([sys.executable, "tools/content_lint.py"], "Content Lint"):
        return 1

    if not run_command([sys.executable, "-m", "tools.validate_campaign_module"], "Validate Campaign Module"):
        return 1

    if not run_command([sys.executable, "-m", "tools.validate_visual_assets"], "Validate Visual Assets"):
        return 1

    if not run_command([sys.executable, "-m", "hive_lattice.cli", "validate", "strawberry_omen"], "CLI Validate Strawberry Omen"):
        return 1

    # 2. Export campaign data for Godot
    if not run_command([sys.executable, "tools/export_godot_campaign.py"], "Deterministic Campaign Data Export"):
        return 1

    # 3. Find Godot and ensure project assets/classes are imported
    godot_bin = find_godot_binary()
    if godot_bin:
        run_command(
            [str(godot_bin), "--headless", "--path", "game_godot", "--import"],
            "Godot Project Class & Asset Import",
        )

    # 4. Python Unit Tests Discovery
    if not run_command([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test*.py"], "Python Unit Tests"):
        return 1

    # 5. Run headless acceptance test suite
    if not godot_bin:
        print("[ERROR] Godot binary not found in PATH or ~/.godot_bin!", file=sys.stderr)
        return 1

    if not run_command(
        [str(godot_bin), "--headless", "--path", "game_godot", "res://tests/AcceptanceRunner.tscn"],
        "Native Godot Headless Acceptance Suite",
    ):
        return 1

    print("\n============================================================")
    print("[ALL GATES PASSED] NATIVE CONTRACT & PYTHON PARITY VERIFIED")
    print("============================================================\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
