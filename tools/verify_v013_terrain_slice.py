#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path.home() / ".luca_toolchain" / "Godot-4.7.2" / "Godot_v4.7.2-stable_win64_console.exe"
BAD_MARKERS = ("SCRIPT ERROR", "ERROR:", "Parse Error", "Invalid call", "Failed to load script")


def fail(message: str, output: str = "") -> None:
    if output:
        print(output)
    raise SystemExit(f"[FAIL] {message}")


def run_godot(args: list[str], label: str, env: dict[str, str] | None = None) -> str:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    result = subprocess.run(
        [str(GODOT), "--headless", "--path", str(ROOT), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=180,
        env=merged_env,
    )
    output = result.stdout + "\n" + result.stderr
    markers = [marker for marker in BAD_MARKERS if marker.lower() in output.lower()]
    if result.returncode != 0 or markers:
        fail(f"{label}: rc={result.returncode}, markers={markers}", output)
    print(f"[PASS] {label}")
    return output


def main() -> int:
    if not GODOT.exists():
        fail(f"locked Godot 4.7.2 executable missing: {GODOT}")

    terrain = run_godot(
        ["--script", "tests/terrain_slice_acceptance.gd"],
        "terrain generation/edit/collision/persistence acceptance",
    )
    if "[ALL ENG-003 TERRAIN SLICE GATES PASSED]" not in terrain:
        fail("terrain acceptance completion marker missing", terrain)

    player = run_godot(
        ["--script", "tests/terrain_player_flow.gd"],
        "real Player -> Game -> Terrain tool flow",
        {"LUCA_V013_SLICE_SAVE_PATH": "user://eng003_player_flow.json"},
    )
    if "[ALL ENG-003 PLAYER FLOW GATES PASSED]" not in player:
        fail("player-flow completion marker missing", player)

    climb = run_godot(
        ["--script", "tests/terrain_climb_acceptance.gd"],
        "real player collision/jump mountain ascent",
        {"LUCA_V013_SLICE_SAVE_PATH": "user://eng003_climb_acceptance.json"},
    )
    if "[ALL ENG-003 CLIMB GATES PASSED]" not in climb:
        fail("climb acceptance completion marker missing", climb)

    runtime = run_godot(["--quit-after", "120"], "integrated game boot")
    for marker in ("V013_TERRAIN_SLICE_READY", "LUCA_SANDBOX_READY"):
        if marker not in runtime:
            fail(f"integrated runtime marker missing: {marker}", runtime)

    print("[ALL V0.13 TERRAIN SLICE GATES PASSED]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
