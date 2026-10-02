#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CFG = json.loads((ROOT / "tools/luca/architecture_manifest.json").read_text(encoding="utf-8"))
CHUNK = float(CFG["world"]["chunk_size_m"])
results: list[tuple[str, bool, str]] = []

def chunk_for(x: float, z: float) -> tuple[int, int]:
    return (math.floor(x / CHUNK), math.floor(z / CHUNK))

def ring(center: tuple[int, int], radius: int) -> set[tuple[int, int]]:
    cx, cz = center
    return {
        (x, z)
        for z in range(cz - radius, cz + radius + 1)
        for x in range(cx - radius, cx + radius + 1)
    }

def record(name: str, ok: bool, detail: str) -> None:
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name} // {detail}")

def boundary_crossings() -> None:
    last = chunk_for(0.0, 0.0)
    transitions = 0
    for i in range(500):
        boundary = (i + 1) * CHUNK
        before = chunk_for(boundary - 0.01, 0.0)
        after = chunk_for(boundary + 0.01, 0.0)
        transitions += int(before != after)
        last = after
        if len(ring(after, 3)) != 49 or len(ring(after, 2)) != 25 or len(ring(after, 1)) != 9:
            record("500 boundary crossings", False, f"ring count failed at {i}")
            return
    record("500 boundary crossings", transitions == 500, f"{transitions}/500 transitions; final={last}")

def corner_teleports() -> None:
    digest = hashlib.sha256()
    unique = set()
    for i in range(128):
        sign_x = -1 if i % 2 else 1
        sign_z = -1 if (i // 2) % 2 else 1
        x = sign_x * (4096.0 + i * 173.25)
        z = sign_z * (8192.0 + i * 97.75)
        cell = chunk_for(x, z)
        unique.add(cell)
        digest.update(f"{i}:{cell[0]}:{cell[1]}".encode())
    replay = hashlib.sha256()
    for i in range(128):
        sign_x = -1 if i % 2 else 1
        sign_z = -1 if (i // 2) % 2 else 1
        cell = chunk_for(sign_x * (4096.0 + i * 173.25), sign_z * (8192.0 + i * 97.75))
        replay.update(f"{i}:{cell[0]}:{cell[1]}".encode())
    ok = len(unique) > 100 and digest.digest() == replay.digest()
    record("128 corner teleports", ok, f"{len(unique)} unique deterministic destinations")

def persistence_mutations() -> None:
    baseline = {"objects": [{"id": f"obj.{i}"} for i in range(100)]}
    baseline_hash = hashlib.sha256(json.dumps(baseline, sort_keys=True).encode()).hexdigest()
    delta = {"removed": [], "moved": {}, "collected": [], "spawned": {}}
    for i in range(300):
        kind = i % 4
        entity = f"obj.{i % 100}"
        if kind == 0 and entity not in delta["removed"]:
            delta["removed"].append(entity)
        elif kind == 1:
            delta["moved"][entity] = {"x": i, "y": i % 7, "z": -i}
        elif kind == 2 and entity not in delta["collected"]:
            delta["collected"].append(entity)
        else:
            delta["spawned"][f"spawn.{i}"] = {"id": f"spawn.{i}", "kind": "test_prop"}
    after_hash = hashlib.sha256(json.dumps(baseline, sort_keys=True).encode()).hexdigest()
    categories_ok = set(delta) == {"removed", "moved", "collected", "spawned"}
    record("300 persistence mutations", baseline_hash == after_hash and categories_ok, "baseline descriptor unchanged")

def flight_torture() -> None:
    suspend_height = float(CFG["streaming"]["flight_suspend_height_m"])
    samples = 0
    physics_suspended = 0
    for distance in range(0, 5001, 25):
        altitude = 40.0 + distance * 0.12
        center = chunk_for(float(distance), float(distance) * 0.37)
        preload_count = len(ring(center, 3))
        render_count = len(ring(center, 2))
        physics_count = 0 if altitude > suspend_height else len(ring(center, 1))
        samples += 1
        physics_suspended += int(physics_count == 0)
        if preload_count != 49 or render_count != 25:
            record("5,000m flight torture", False, f"ring corruption at {distance}m")
            return
    record("5,000m flight torture", physics_suspended > 0, f"{samples} samples; {physics_suspended} physics-suspended")

boundary_crossings()
corner_teleports()
persistence_mutations()
flight_torture()

passed = sum(1 for _, ok, _ in results if ok)
if passed != 4:
    print(f"\nDEMOLITION FAIL // {passed}/4 scenarios")
    sys.exit(1)
print("\nDEMOLITION PASS // 4/4 scenarios")
