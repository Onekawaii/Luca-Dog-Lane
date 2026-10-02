#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads((ROOT / "tools/luca/architecture_manifest.json").read_text(encoding="utf-8"))
assertions = 0
failures: list[str] = []
suites_run = 0

def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def check(condition: bool, label: str) -> None:
    global assertions
    assertions += 1
    if not condition:
        failures.append(label)

def suite(name: str, fn) -> None:
    global suites_run
    suites_run += 1
    before = len(failures)
    fn()
    print(f"[{'PASS' if len(failures) == before else 'FAIL'}] {name}")

def identity() -> None:
    project = text("game_godot/project.godot")
    export = text("game_godot/export_presets.cfg")
    check('config/name="Luca Dog World"' in project, "identity: product name")
    check('config/version="0.11.0"' in project, "identity: product version")
    check('package/unique_name="com.onekawaii.lucadogworld"' in export, "identity: android package")

def bootstrap() -> None:
    scene = text("game_godot/scenes/bootstrap/FirstPersonBootstrap.tscn")
    check("LucaWorldBootstrap.gd" in scene, "bootstrap: root bootstrap")
    check("LucaWorldRoot.gd" in scene, "bootstrap: world root resource")
    check('name="LucaWorldRoot"' in scene, "bootstrap: world root node")

def generation() -> None:
    source = text("game_godot/scripts/luca/LucaWorldGenerator.gd")
    check("class_name LucaWorldGenerator" in source, "generation: class")
    check(all(name in source for name in MANIFEST["world"]["generation_passes"]), "generation: eight passes")
    check('chunk["descriptor_hash"]' in source and "sha256_text" in source, "generation: descriptor hash")

def chunks() -> None:
    cfg = MANIFEST["world"]
    db = text("game_godot/scripts/luca/LucaChunkDatabase.gd")
    check(cfg["chunk_size_m"] == 128, "chunks: 128m")
    check(cfg["subcell_size_m"] == 32, "chunks: 32m subcells")
    check("class_name LucaChunkDatabase" in db and "func get_chunk" in db, "chunks: database")

def streaming() -> None:
    cfg = MANIFEST["streaming"]
    check(cfg["preload_grid"] == 7, "streaming: 7x7 preload")
    check(cfg["render_grid"] == 5, "streaming: 5x5 render")
    check(cfg["physics_grid"] == 3, "streaming: 3x3 physics")
    check(cfg["hysteresis_cells"] == 2, "streaming: hysteresis")

def persistence() -> None:
    cfg = MANIFEST["persistence"]
    check(cfg["immutable_chunk_descriptions"] is True, "persistence: immutable descriptors")
    check(cfg["delta_only"] is True, "persistence: delta only")
    check(cfg["delta_categories"] == ["removed", "moved", "collected", "spawned"], "persistence: categories")

def companion() -> None:
    guide = text("game_godot/scripts/actors/LucaGuide.gd")
    check(MANIFEST["companion"]["states"] == ["IDLE", "FOLLOW", "INVESTIGATE", "WAIT", "RECOVER", "REST"], "companion: six states")
    check("BrainClass" in guide and "choose_state" in guide, "companion: guide integration")

def tools() -> None:
    modes = MANIFEST["tools"]["modes"]
    check(modes == ["object_tether", "builder", "remover", "inspector"], "tools: modes")
    check((ROOT / "game_godot/scripts/luca/LucaObjectTether.gd").is_file(), "tools: tether")

def mods() -> None:
    cfg = MANIFEST["mods"]
    manager = text("game_godot/scripts/luca/LucaModManager.gd")
    check(cfg["denied_permissions"] == ["filesystem", "shell", "network", "native_code", "process"], "mods: denied permissions")
    check(".lucamod" in manager and "ZIPReader" in manager and "_unsafe_path" in manager, "mods: archive sandbox")

def runtime() -> None:
    root = text("game_godot/scripts/luca/LucaWorldRoot.gd")
    check("LucaWorldStreamer" in root and "LucaChunkDatabase" in root, "runtime: standalone services")
    check('world_state["luca_world"]' in root, "runtime: save integration")

def release() -> None:
    check(MANIFEST["world"]["biome_count"] == 10, "release: ten biomes")
    check(MANIFEST["world"]["minimum_location_types"] == 20, "release: twenty location types")

for name, fn in [
    ("identity", identity), ("bootstrap", bootstrap), ("generation", generation),
    ("chunks", chunks), ("streaming", streaming), ("persistence", persistence),
    ("companion", companion), ("tools", tools), ("mods", mods),
    ("runtime", runtime), ("release", release),
]:
    suite(name, fn)

if assertions != 29:
    failures.append(f"bench definition drift: expected 29 assertions, got {assertions}")
if failures:
    print("\nLUCABENCH FAIL")
    for failure in failures:
        print(" -", failure)
    sys.exit(1)
print(f"\nLUCABENCH PASS // {suites_run}/11 suites, {assertions} assertions")
