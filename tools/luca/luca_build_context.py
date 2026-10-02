#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools" / "luca" / "architecture_manifest.json"
REQUIRED = [
    "game_godot/scripts/luca/LucaWorldConfig.gd",
    "game_godot/scripts/luca/LucaWorldGenerator.gd",
    "game_godot/scripts/luca/LucaChunkDatabase.gd",
    "game_godot/scripts/luca/LucaWorldStreamer.gd",
    "game_godot/scripts/luca/LucaChunkRenderer.gd",
    "game_godot/scripts/luca/LucaWorldPersistence.gd",
    "game_godot/scripts/luca/LucaCompanionBrain.gd",
    "game_godot/scripts/luca/LucaWorldRoot.gd",
    "game_godot/scripts/luca/LucaModManager.gd",
    "game_godot/scripts/luca/LucaModVM.gd",
]
PROTECTED = [
    "game_godot/scripts/fps/TouchLookZone.gd",
    "game_godot/scripts/ui/VirtualStick.gd",
    "game_godot/scripts/fps/FirstPersonPlayer.gd",
]

def run(*args: str) -> str:
    return subprocess.check_output(
        args, cwd=ROOT, text=True, encoding="utf-8", errors="replace"
    ).strip()

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def main() -> int:
    missing = [p for p in REQUIRED if not (ROOT / p).is_file()]
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    context = {
        "schema": "luca_build_context_v1",
        "branch": run("git", "branch", "--show-current"),
        "head": run("git", "rev-parse", "HEAD"),
        "status": run("git", "status", "--short").splitlines(),
        "manifest_sha256": sha256(MANIFEST),
        "generator_version": manifest["world"]["generator_version"],
        "required_files": {
            p: sha256(ROOT / p) for p in REQUIRED if (ROOT / p).is_file()
        },
        "protected_files": {
            p: sha256(ROOT / p) for p in PROTECTED if (ROOT / p).is_file()
        },
        "missing_required": missing,
    }
    context["valid"] = not missing
    print(json.dumps(context, indent=2, sort_keys=True))
    return 0 if context["valid"] else 1

if __name__ == "__main__":
    sys.exit(main())
