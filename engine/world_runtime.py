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
                "blocked_regions": list(world.get("blocked_regions", [])),
                "waypoints": list(world.get("waypoints", [])),
                "style": dict(world.get("style", {})),
            },
            player={"x": float(player["x"]), "y": float(player["y"]), "speed": float(world.get("player_speed", 22))},
            entities=entities,
            hotspots=hotspots,
            nearby=nearby,
            ambient_fx=list(world.get("ambient_fx", [])),
            audio_cues=list(world.get("audio_cues", [])),
        ).to_dict()

    def _resolve_collision(self, world: Dict[str, Any], point: Dict[str, float]) -> Dict[str, float]:
        """Slide/resolve point outside any blocked collision regions."""
        x = point["x"]
        y = point["y"]
        for region in world.get("blocked_regions", []):
            min_x = float(region.get("min_x", 0))
            max_x = float(region.get("max_x", 100))
            min_y = float(region.get("min_y", 0))
            max_y = float(region.get("max_y", 100))
            if min_x <= x <= max_x and min_y <= y <= max_y:
                d_left = abs(x - min_x)
                d_right = abs(x - max_x)
                d_top = abs(y - min_y)
                d_bottom = abs(y - max_y)
                min_d = min(d_left, d_right, d_top, d_bottom)
                if min_d == d_left:
                    x = min_x - 0.8
                elif min_d == d_right:
                    x = max_x + 0.8
                elif min_d == d_top:
                    y = min_y - 0.8
                else:
                    y = max_y + 0.8
        return {"x": x, "y": y}

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
            # A generous anti-teleport guard. Normal client movement syncs in small steps.
            max_step = float(world.get("max_sync_step", 18))
            distance = self._distance(current, requested)
            if distance > max_step:
                ratio = max_step / distance
                requested = {
                    "x": current["x"] + (requested["x"] - current["x"]) * ratio,
                    "y": current["y"] + (requested["y"] - current["y"]) * ratio,
                }
            # Enforce collision boundaries
            requested = self._resolve_collision(world, requested)
            state.world_state["player"] = requested
            event = GameEvent(kind="world.move", turn=state.turn_count, data={"position": dict(requested)})
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
            if result and (not state.log or state.log[-1] != result):
                state.log.append(result)
            return {"event": event.to_dict(), "result": result}

        if action.kind == "verb":
            if not action.target_id:
                raise ValueError("verb requires target_id")
            verb = str(action.payload.get("verb", "LOOK")).strip().upper()
            item_id = action.payload.get("item_id")
            entities = {row["id"]: row for row in self._entities_for_world(state, world)}
            hotspots = {row["id"]: row for row in self._hotspots_for_world(state, world)}
            target = entities.get(action.target_id) or hotspots.get(action.target_id)
            if target is None:
                raise KeyError(f"Unknown or unavailable world target '{action.target_id}'")

            player = state.world_state.get("player", self._spawn_for_location(world, state.current_location))
            radius = float(target.get("interaction_radius", 18))
            # LOOK can be performed from across the room; tactile verbs require proximity
            if verb != "LOOK" and self._distance(player, target["position"]) > radius:
                raise PermissionError(f"Move closer to {target.get('name', target['id'])} before doing that.")

            tid = target["id"]
            result = ""

            # Keith interactions
            if tid == "npc.keith_janitor":
                if verb == "LOOK":
                    result = "Keith stands beside his mop bucket, staring impassively into the middle distance. His faded coveralls bear stains from incidents that were definitely not his business."
                elif verb == "TALK":
                    self.module.enter_scene(state, target.get("scene", "scene.act1.keith_corner"))
                    result = target.get("result", "Keith nods once.")
                elif verb == "TAKE":
                    result = "Keith is a unionized institutional employee. You cannot place him into your inventory."
                elif verb == "USE":
                    if item_id == "item.evidence_bag_not_my_business":
                        result = "Keith points a gloved thumb toward the table. 'I gave you the bag so you wouldn't touch it with bare skin. Go use it on the berry.'"
                    elif item_id == "item.bagged_wetberry_evidence":
                        result = "Keith leans away slightly. 'Keep that plastic sealed. I don't want it vibrating anywhere near my mop bucket.'"
                    elif item_id:
                        result = "Keith glances at the object with complete administrative indifference. 'Not my department.'"
                    else:
                        result = "Select an item from Gear & Archives to use."
                elif verb == "OPEN":
                    result = "Keith's personal boundaries remain sealed under Department Regulation 404-B."
                elif verb == "GO":
                    result = "You step alongside Keith's mop bucket."
                else:
                    result = f"Keith gives you a slow look. You cannot {verb.lower()} Keith."

            # Darla interactions
            elif tid == "npc.darla_microwave":
                if verb == "LOOK":
                    result = "Darla of the Microwave watches a damp paper towel rotate through the oven window with profound religious focus."
                elif verb == "TALK":
                    self.module.enter_scene(state, target.get("scene", "scene.act1.coffee_counter"))
                    result = target.get("result", "Darla acknowledges you briefly.")
                elif verb == "TAKE":
                    result = "Darla's hand is firmly wrapped around her mug. Attempting to take anything would prompt an immediate HR grievance."
                elif verb == "USE":
                    result = "Darla ignores your offering. Her attention is locked to the microwave countdown."
                elif verb == "OPEN":
                    result = "Darla does not open up to personnel who haven't completed quarterly sensitivity training."
                elif verb == "GO":
                    result = "You step up to the coffee counter beside Darla."
                else:
                    result = f"You cannot {verb.lower()} Darla."

            # Wetberry hotspot interactions
            elif tid == "hotspot.wetberry":
                if verb == "LOOK":
                    result = "The Wetberry rests on the formica surface. It is abnormally red, glistening with condensation that seems to flow uphill, and emitting a faint 60 Hz vibration."
                elif verb == "TALK":
                    result = "You speak to the Wetberry. A crimson moisture bead quivers on its skin in what feels uncomfortably like mockery."
                elif verb == "TAKE":
                    if "item.evidence_bag_not_my_business" in state.inventory:
                        result = self.module.use_item(state, "use.evidence_bag.wetberry")
                    else:
                        result = "Keith warned you: touching the Wetberry with your bare hands is an institutional violation and an immediate psychic hazard. You need an evidence bag."
                elif verb == "USE":
                    if item_id == "item.evidence_bag_not_my_business" or "item.evidence_bag_not_my_business" in state.inventory:
                        result = self.module.use_item(state, "use.evidence_bag.wetberry")
                    elif item_id:
                        result = "That item cannot contain or affect the Wetberry."
                    else:
                        result = "Select the Evidence Bag from Gear to contain the Wetberry."
                elif verb == "OPEN":
                    result = "The Wetberry possesses no visible seams, only a glistening taut skin."
                elif verb == "GO":
                    result = "You step closer to the Central Table."
                else:
                    result = f"You cannot {verb.lower()} the Wetberry."

            # Central Table hotspot
            elif tid == "hotspot.central_table":
                if verb == "LOOK":
                    result = "A sturdy circular Formica table bolted to the linoleum. It has absorbed decades of lukewarm coffee rings and bureaucratic despair."
                elif verb == "TALK":
                    result = "The table hums faintly with building ventilation, but provides no answers."
                elif verb == "TAKE":
                    result = "The table is bolted securely to the facility foundation."
                elif verb == "USE":
                    result = "You rest your palms against the cool Formica. The vibration tingles up your forearms."
                elif verb == "OPEN":
                    result = "There are no drawers beneath the central table."
                elif verb == "GO":
                    result = "You approach the central table."
                else:
                    result = f"You cannot {verb.lower()} the table."

            # Coffee counter / microwave hotspot
            elif tid == "hotspot.coffee_machine":
                if verb == "LOOK":
                    result = "A commercial microwave with grease-caked touchpad buttons and an amber display frozen permanently at 00:01."
                elif verb == "TALK":
                    result = "The microwave transformer hums steadily in flat B-flat."
                elif verb == "TAKE":
                    result = "The microwave and laminate counter are fixed institutional fixtures."
                elif verb == "USE":
                    result = "You press ADD 30 SEC. The display beeps once, but the timer remains stubbornly at 00:01."
                elif verb == "OPEN":
                    result = "The microwave latch releases with a metallic squeal, releasing a faint smell of ancient butter flavor and scorched ozone."
                elif verb == "GO":
                    result = "You walk over to the coffee counter."
                else:
                    result = f"You cannot {verb.lower()} the microwave."

            # Vending machine hotspot
            elif tid == "hotspot.vending_machine":
                if verb == "LOOK":
                    result = "Vendrick the Vending Machine stands silent in the corner, his coiled wire racks displaying bags of potato chips from a defunct regional manufacturer."
                elif verb == "TALK":
                    result = "You speak to the vending machine. The cooling compressor rattles in reply."
                elif verb == "TAKE":
                    result = "Vendrick weighs approximately four hundred and fifty pounds."
                elif verb == "USE":
                    result = "The coin slot rejects anything other than exact emotional tokens or approved Department scrip."
                elif verb == "OPEN":
                    result = "The coin return flap is jammed shut with fossilized soda syrup."
                elif verb == "GO":
                    result = "You step in front of Vendrick's illuminated glass panel."
                else:
                    result = f"You cannot {verb.lower()} Vendrick."

            else:
                result = f"You cannot {verb.lower()} {target.get('name', target['id'])} right now."

            event = GameEvent(
                kind="world.verb",
                turn=state.turn_count,
                actor_id=(target["id"] if target.get("kind") == "npc" else None),
                target_id=action.target_id,
                data={"verb": verb, "result": result, "item_id": item_id},
            )
            state.event_history.append(event.to_dict())
            if result and (not state.log or state.log[-1] != result):
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
