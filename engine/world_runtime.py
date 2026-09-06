"""Campaign-local spatial runtime for the v0.7 World in Motion slice.

This intentionally keeps movement/presentation separate from frozen Bard schemas.
It consumes campaign-local ``world.json`` and ``character_identities.json``.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from engine.actor_dynamics import ActorDynamicsEngine
from engine.world_contracts import GameAction, GameEvent, PresentationSnapshot


class WorldRuntime:
    SCHEMA = "hive_world_snapshot_v1"

    def __init__(self, module):
        self.module = module
        game_dir = Path(module.root) / "game"
        self.world_data = self._load_optional(game_dir / "world.json", {"schema": "hive_world_v1", "worlds": []})
        self.identities = self._load_optional(
            game_dir / "character_identities.json",
            {"schema": "character_identity_v1", "characters": {}},
        )
        self.worlds = {row["id"]: row for row in self.world_data.get("worlds", [])}
        self.nodes = self._flatten_location_nodes()

    @staticmethod
    def _load_optional(path: Path, default: Dict[str, Any]) -> Dict[str, Any]:
        if not path.exists():
            return default
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def _flatten_location_nodes(self) -> Dict[str, Dict[str, Any]]:
        nodes: Dict[str, Dict[str, Any]] = {}
        for parent in self.module.locations.values():
            for node in parent.get("nodes", []):
                nodes[node["id"]] = node
        return nodes

    def world_for_location(self, location_id: str) -> Optional[Dict[str, Any]]:
        for world in self.worlds.values():
            if location_id in world.get("locations", []):
                return world
        return None

    def ensure_state(self, state) -> Dict[str, Any]:
        if not getattr(state, "world_state", None):
            state.world_state = {}
        world = self.world_for_location(state.current_location)
        if not world:
            return state.world_state

        active_world = state.world_state.get("active_world")
        if active_world != world["id"]:
            state.world_state["active_world"] = world["id"]
            state.world_state["player"] = self._spawn_for_location(world, state.current_location)
            state.world_state["scene_location"] = state.current_location
        elif state.world_state.get("scene_location") != state.current_location:
            # Narrative scene changes teleport the avatar to the matching authored node.
            state.world_state["player"] = self._spawn_for_location(world, state.current_location)
            state.world_state["scene_location"] = state.current_location
        state.world_state.setdefault("player", dict(world.get("player_spawn", {"x": 50, "y": 70})))
        return state.world_state

    def _spawn_for_location(self, world: Dict[str, Any], location_id: str) -> Dict[str, float]:
        node = self.nodes.get(location_id)
        if node and "x" in node and "y" in node:
            return {"x": float(node["x"]), "y": float(node["y"])}
        spawn = world.get("player_spawn", {"x": 50, "y": 70})
        return {"x": float(spawn.get("x", 50)), "y": float(spawn.get("y", 70))}

    @staticmethod
    def _distance(a: Dict[str, float], b: Dict[str, float]) -> float:
        return math.hypot(float(a["x"]) - float(b["x"]), float(a["y"]) - float(b["y"]))

    @staticmethod
    def _clamp(value: float, lo: float, hi: float) -> float:
        return max(lo, min(hi, value))

    def _visible_records(self, state, records: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
        return [row for row in records if self.module.evaluate(state, row.get("when"))]

    def _actor_view(self, state, actor_id: str) -> Dict[str, Any]:
        data = getattr(state, "actor_dynamics", {}).get(actor_id)
        return ActorDynamicsEngine.view(data)

    def _identity(self, actor_id: str) -> Dict[str, Any]:
        return dict(self.identities.get("characters", {}).get(actor_id, {}))

    def _entities_for_world(self, state, world: Dict[str, Any]) -> List[Dict[str, Any]]:
        rows = []
        for entity in self._visible_records(state, world.get("entities", [])):
            actor_id = entity["id"]
            row = dict(entity)
            row["identity"] = self._identity(actor_id)
            row["dynamics"] = self._actor_view(state, actor_id)
            row["relationship"] = int(state.npc_memory.get(actor_id, 0))
            rows.append(row)
        return rows

    def _hotspots_for_world(self, state, world: Dict[str, Any]) -> List[Dict[str, Any]]:
        return [dict(row) for row in self._visible_records(state, world.get("hotspots", []))]

    def snapshot(self, state) -> Dict[str, Any]:
        self.ensure_state(state)
        world = self.world_for_location(state.current_location)
        if not world:
            return PresentationSnapshot(
                schema=self.SCHEMA,
                world={"enabled": False, "id": None},
                player={},
                entities=[],
                hotspots=[],
                nearby=[],
            ).to_dict()

        player = dict(state.world_state.get("player", self._spawn_for_location(world, state.current_location)))
        entities = self._entities_for_world(state, world)
        hotspots = self._hotspots_for_world(state, world)
        nearby: List[Dict[str, Any]] = []
        for row in [*entities, *hotspots]:
            pos = row.get("position")
            radius = float(row.get("interaction_radius", 11))
            if pos and self._distance(player, pos) <= radius:
                nearby.append({
                    "id": row["id"],
                    "kind": row.get("kind", "entity"),
                    "label": row.get("interaction_label", f"Interact with {row.get('name', row['id'])}"),
                    "distance": round(self._distance(player, pos), 2),
                })
        nearby.sort(key=lambda row: row["distance"])

        return PresentationSnapshot(
            schema=self.SCHEMA,
            world={
                "enabled": bool(world.get("enabled", True)),
                "id": world["id"],
                "title": world.get("title", world["id"]),
                "bounds": dict(world.get("bounds", {"min_x": 0, "max_x": 100, "min_y": 0, "max_y": 100})),
                "style": dict(world.get("style", {})),
            },
            player={"x": float(player["x"]), "y": float(player["y"]), "speed": float(world.get("player_speed", 22))},
            entities=entities,
            hotspots=hotspots,
            nearby=nearby,
            ambient_fx=list(world.get("ambient_fx", [])),
            audio_cues=list(world.get("audio_cues", [])),
        ).to_dict()

    def apply_action(self, state, action: GameAction) -> Dict[str, Any]:
        self.ensure_state(state)
        world = self.world_for_location(state.current_location)
        if not world:
            raise PermissionError("No walkable world is active for this scene.")

        if action.kind == "move":
            if action.x is None or action.y is None:
                raise ValueError("move requires x and y")
            bounds = world.get("bounds", {"min_x": 0, "max_x": 100, "min_y": 0, "max_y": 100})
            current = dict(state.world_state.get("player", self._spawn_for_location(world, state.current_location)))
            requested = {
                "x": self._clamp(float(action.x), float(bounds.get("min_x", 0)), float(bounds.get("max_x", 100))),
                "y": self._clamp(float(action.y), float(bounds.get("min_y", 0)), float(bounds.get("max_y", 100))),
            }
            # A generous anti-teleport guard.  Normal client movement syncs in small steps.
            max_step = float(world.get("max_sync_step", 18))
            distance = self._distance(current, requested)
            if distance > max_step:
                ratio = max_step / distance
                requested = {
                    "x": current["x"] + (requested["x"] - current["x"]) * ratio,
                    "y": current["y"] + (requested["y"] - current["y"]) * ratio,
                }
            state.world_state["player"] = requested
            event = GameEvent(kind="world.move", turn=state.turn_count, data={"position": dict(requested)})
            # Movement sync is intentionally not appended to event_history; doing so
            # would bloat saves several times per second. The current position is
            # authoritative in world_state and the move event is returned to the client.
            state.world_state["last_move"] = event.to_dict()
            return {"event": event.to_dict(), "result": ""}

        if action.kind == "interact":
            if not action.target_id:
                raise ValueError("interact requires target_id")
            entities = {row["id"]: row for row in self._entities_for_world(state, world)}
            hotspots = {row["id"]: row for row in self._hotspots_for_world(state, world)}
            target = entities.get(action.target_id) or hotspots.get(action.target_id)
            if target is None:
                raise KeyError(f"Unknown or unavailable world target '{action.target_id}'")
            player = state.world_state.get("player", self._spawn_for_location(world, state.current_location))
            radius = float(target.get("interaction_radius", 11))
            if self._distance(player, target["position"]) > radius:
                raise PermissionError("Move closer before interacting.")

            result = target.get("result", "")
            if target.get("actor_signal"):
                actor_id = target.get("actor_id") or target.get("id")
                self.module.apply_actor_signal(state, actor_id, target["actor_signal"], salt=f"world:{action.target_id}")
            if target.get("scene"):
                self.module.enter_scene(state, target["scene"])
            state.world_state["last_interaction"] = action.target_id
            event = GameEvent(
                kind="world.interact",
                turn=state.turn_count,
                actor_id=(target["id"] if target.get("kind") == "npc" else None),
                target_id=action.target_id,
                data={"scene": target.get("scene"), "result": result},
            )
            state.event_history.append(event.to_dict())
            if result:
                state.log.append(result)
            return {"event": event.to_dict(), "result": result}

        raise KeyError(f"Unsupported world action '{action.kind}'")

    def presentation_entities(self, state) -> List[Dict[str, Any]]:
        """Server-derived current-location actors for non-walkable legacy scenes."""
        rows = []
        for npc in self.module.npcs.values():
            if npc.get("location") != state.current_location:
                continue
            identity = self._identity(npc["id"])
            rows.append({
                "id": npc["id"],
                "name": npc.get("name", npc["id"]),
                "kind": "npc",
                "identity": identity,
                "dynamics": self._actor_view(state, npc["id"]),
                "relationship": int(state.npc_memory.get(npc["id"], 0)),
                "token": identity.get("token"),
            })
        return rows
