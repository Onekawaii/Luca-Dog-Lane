#!/usr/bin/env python3
from __future__ import annotations

import json
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
    if 'config/version="0.2.0"' not in project:
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
    game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
    tools_doc = json.loads((ROOT / "data" / "tools_v016.json").read_text(encoding="utf-8"))
    actions = {spec["action"] for spec in tools_doc["tools"].values()}
    for token in ("DEVELOPER SPAWN", "NOCLIP", "TOOL", "WORLD MAP & TRANSITIONS", "open_encounter", "get_map_options", "request_map"):
        if token not in hud:
            fail(f"HUD missing {token}")
    for action in ("grab", "remove", "duplicate", "inspect", "strike", "mine", "place", "craft"):
        if action not in actions:
            fail(f"tool action missing {action}")
    if "act" in actions or "mercy" in actions:
        fail("contextual encounter verbs leaked back into tool catalog")
    for token in ("spawn_prop", "_spawn_npc", "_spawn_buggy", "ContentRegistry.new()"):
        if token not in game:
            fail(f"sandbox/content contract missing {token}")
    print("[PASS] catalog-driven sandbox/tools/maps/NPC/vehicle contract present")

def run_godot() -> None:
    if not GODOT.exists():
        fail(f"Godot binary missing: {GODOT}")
    command = [str(GODOT), "--headless", "--path", str(ROOT), "--editor", "--quit"]
    result = subprocess.run(command, text=True, capture_output=True, timeout=90)
    combined = result.stdout + "\n" + result.stderr
    bad = ("SCRIPT ERROR", "Parse Error", "Failed to load script", "Invalid call", "Nonexistent function")
    found = [needle for needle in bad if needle.lower() in combined.lower()]
    if result.returncode != 0 or found:
        print(combined)
        fail(f"Godot import gate failed: rc={result.returncode}, markers={found}")
    print("[PASS] Godot import/parse gate")


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


def run_v016_systems() -> None:
    command = [
        str(GODOT),
        "--headless",
        "--path",
        str(ROOT),
        "--script",
        "tests/v016_systems_acceptance.gd",
    ]
    result = subprocess.run(command, text=True, capture_output=True, timeout=150)
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
    if result.returncode != 0 or found or "[ALL V016 SYSTEM GATES PASSED]" not in combined:
        print(combined)
        fail(f"v0.16 systems gate failed: rc={result.returncode}, markers={found}")
    print("[PASS] v0.16 vehicle/companion/damage/content/maps gate")


def run_spiral_field() -> None:
    command = [
        str(GODOT),
        "--headless",
        "--path",
        str(ROOT),
        "--script",
        "tests/spiral_field_acceptance.gd",
    ]
    result = subprocess.run(command, text=True, capture_output=True, timeout=150)
    combined = result.stdout + "\n" + result.stderr
    bad = ("SCRIPT ERROR", "Parse Error", "Failed to load script", "Invalid call", "Nonexistent function", "Can't add child")
    found = [needle for needle in bad if needle.lower() in combined.lower()]
    if result.returncode != 0 or found or "[ALL SPIRAL FIELD V02 GATES PASSED]" not in combined:
        print(combined)
        fail(f"Spiral Field gate failed: rc={result.returncode}, markers={found}")
    print("[PASS] Spiral Field contextual encounters + world-state + persistence gate")


def main() -> int:
    check_clean_tree()
    check_project_contract()
    check_boundary_contract()
    check_sandbox_contract()
    run_godot()
    run_playability()
    run_v016_systems()
    run_spiral_field()
    print("[ALL GATES PASSED] SPIRAL FIELD SUBSTRATE VERIFIED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
