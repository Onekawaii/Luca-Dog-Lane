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


def run_command(cmd: list[str], desc: str, cwd: Path = Path("."), timeout: int = 300) -> bool:
    cmd_str = " ".join(str(c) for c in cmd)
    print(f"\n[GATE] {desc} (timeout: {timeout}s)...", flush=True)
    print(f"       Command: {cmd_str}", flush=True)
    
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    
    try:
        res = subprocess.run(cmd, cwd=cwd, env=env, timeout=timeout)
        sys.stdout.flush()
        sys.stderr.flush()
    except subprocess.TimeoutExpired as exc:
        print(f"\n[FAIL] TIMEOUT: '{desc}' exceeded timeout of {timeout} seconds!", file=sys.stderr, flush=True)
        print(f"       Blocking Command: {cmd_str}", file=sys.stderr, flush=True)
        sys.stderr.flush()
        return False
    except Exception as exc:
        print(f"\n[FAIL] ERROR: '{desc}' failed with exception: {exc}", file=sys.stderr, flush=True)
        print(f"       Command: {cmd_str}", file=sys.stderr, flush=True)
        sys.stderr.flush()
        return False

    if res.returncode != 0:
        print(f"[FAIL] '{desc}' exited with code {res.returncode}", file=sys.stderr, flush=True)
        print(f"       Failed Command: {cmd_str}", file=sys.stderr, flush=True)
        sys.stderr.flush()
        return False

    print(f"[PASS] {desc}", flush=True)
    return True


def main() -> int:
    print("============================================================", flush=True)
    print("HIVE-LATTICE // FULL STACK CONTRACT VERIFICATION", flush=True)
    print("============================================================", flush=True)

    # 1. Content Lint & Python Validation (Timeout: 300s each)
    if not run_command([sys.executable, "tools/content_lint.py"], "Content Lint", timeout=300):
        return 1

    if not run_command([sys.executable, "-m", "tools.validate_campaign_module"], "Validate Campaign Module", timeout=300):
        return 1

    if not run_command([sys.executable, "-m", "tools.validate_visual_assets"], "Validate Visual Assets", timeout=300):
        return 1

    if not run_command([sys.executable, "-m", "hive_lattice.cli", "validate", "strawberry_omen"], "CLI Validate Strawberry Omen", timeout=300):
        return 1

    # 2. Export campaign data for Godot (Timeout: 120s)
    if not run_command([sys.executable, "tools/export_godot_campaign.py"], "Deterministic Campaign Data Export", timeout=120):
        return 1

    # 3. Find Godot and ensure project assets/classes are imported (Timeout: 180s)
    godot_bin = find_godot_binary()
    if godot_bin:
        if not run_command(
            [str(godot_bin), "--headless", "--path", "game_godot", "--import"],
            "Godot Project Class & Asset Import",
            timeout=180,
        ):
            return 1
        if not run_command(
            [str(godot_bin), "--headless", "--path", "game_godot", "--script", "res://tests/ValidateScripts.gd"],
            "Godot GDScript Parse Gate",
            timeout=180,
        ):
            return 1

    # 4. Python Unit Tests Discovery (Timeout: 300s)
    if not run_command([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test*.py"], "Python Unit Tests", timeout=300):
        return 1

    # 5. Run headless acceptance test suite (Timeout: 300s)
    if not godot_bin:
        print("[ERROR] Godot binary not found in PATH or ~/.godot_bin!", file=sys.stderr, flush=True)
        return 1

    if not run_command(
        [str(godot_bin), "--headless", "--path", "game_godot", "res://tests/AcceptanceRunner.tscn"],
        "Native Godot Headless Acceptance Suite",
        timeout=300,
    ):
        return 1

    print("\n============================================================", flush=True)
    print("[ALL GATES PASSED] NATIVE CONTRACT & PYTHON PARITY VERIFIED", flush=True)
    print("============================================================\n", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
