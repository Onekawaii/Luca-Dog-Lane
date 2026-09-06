"""Persistent save/load system for CampaignModule (ModuleState)."""

from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from engine.module_runtime import CampaignModule, ModuleState

SAVE_VERSION = 3
DEFAULT_SLOT = "default"


class ModuleSaveSystem:
    """Save and restore ModuleState to/from JSON files.

    Save v2 added room memory, NPC memory, conditions and deterministic system
    state. Save v3 adds spatial world state and fictional actor dynamics. v1/v2
    files remain loadable with sensible empty/default values.
    """

    def __init__(self, module: CampaignModule, save_dir: Optional[str | Path] = None):
        self.module = module
        self.save_dir = Path(save_dir) if save_dir is not None else Path("saves") / "strawberry_omen"
        self.save_dir.mkdir(parents=True, exist_ok=True)

    def _save_path(self, slot: str = DEFAULT_SLOT) -> Path:
        return self.save_dir / f"{slot}_save.json"

    def save_game(self, state: ModuleState, slot: str = DEFAULT_SLOT) -> str:
        save_data = {
            "save_version": SAVE_VERSION,
            "module_id": state.campaign_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "current_scene": state.current_scene,
            "current_location": state.current_location,
            "flags": dict(state.flags),
            "stats": dict(state.stats),
            "inventory": list(state.inventory),
            "log": list(state.log),
            "room_state": dict(state.room_state),
            "npc_memory": dict(state.npc_memory),
            "conditions": dict(state.conditions),
            "event_history": list(state.event_history),
            "turn_count": int(state.turn_count),
            "rng_seed": int(state.rng_seed),
            "last_outcome": dict(state.last_outcome),
            "world_state": dict(state.world_state),
            "actor_dynamics": {k: dict(v) for k, v in state.actor_dynamics.items()},
        }

        target = self._save_path(slot)
        target.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(dir=str(target.parent), suffix=".tmp", prefix="save_")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(save_data, f, indent=2, ensure_ascii=False)
                f.write("\n")
            os.replace(tmp_path, str(target))
        except BaseException:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise
        return f"Game saved to {target.name}."

    def load_game(self, slot: str = DEFAULT_SLOT) -> Optional[ModuleState]:
        path = self._save_path(slot)
        if not path.exists():
            print(f"No save file found: {path.name}. Start a new game or use 'saves'.")
            return None
        try:
            with path.open("r", encoding="utf-8") as f:
                save_data = json.load(f)
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            print(f"Corrupt save file ({path.name}): {exc}")
            return None

        required_keys = {"save_version", "module_id", "current_scene", "current_location"}
        missing = required_keys - save_data.keys()
        if missing:
            print(f"Corrupt save file ({path.name}): missing fields {missing}")
            return None

        return ModuleState(
            campaign_id=save_data["module_id"],
            current_scene=save_data["current_scene"],
            current_location=save_data["current_location"],
            flags=dict(save_data.get("flags", {})),
            stats=dict(save_data.get("stats", {})),
            inventory=list(save_data.get("inventory", [])),
            log=list(save_data.get("log", [])),
            room_state=dict(save_data.get("room_state", {})),
            npc_memory={k: int(v) for k, v in save_data.get("npc_memory", {}).items()},
            conditions={k: int(v) for k, v in save_data.get("conditions", {}).items()},
            event_history=list(save_data.get("event_history", [])),
            turn_count=int(save_data.get("turn_count", 0)),
            rng_seed=int(save_data.get("rng_seed", self.module.campaign.get("rng_seed", 6060))),
            last_outcome=dict(save_data.get("last_outcome", {})),
            world_state=dict(save_data.get("world_state", {})),
            actor_dynamics={k: dict(v) for k, v in save_data.get("actor_dynamics", {}).items()},
        )

    def list_saves(self) -> List[Dict[str, Any]]:
        saves: List[Dict[str, Any]] = []
        if not self.save_dir.exists():
            return saves
        for p in sorted(self.save_dir.glob("*_save.json")):
            try:
                with p.open("r", encoding="utf-8") as f:
                    data = json.load(f)
                saves.append({
                    "slot": p.stem.replace("_save", ""),
                    "file": p.name,
                    "module_id": data.get("module_id", "unknown"),
                    "timestamp": data.get("timestamp", "unknown"),
                    "current_scene": data.get("current_scene", "unknown"),
                    "save_version": data.get("save_version", 1),
                })
            except (json.JSONDecodeError, OSError):
                saves.append({"slot": p.stem, "file": p.name, "module_id": "CORRUPT"})
        return saves

    def delete_save(self, slot: str = DEFAULT_SLOT) -> str:
        path = self._save_path(slot)
        if not path.exists():
            return f"No save file to delete: {path.name}."
        path.unlink()
        return f"Save file deleted: {path.name}."
