#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))


def load(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    required_files = [
        "campaign.manifest.json",
        "campaign.book.md",
        "game/campaign.json",
        "game/locations.json",
        "game/items.json",
        "game/npcs.json",
        "game/encounters.json",
        "game/conditions.json",
        "game/random_tables.json",
        "game/quests.json",
        "game/interactions.json",
    ]
    for relative_path in required_files:
        if not (root / relative_path).exists():
            errors.append(f"missing required file: {relative_path}")
    if errors:
        return errors

    manifest = load(root / "campaign.manifest.json")
    game_dir = root / "game"
    campaign = load(game_dir / "campaign.json")
    locations = load(game_dir / "locations.json")
    items = load(game_dir / "items.json")
    npcs = load(game_dir / "npcs.json")
    encounters = load(game_dir / "encounters.json")
    conditions = load(game_dir / "conditions.json")
    random_tables = load(game_dir / "random_tables.json")
    quests = load(game_dir / "quests.json")
    interactions = load(game_dir / "interactions.json")

    ids = {
        "locations": {loc["id"] for loc in locations},
        "nodes": {node["id"] for loc in locations for node in loc.get("nodes", [])},
        "items": {item["id"] for item in items},
        "npcs": {npc["id"] for npc in npcs},
        "encounters": {enc["id"] for enc in encounters},
        "conditions": {condition["id"] for condition in conditions},
        "quests": {quest["id"] for quest in quests},
    }

    if manifest.get("id") != campaign.get("id"):
        errors.append("manifest id does not match campaign id")
    if manifest.get("book") and not (root / manifest["book"]).exists():
        errors.append(f"manifest book missing: {manifest['book']}")
    for label, relative_path in manifest.get("game_files", {}).items():
        if not (root / relative_path).exists():
            errors.append(f"manifest game file missing for {label}: {relative_path}")
    if campaign.get("entry_scene") not in ids["encounters"]:
        errors.append(f"entry scene missing: {campaign.get('entry_scene')}")
    if campaign.get("entry_location") not in ids["nodes"]:
        errors.append(f"entry location missing: {campaign.get('entry_location')}")

    for loc in locations:
        for node in loc.get("nodes", []):
            scene_id = node.get("scene")
            if scene_id and scene_id not in ids["encounters"]:
                errors.append(f"location node {node['id']} points to missing scene {scene_id}")

    for enc in encounters:
        if enc.get("location") not in ids["nodes"]:
            errors.append(f"encounter {enc['id']} points to missing location {enc.get('location')}")
        for choice in enc.get("choices", []):
            for item_id in choice.get("grants_items", []):
                if item_id not in ids["items"]:
                    errors.append(f"choice {choice['id']} grants missing item {item_id}")
            spawned = choice.get("spawns_npc")
            if spawned and spawned not in ids["npcs"]:
                errors.append(f"choice {choice['id']} spawns missing npc {spawned}")
            nxt = choice.get("next_scene")
            if nxt and nxt not in ids["encounters"]:
                errors.append(f"choice {choice['id']} points to missing next_scene {nxt}")

    for npc in npcs:
        if npc.get("location") not in ids["nodes"]:
            errors.append(f"npc {npc['id']} points to missing location {npc.get('location')}")

    for item in items:
        for asset_path in item.get("asset", {}).values():
            if not (root / asset_path).exists():
                errors.append(f"item {item['id']} references missing asset {asset_path}")
        for effect in item.get("effects", []):
            condition = effect.get("on_fail", {}).get("condition")
            if condition and condition not in ids["conditions"]:
                errors.append(f"item {item['id']} references missing condition {condition}")

    for table_id, rows in random_tables.items():
        for row in rows:
            item_id = row.get("item")
            if item_id and item_id not in ids["items"]:
                errors.append(f"random table {table_id} references missing item {item_id}")

    for quest in quests:
        if quest.get("starts_at") not in ids["encounters"]:
            errors.append(f"quest {quest['id']} starts at missing encounter {quest.get('starts_at')}")
        for objective in quest.get("objectives", []):
            item_id = objective.get("item")
            if item_id and item_id not in ids["items"]:
                errors.append(f"quest objective {objective['id']} references missing item {item_id}")

    # Reactive interaction layer (v0.6.0+)
    if interactions.get("schema") != manifest.get("interaction_schema"):
        errors.append("interaction schema does not match manifest interaction_schema")

    all_choice_ids = {choice["id"] for enc in encounters for choice in enc.get("choices", [])}
    for scene_id, extras in interactions.get("scene_choices", {}).items():
        if scene_id not in ids["encounters"]:
            errors.append(f"interaction scene_choices points to missing scene {scene_id}")
        for choice in extras:
            if choice["id"] in all_choice_ids:
                errors.append(f"interaction choice duplicates existing choice id {choice['id']}")
            all_choice_ids.add(choice["id"])
            nxt = choice.get("next_scene")
            if nxt and nxt not in ids["encounters"]:
                errors.append(f"interaction choice {choice['id']} points to missing next_scene {nxt}")
            for item_id in choice.get("grants_items", []) + choice.get("requires_items", []) + choice.get("removes_items", []) + choice.get("consumes_items", []):
                if item_id not in ids["items"]:
                    errors.append(f"interaction choice {choice['id']} references missing item {item_id}")
            for condition in choice.get("add_conditions", []):
                condition_id = condition if isinstance(condition, str) else condition.get("id")
                if condition_id and condition_id not in ids["conditions"]:
                    errors.append(f"interaction choice {choice['id']} references missing condition {condition_id}")

    for choice_id, overlay in interactions.get("choice_overlays", {}).items():
        if choice_id not in all_choice_ids:
            errors.append(f"choice overlay references missing choice {choice_id}")
        for item_id in overlay.get("grants_items", []) + overlay.get("requires_items", []) + overlay.get("removes_items", []) + overlay.get("consumes_items", []):
            if item_id not in ids["items"]:
                errors.append(f"choice overlay {choice_id} references missing item {item_id}")
        for npc_id in overlay.get("npc_delta", {}):
            if npc_id not in ids["npcs"]:
                errors.append(f"choice overlay {choice_id} references missing npc {npc_id}")

    action_ids = set()
    for action in interactions.get("item_actions", []):
        if action["id"] in action_ids:
            errors.append(f"duplicate item action id {action['id']}")
        action_ids.add(action["id"])
        if action.get("item_id") not in ids["items"]:
            errors.append(f"item action {action['id']} references missing item {action.get('item_id')}")
        nxt = action.get("next_scene")
        if nxt and nxt not in ids["encounters"]:
            errors.append(f"item action {action['id']} points to missing next_scene {nxt}")
        for npc_id in action.get("npc_delta", {}):
            if npc_id not in ids["npcs"]:
                errors.append(f"item action {action['id']} references missing npc {npc_id}")

    rule_tables = interactions.get("rule_tables", {})
    for choice in list(interactions.get("scene_choices", {}).values()):
        pass
    # Validate declared rule-table and random-table references recursively at top level.
    interaction_records = list(interactions.get("choice_overlays", {}).values())
    interaction_records += [c for rows in interactions.get("scene_choices", {}).values() for c in rows]
    interaction_records += list(interactions.get("item_actions", []))
    for record in interaction_records:
        table = record.get("rule_table")
        if table and table not in rule_tables:
            errors.append(f"interaction record {record.get('id', '<overlay>')} references missing rule table {table}")
        random_table = record.get("triggers_table")
        if random_table and random_table not in random_tables:
            errors.append(f"interaction record {record.get('id', '<overlay>')} references missing random table {random_table}")

    for table_id, rules in rule_tables.items():
        if not any(rule.get("default") for rule in rules):
            errors.append(f"rule table {table_id} has no default rule")
        for rule in rules:
            for condition in rule.get("add_conditions", []):
                condition_id = condition if isinstance(condition, str) else condition.get("id")
                if condition_id and condition_id not in ids["conditions"]:
                    errors.append(f"rule table {table_id} references missing condition {condition_id}")

    return errors


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("campaigns/strawberry_omen")
    errors = validate(root)
    
    from tools.validate_visual_assets import validate_visual_assets as validate_visual
    visual_errors = validate_visual(root)
    errors.extend(visual_errors)
    
    if errors:
        print("Campaign module validation FAILED")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"Campaign module validation PASSED: {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
