from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from engine.actor_dynamics import ActorDynamicsEngine, DEFAULT_ACTOR_STATE


@dataclass
class ModuleState:
    campaign_id: str
    current_scene: str
    current_location: str
    flags: Dict[str, Any] = field(default_factory=dict)
    stats: Dict[str, int] = field(default_factory=dict)
    inventory: List[str] = field(default_factory=list)
    log: List[str] = field(default_factory=list)
    room_state: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    npc_memory: Dict[str, int] = field(default_factory=dict)
    conditions: Dict[str, int] = field(default_factory=dict)
    event_history: List[Dict[str, Any]] = field(default_factory=list)
    turn_count: int = 0
    rng_seed: int = 6060
    last_outcome: Dict[str, Any] = field(default_factory=dict)
    world_state: Dict[str, Any] = field(default_factory=dict)
    actor_dynamics: Dict[str, Dict[str, float]] = field(default_factory=dict)

    def room_memory(self, location_id: Optional[str] = None) -> Dict[str, Any]:
        return self.room_state.setdefault(location_id or self.current_location, {})


class CampaignModule:
    """Data-driven Strawberry campaign runtime.

    The legacy encounter JSON remains valid.  v0.6.0 adds a versioned,
    campaign-local interaction layer (game/interactions.json) that can overlay
    choice requirements/effects, add contextual choices and item actions, and
    resolve rule tables without mutating the frozen Bard schemas.
    """

    def __init__(self, root: str | Path):
        self.root = Path(root)
        self.manifest = self._load_json(self.root / "campaign.manifest.json")
        game_dir = self.root / "game"
        self.campaign = self._load_json(game_dir / "campaign.json")
        self.locations = self._by_id(self._load_json(game_dir / "locations.json"))
        self.items = self._by_id(self._load_json(game_dir / "items.json"))
        self.npcs = self._by_id(self._load_json(game_dir / "npcs.json"))
        self.encounters = self._by_id(self._load_json(game_dir / "encounters.json"))
        self.conditions = self._by_id(self._load_json(game_dir / "conditions.json"))
        self.random_tables = self._load_json(game_dir / "random_tables.json")
        self.quests = self._by_id(self._load_json(game_dir / "quests.json"))
        interactions_path = game_dir / "interactions.json"
        self.interactions = self._load_json(interactions_path) if interactions_path.exists() else {
            "schema": "strawberry_interactions_v1",
            "choice_overlays": {},
            "scene_choices": {},
            "item_actions": [],
            "rule_tables": {},
        }
        self.item_actions = self._by_id(self.interactions.get("item_actions", []))

    @staticmethod
    def _load_json(path: Path) -> Any:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)

    @staticmethod
    def _by_id(records: Iterable[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        return {record["id"]: record for record in records}

    def new_state(self) -> ModuleState:
        return ModuleState(
            campaign_id=self.campaign["id"],
            current_scene=self.campaign["entry_scene"],
            current_location=self.campaign["entry_location"],
            flags=dict(self.campaign.get("starting_flags", {})),
            stats=dict(self.campaign.get("starting_stats", {})),
            inventory=list(self.campaign.get("starting_inventory", [])),
            rng_seed=int(self.campaign.get("rng_seed", 6060)),
        )

    def scene(self, scene_id: str) -> Dict[str, Any]:
        return self.encounters[scene_id]

    # ------------------------------------------------------------------
    # Condition / requirement engine
    # ------------------------------------------------------------------

    def evaluate(self, state: ModuleState, spec: Optional[Dict[str, Any]]) -> bool:
        """Evaluate a declarative interaction condition.

        Supported forms are intentionally small and composable:
          all / any / not
          flags / not_flags
          item / items_all / items_any
          stats: {name: {gte/lte/gt/lt/eq: number}}
          npc: {id, gte/lte/eq}
          room: {location?, key, equals|gte|lte}
          condition / scene
        """
        if not spec:
            return True
        if "all" in spec:
            return all(self.evaluate(state, child) for child in spec["all"])
        if "any" in spec:
            return any(self.evaluate(state, child) for child in spec["any"])
        if "not" in spec:
            return not self.evaluate(state, spec["not"])

        if "flags" in spec:
            if not all(state.flags.get(k) == v for k, v in spec["flags"].items()):
                return False
        if "not_flags" in spec:
            if any(state.flags.get(k) == v for k, v in spec["not_flags"].items()):
                return False
        if "item" in spec and spec["item"] not in state.inventory:
            return False
        if "items_all" in spec and not all(i in state.inventory for i in spec["items_all"]):
            return False
        if "items_any" in spec and not any(i in state.inventory for i in spec["items_any"]):
            return False
        if "scene" in spec and state.current_scene != spec["scene"]:
            return False
        if "condition" in spec and spec["condition"] not in state.conditions:
            return False

        for stat, rule in spec.get("stats", {}).items():
            if not self._compare_number(int(state.stats.get(stat, 0)), rule):
                return False

        npc_rule = spec.get("npc")
        if npc_rule:
            value = int(state.npc_memory.get(npc_rule["id"], 0))
            if not self._compare_number(value, npc_rule):
                return False

        room_rule = spec.get("room")
        if room_rule:
            location = room_rule.get("location", state.current_location)
            value = state.room_state.get(location, {}).get(room_rule["key"])
            if "equals" in room_rule and value != room_rule["equals"]:
                return False
            if any(k in room_rule for k in ("gte", "lte", "gt", "lt", "eq")):
                try:
                    numeric = int(value or 0)
                except (TypeError, ValueError):
                    return False
                if not self._compare_number(numeric, room_rule):
                    return False
        return True

    @staticmethod
    def _compare_number(value: int, rule: Dict[str, Any]) -> bool:
        if "gte" in rule and value < int(rule["gte"]):
            return False
        if "lte" in rule and value > int(rule["lte"]):
            return False
        if "gt" in rule and value <= int(rule["gt"]):
            return False
        if "lt" in rule and value >= int(rule["lt"]):
            return False
        if "eq" in rule and value != int(rule["eq"]):
            return False
        return True

    def _requirements_for_choice(self, choice: Dict[str, Any]) -> Dict[str, Any]:
        parts: List[Dict[str, Any]] = []
        if choice.get("requires_flags"):
            parts.append({"flags": choice["requires_flags"]})
        if choice.get("forbids_flags"):
            parts.append({"not_flags": choice["forbids_flags"]})
        if choice.get("requires_items"):
            parts.append({"items_all": choice["requires_items"]})
        if choice.get("requires_any_items"):
            parts.append({"items_any": choice["requires_any_items"]})
        if choice.get("requires_stats"):
            parts.append({"stats": choice["requires_stats"]})
        if choice.get("when"):
            parts.append(choice["when"])
        if not parts:
            return {}
        return {"all": parts}

    def _locked_reason(self, state: ModuleState, choice: Dict[str, Any]) -> str:
        if choice.get("locked_reason"):
            return choice["locked_reason"]
        missing = [i for i in choice.get("requires_items", []) if i not in state.inventory]
        if missing:
            names = [self.items.get(i, {}).get("name", i) for i in missing]
            return "Requires " + ", ".join(names)
        for stat, rule in choice.get("requires_stats", {}).items():
            if not self._compare_number(int(state.stats.get(stat, 0)), rule):
                if "gte" in rule:
                    return f"Requires {stat.replace('_', ' ').title()} {rule['gte']}+"
        if choice.get("requires_flags"):
            return "A prior action has not unlocked this yet."
        return "Unavailable because of your current state."

    # ------------------------------------------------------------------
    # Choice composition / presentation
    # ------------------------------------------------------------------

    def scene_choices(self, scene_id: str) -> List[Dict[str, Any]]:
        scene = self.scene(scene_id)
        overlays = self.interactions.get("choice_overlays", {})
        choices: List[Dict[str, Any]] = []
        for base in scene.get("choices", []):
            merged = dict(base)
            merged.update(overlays.get(base["id"], {}))
            choices.append(merged)
        for extra in self.interactions.get("scene_choices", {}).get(scene_id, []):
            choices.append(dict(extra))
        return choices

    def choice_views(self, state: ModuleState) -> List[Dict[str, Any]]:
        views: List[Dict[str, Any]] = []
        for choice in self.scene_choices(state.current_scene):
            available = self.evaluate(state, self._requirements_for_choice(choice))
            if not available and choice.get("hidden_if_locked", False):
                continue
            views.append({
                "id": choice["id"],
                "label": choice["label"],
                "available": available,
                "locked_reason": None if available else self._locked_reason(state, choice),
                "kind": choice.get("kind", "choice"),
            })
        return views

    # ------------------------------------------------------------------
    # State effects
    # ------------------------------------------------------------------

    def _advance_conditions(self, state: ModuleState) -> None:
        expired: List[str] = []
        for condition_id, turns in list(state.conditions.items()):
            if turns < 0:
                continue
            remaining = int(turns) - 1
            if remaining <= 0:
                expired.append(condition_id)
            else:
                state.conditions[condition_id] = remaining
        for condition_id in expired:
            state.conditions.pop(condition_id, None)

    def apply_actor_signal(
        self,
        state: ModuleState,
        actor_id: str,
        signal: Dict[str, float],
        *,
        salt: str = "effect",
    ) -> Dict[str, float]:
        current = state.actor_dynamics.get(actor_id, DEFAULT_ACTOR_STATE.to_dict())
        stepped = ActorDynamicsEngine.step(
            current,
            signal,
            seed=state.rng_seed,
            salt=f"{actor_id}:{state.turn_count}:{salt}:{current}",
            noise_scale=float(signal.get("_noise_scale", 0.02)),
        )
        state.actor_dynamics[actor_id] = stepped.to_dict()
        return state.actor_dynamics[actor_id]

    def apply_effects(self, state: ModuleState, effects: Dict[str, Any]) -> None:
        for key, value in effects.get("sets_flags", {}).items():
            state.flags[key] = value
        for key, delta in effects.get("stat_delta", {}).items():
            state.stats[key] = int(state.stats.get(key, 0)) + int(delta)
        for item_id in effects.get("grants_items", []):
            if item_id not in state.inventory:
                state.inventory.append(item_id)
        for item_id in effects.get("removes_items", []):
            while item_id in state.inventory:
                state.inventory.remove(item_id)
        for item_id in effects.get("consumes_items", []):
            if item_id in state.inventory:
                state.inventory.remove(item_id)
        for npc_id, delta in effects.get("npc_delta", {}).items():
            state.npc_memory[npc_id] = int(state.npc_memory.get(npc_id, 0)) + int(delta)
        for actor_id, signal in effects.get("actor_signal", {}).items():
            self.apply_actor_signal(state, actor_id, dict(signal), salt="apply_effects")
        if effects.get("room_state"):
            room = state.room_memory(effects.get("room_location"))
            room.update(effects["room_state"])
        for condition in effects.get("add_conditions", []):
            if isinstance(condition, str):
                state.conditions[condition] = -1
            else:
                state.conditions[condition["id"]] = int(condition.get("turns", -1))
        for condition_id in effects.get("remove_conditions", []):
            state.conditions.pop(condition_id, None)

    def _deterministic_roll(self, state: ModuleState, salt: str) -> int:
        digest = hashlib.sha256(
            f"{state.rng_seed}:{state.turn_count}:{state.current_scene}:{salt}".encode("utf-8")
        ).digest()
        return int.from_bytes(digest[:8], "big")

    def trigger_table(self, state: ModuleState, table_id: str) -> Optional[Dict[str, Any]]:
        rows = self.random_tables.get(table_id, [])
        if not rows:
            return None
        total = sum(max(0, int(row.get("weight", 1))) for row in rows)
        if total <= 0:
            return None
        pick = self._deterministic_roll(state, table_id) % total
        selected = rows[-1]
        cursor = 0
        for row in rows:
            cursor += max(0, int(row.get("weight", 1)))
            if pick < cursor:
                selected = row
                break
        self.apply_effects(state, selected)
        event = {
            "table": table_id,
            "text": selected.get("text", ""),
            "turn": state.turn_count,
        }
        state.event_history.append(event)
        if event["text"]:
            state.log.append(event["text"])
        return event

    def resolve_rule_table(self, state: ModuleState, table_id: str) -> Dict[str, Any]:
        rules = self.interactions.get("rule_tables", {}).get(table_id, [])
        for rule in rules:
            if rule.get("default") or self.evaluate(state, rule.get("when")):
                self.apply_effects(state, rule)
                return rule
        raise KeyError(f"Rule table '{table_id}' has no matching/default rule")

    def enter_scene(self, state: ModuleState, scene_id: Optional[str] = None, *, apply_entry: bool = True) -> Dict[str, Any]:
        scene = self.scene(scene_id or state.current_scene)
        state.current_scene = scene["id"]
        state.current_location = scene["location"]
        room = state.room_memory()
        room["visited"] = True
        room["visits"] = int(room.get("visits", 0)) + (1 if apply_entry else 0)
        if apply_entry:
            for key, value in scene.get("on_enter_flags", {}).items():
                state.flags[key] = value
            entry_overlay = self.interactions.get("scene_entry_effects", {}).get(scene["id"], {})
            self.apply_effects(state, entry_overlay)
            if entry_overlay.get("triggers_table"):
                self.trigger_table(state, entry_overlay["triggers_table"])
        return scene

    def choose(self, state: ModuleState, choice_id: str) -> str:
        choice = next((c for c in self.scene_choices(state.current_scene) if c["id"] == choice_id), None)
        if choice is None:
            raise KeyError(f"Unknown choice '{choice_id}' for scene '{state.current_scene}'")
        if not self.evaluate(state, self._requirements_for_choice(choice)):
            raise PermissionError(self._locked_reason(state, choice))

        self._advance_conditions(state)
        state.turn_count += 1

        # Base effects first. A check/rule table may add or override the result.
        self.apply_effects(state, choice)
        result = choice.get("result", "")
        outcome: Dict[str, Any] = {"choice_id": choice_id, "turn": state.turn_count}

        check = choice.get("check")
        if check:
            branch = check.get("success", {}) if self.evaluate(state, check.get("when")) else check.get("failure", {})
            self.apply_effects(state, branch)
            result = branch.get("result", result)
            outcome["check"] = "success" if branch is check.get("success") else "failure"
            if branch.get("next_scene"):
                choice = {**choice, "next_scene": branch["next_scene"]}

        if choice.get("rule_table"):
            rule = self.resolve_rule_table(state, choice["rule_table"])
            result = rule.get("result", result)
            outcome["rule"] = rule.get("id")
            if rule.get("next_scene"):
                choice = {**choice, "next_scene": rule["next_scene"]}

        if choice.get("triggers_table"):
            event = self.trigger_table(state, choice["triggers_table"])
            if event and event.get("text"):
                result = (result + "\n\n" + event["text"]).strip()
            outcome["event"] = event

        if result:
            state.log.append(result)
        state.last_outcome = outcome

        if choice.get("next_scene"):
            self.enter_scene(state, choice["next_scene"])
        return result

    # ------------------------------------------------------------------
    # Item actions
    # ------------------------------------------------------------------

    def item_action_views(self, state: ModuleState) -> List[Dict[str, Any]]:
        views: List[Dict[str, Any]] = []
        for action in self.item_actions.values():
            if action.get("item_id") not in state.inventory:
                continue
            available = self.evaluate(state, action.get("when"))
            if not available and action.get("hidden_if_locked", True):
                continue
            views.append({
                "id": action["id"],
                "item_id": action["item_id"],
                "label": action["label"],
                "available": available,
                "locked_reason": None if available else action.get("locked_reason", "Not usable here."),
            })
        return views

    def use_item(self, state: ModuleState, action_id: str) -> str:
        action = self.item_actions.get(action_id)
        if action is None:
            raise KeyError(f"Unknown item action '{action_id}'")
        if action["item_id"] not in state.inventory:
            raise PermissionError("You do not have that item.")
        if not self.evaluate(state, action.get("when")):
            raise PermissionError(action.get("locked_reason", "That item cannot be used here."))

        self._advance_conditions(state)
        state.turn_count += 1
        self.apply_effects(state, action)
        result = action.get("result", "")
        if action.get("rule_table"):
            rule = self.resolve_rule_table(state, action["rule_table"])
            result = rule.get("result", result)
        if action.get("triggers_table"):
            event = self.trigger_table(state, action["triggers_table"])
            if event and event.get("text"):
                result = (result + "\n\n" + event["text"]).strip()
        if result:
            state.log.append(result)
        state.last_outcome = {"item_action": action_id, "turn": state.turn_count}
        if action.get("next_scene"):
            self.enter_scene(state, action["next_scene"])
        return result

    def item_details(self, state: ModuleState) -> List[Dict[str, Any]]:
        actions_by_item: Dict[str, List[Dict[str, Any]]] = {}
        for view in self.item_action_views(state):
            actions_by_item.setdefault(view["item_id"], []).append(view)
        details: List[Dict[str, Any]] = []
        for item_id in state.inventory:
            item = self.items.get(item_id, {"id": item_id, "name": item_id, "description": ""})
            details.append({
                "id": item_id,
                "name": item.get("name", item_id),
                "description": item.get("description", ""),
                "tags": item.get("tags", []),
                "actions": actions_by_item.get(item_id, []),
            })
        return details


def render_scene_for_console(module: CampaignModule, state: ModuleState) -> str:
    scene = module.scene(state.current_scene)
    lines = [f"[{scene['title']}]", scene.get("read_aloud", "")]
    choices = module.choice_views(state)
    if choices:
        lines.append("\nChoices:")
        for index, choice in enumerate(choices, start=1):
            suffix = "" if choice["available"] else f" [LOCKED: {choice['locked_reason']}]"
            lines.append(f"  {index}. {choice['label']} ({choice['id']}){suffix}")
    item_actions = module.item_action_views(state)
    if item_actions:
        lines.append("\nItem actions:")
        for action in item_actions:
            lines.append(f"  use {action['id']} — {action['label']}")
    return "\n".join(lines)
