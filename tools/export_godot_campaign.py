#!/usr/bin/env python3
"""Deterministic Campaign Data Exporter for Godot 4 Native Client.

Exports canonical campaign data from campaigns/strawberry_omen/game/ into
game_godot/data/strawberry_omen/ preserving all source IDs, references, and
provenance hashes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def export_campaign(campaign_dir: Path, output_dir: Path) -> Dict[str, Any]:
    game_dir = campaign_dir / "game"
    if not game_dir.exists():
        raise FileNotFoundError(f"Source game directory not found: {game_dir}")

    output_dir.mkdir(parents=True, exist_ok=True)

    source_files = [
        "campaign.json",
        "world.json",
        "character_identities.json",
        "interactions.json",
        "items.json",
        "conditions.json",
        "quests.json",
        "npcs.json",
        "encounters.json",
        "random_tables.json",
        "locations.json",
    ]

    manifest_entries: Dict[str, Dict[str, Any]] = {}
    combined_hasher = hashlib.sha256()

    for filename in source_files:
        src_path = game_dir / filename
        if not src_path.exists():
            print(f"Warning: {filename} does not exist in {game_dir}")
            continue

        file_hash = sha256_file(src_path)
        combined_hasher.update(file_hash.encode("utf-8"))

        with src_path.open("r", encoding="utf-8") as f:
            data = json.load(f)

        dest_path = output_dir / filename
        with dest_path.open("w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")

        manifest_entries[filename] = {
            "sha256": file_hash,
            "bytes": src_path.stat().st_size,
        }

    overall_hash = combined_hasher.hexdigest()

    # Load campaign root manifest if available
    campaign_manifest_path = campaign_dir / "campaign.manifest.json"
    campaign_manifest = {}
    if campaign_manifest_path.exists():
        with campaign_manifest_path.open("r", encoding="utf-8") as f:
            campaign_manifest = json.load(f)

    existing_exported_at = None
    existing_manifest_path = output_dir / "manifest.json"
    if existing_manifest_path.exists():
        try:
            with existing_manifest_path.open("r", encoding="utf-8") as f:
                existing_manifest = json.load(f)
            if existing_manifest.get("combined_sha256") == overall_hash:
                existing_exported_at = existing_manifest.get("exported_at")
        except (OSError, json.JSONDecodeError):
            existing_exported_at = None

    manifest = {
        "schema": "godot_campaign_manifest_v1",
        "campaign_id": campaign_manifest.get("id", "campaign.strawberry_omen"),
        "campaign_title": campaign_manifest.get("title", "The Strawberry Omen"),
        "exported_at": existing_exported_at or datetime.now(timezone.utc).isoformat(),
        "combined_sha256": overall_hash,
        "entry_location": "location.breakroom",
        "entry_scene": "scene.act1.first_sighting",
        "files": manifest_entries,
    }

    manifest_path = output_dir / "manifest.json"
    with manifest_path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"[OK] Exported {len(manifest_entries)} campaign data files to {output_dir}")
    print(f"     Combined SHA256: {overall_hash}")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Export campaign data for Godot client.")
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("campaigns/strawberry_omen"),
        help="Source campaign folder",
    )
    parser.add_argument(
        "--dest",
        type=Path,
        default=Path("game_godot/data/strawberry_omen"),
        help="Target data folder inside game_godot",
    )
    args = parser.parse_args()

    try:
        export_campaign(args.source, args.dest)
        return 0
    except Exception as exc:
        print(f"[ERROR] Campaign export failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
