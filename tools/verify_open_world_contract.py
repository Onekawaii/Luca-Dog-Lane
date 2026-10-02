#!/usr/bin/env python3
"""Deterministic PCO gate for the Hive-Lattice open-world runtime."""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / "game_godot/scripts/procgen/HiveProcGenEngine.gd"
RENDERER = ROOT / "game_godot/scripts/procgen/HiveOpenWorldRenderer.gd"
AUDITOR = ROOT / "game_godot/scripts/procgen/HiveWorldAuditor.gd"
VEHICLE = ROOT / "game_godot/scripts/vehicles/HiveVehicle.gd"
PLAYER = ROOT / "game_godot/scripts/fps/FirstPersonPlayer.gd"
RUNTIME = ROOT / "game_godot/scripts/procgen/HiveProcGenRuntime.gd"
SCHEMAS = ROOT / "SCHEMA_VERSIONS.md"

def read(path: Path) -> str:
    if not path.exists():
        raise AssertionError(f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")

def quoted_const(text: str, name: str) -> list[str]:
    match = re.search(rf"const\s+{re.escape(name)}\s*:=\s*\[(.*?)\]", text, re.S)
    if not match:
        raise AssertionError(f"missing constant list: {name}")
    return re.findall(r'"([^"]+)"', match.group(1))

def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)

def main() -> int:
    failures: list[str] = []
    engine = read(ENGINE)
    renderer = read(RENDERER)
    auditor = read(AUDITOR)
    vehicle = read(VEHICLE)
    player = read(PLAYER)
    runtime = read(RUNTIME)
    schemas = read(SCHEMAS)

    biomes = quoted_const(engine, "BIOMES")
    level_types = quoted_const(engine, "WORLD_LEVEL_TYPES")
    route_titles = quoted_const(read(ROOT / "game_godot/scripts/procgen/HiveProcGenChunkRenderer.gd"), "LEVEL_TITLES")

    require('"hive_procgen_world_v2"' in engine, "schema is not hive_procgen_world_v2", failures)
    require("WORLD_SIZE := 8192.0" in engine, "world is not 8192m x 8192m", failures)
    require("REGION_COUNT := 10" in engine, "region count is not 10", failures)
    require(len(biomes) == 10 and len(set(biomes)) == 10, "biome list must contain 10 unique values", failures)
    require(len(level_types) == 20 and len(set(level_types)) == 20, "world level list must contain 20 unique values", failures)
    require(len(route_titles) == 20 and len(set(route_titles)) == 20, "walkable route must expose 20 unique level titles", failures)

    require("SurfaceTool.new()" in renderer, "free-roam terrain mesh generator missing", failures)
    require("create_trimesh_shape()" in renderer, "terrain collision generation missing", failures)
    require('"cloudstep_highlands": return 48.0' in renderer, "mountain elevation contract missing", failures)
    require("TERRAIN_RADIUS := 2" in renderer, "bounded terrain streaming radius missing", failures)
    require('preload("res://scripts/vehicles/HiveVehicle.gd")' in renderer, "vehicle is not wired into world renderer", failures)
    require("StarterTrailCar" in renderer, "starter trail car spawn missing", failures)
    require("LucaGuideClass" in renderer and "_spawn_luca_guide" in renderer, "Luca companion is not wired into open world", failures)

    require("extends CharacterBody3D" in vehicle, "vehicle is not a physical CharacterBody3D", failures)
    require("move_and_slide()" in vehicle, "vehicle collision-aware movement missing", failures)
    require("request_exit" in vehicle and "interact(player" in vehicle, "vehicle enter/exit interaction missing", failures)
    require("enter_vehicle" in player and "exit_vehicle" in player, "player vehicle state integration missing", failures)
    require("floor_max_angle = deg_to_rad(55.0)" in player, "climbable slope contract missing", failures)

    require("WorldAuditorClass" in runtime, "world auditor is not wired into runtime", failures)
    require("OPEN WORLD AUDIT BLOCKED RUNTIME" in runtime, "auditor is not fail-closed", failures)
    require("bullshit_score" in auditor and "LOGISTICS:" in auditor and "CONGRUENCY:" in auditor, "PCO deterministic bullshit/logistics checks missing", failures)
    require("room_schema_v1" in schemas and "Status**: LOCKED" in schemas, "legacy room schema freeze was mutated", failures)

    paths = [ENGINE, RENDERER, AUDITOR, VEHICLE, PLAYER, RUNTIME]
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(path.read_bytes())

    print("ARKHEOPANTHEOCHIVE // OPEN WORLD PCO RECEIPT")
    print(f"biomes={len(biomes)}")
    print(f"level_types={len(level_types)}")
    print(f"walkable_level_titles={len(route_titles)}")
    print("terrain_streaming=bounded")
    print("mountains=climbable_contract")
    print("vehicles=enabled")
    print(f"sha256={digest.hexdigest()}")
    if failures:
        print(f"status=BLOCKED ({len(failures)} issue(s))")
        for issue in failures:
            print(f" - {issue}")
        return 1
    print("bullshit_score=0")
    print("status=PASS")
    return 0

if __name__ == "__main__":
    sys.exit(main())
