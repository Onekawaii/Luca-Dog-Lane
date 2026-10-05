#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path.home() / ".luca_toolchain" / "Godot-4.7.2" / "Godot_v4.7.2-stable_win64_console.exe"

FORBIDDEN = (
    "hive_lattice",
    "strawberry",
    "wetberry",
    "breakroom",
    "firstpersonbootstrap",
    "roommanager",
    "gameruntime",
    "eventbus",
    "atmospheredirector",
)

TEXT_SUFFIXES = {".gd", ".tscn", ".godot", ".cfg", ".md", ".py", ".ps1", ".json", ".yml", ".yaml", ".svg"}

def fail(message: str) -> None:
    print(f"[FAIL] {message}")
    raise SystemExit(1)

def check_clean_tree() -> None:
    offenders: list[str] = []
    runtime_paths = list((ROOT / "scripts").rglob("*.gd"))
    runtime_paths += list((ROOT / "scenes").rglob("*.tscn"))
    runtime_paths += [
        ROOT / "project.godot",
        ROOT / "export_presets.cfg",
        ROOT / "BUILD_RELEASE.ps1",
        ROOT / "README.md",
    ]
    for path in runtime_paths:
        if not path.exists():
            fail(f"expected runtime file missing: {path.relative_to(ROOT)}")
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        for token in FORBIDDEN:
            if token in text:
                offenders.append(f"{path.relative_to(ROOT)} -> {token}")
    if offenders:
        fail("old-runtime contamination:\n  " + "\n  ".join(offenders))
    print("[PASS] shipped runtime contains no inherited runtime identifiers")

def check_project_contract() -> None:
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'run/main_scene="res://scenes/Main.tscn"' not in project:
        fail("main scene is not the clean sandbox scene")
    if "[autoload]" in project:
        fail("autoload section reintroduced")
    if 'config/version="0.15.0-kimi.1"' not in project:
        fail("unexpected product version")
    print("[PASS] project boots directly into standalone sandbox")

def check_boundary_contract() -> None:
    world = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
    player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
    required = ("WorldGround", "NorthBoundary", "SouthBoundary", "WestBoundary", "EastBoundary")
    missing = [name for name in required if name not in world]
    if missing:
        fail("boundary contract missing: " + ", ".join(missing))
    if "GROUND_THICKNESS" not in world or "_recover_if_outside" not in player:
        fail("ground/fall recovery contract missing")
    print("[PASS] continuous ground + four hard boundaries + recovery present")

def check_sandbox_contract() -> None:
    hud = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
    player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
    game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
    for token in ("SPAWN MENU", "NOCLIP", "TOOL"):
        if token not in hud:
            fail(f"HUD missing {token}")
    for token in ("GRAB", "REMOVE", "DUPLICATE", "INSPECT"):
        if token not in player:
            fail(f"tool mode missing {token}")
    for token in ("spawn_prop", "_spawn_npc", "_spawn_buggy"):
        if token not in game:
            fail(f"sandbox spawner missing {token}")
    print("[PASS] sandbox spawn/tools/noclip/NPC/vehicle contract present")

def run_godot() -> None:
    if not GODOT.exists():
        fail(f"Godot binary missing: {GODOT}")
    commands = [
        [str(GODOT), "--headless", "--path", str(ROOT), "--editor", "--quit"],
        [str(GODOT), "--headless", "--path", str(ROOT), "--quit-after", "120"],
    ]
    for index, command in enumerate(commands, start=1):
        result = subprocess.run(command, text=True, capture_output=True, timeout=90)
        combined = result.stdout + "\n" + result.stderr
        bad = ("SCRIPT ERROR", "Parse Error", "Failed to load script", "Invalid call", "Nonexistent function")
        found = [needle for needle in bad if needle.lower() in combined.lower()]
        if result.returncode != 0 or found:
            print(combined)
            fail(f"Godot gate {index} failed: rc={result.returncode}, markers={found}")
        if index == 2 and "LUCA_SANDBOX_READY" not in combined:
            print(combined)
            fail("runtime did not reach sandbox-ready marker")
    print("[PASS] Godot parse and runtime smoke gates")

def run_playability() -> None:
    command = [
        str(GODOT),
        "--headless",
        "--path",
        str(ROOT),
        "--script",
        "tests/runtime_playability.gd",
    ]
    result = subprocess.run(command, text=True, capture_output=True, timeout=90)
    combined = result.stdout + "\n" + result.stderr
    bad = (
        "SCRIPT ERROR",
        "Parse Error",
        "Failed to load script",
        "Invalid call",
        "Nonexistent function",
        "Can't add child",
    )
    found = [needle for needle in bad if needle.lower() in combined.lower()]
    if result.returncode != 0 or found or "[ALL PLAYABILITY GATES PASSED]" not in combined:
        print(combined)
        fail(f"playability regression gate failed: rc={result.returncode}, markers={found}")
    print("[PASS] live playability regression gate")


def main() -> int:
    check_clean_tree()
    check_project_contract()
    check_boundary_contract()
    check_sandbox_contract()
    run_godot()
    run_playability()
    print("[ALL GATES PASSED] LUCA CLEAN-ROOM SANDBOX VERIFIED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
