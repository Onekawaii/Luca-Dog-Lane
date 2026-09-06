#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from engine.module_runtime import CampaignModule, render_scene_for_console
from engine.module_save_system import ModuleSaveSystem


def load(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def get_visual_metadata(module: CampaignModule, state) -> dict:
    root = module.root
    visual_manifest = load(root / "visual_manifest.json")
    generated_manifest = load(root / "assets" / "generated_manifest.json")
    
    current_location_id = state.current_location
    
    # Find the top-level location that contains this nested location
    current_location_name = "Unknown"
    locations_data = load(root / "game" / "locations.json")
    for loc in locations_data:
        if current_location_id in [node["id"] for node in loc.get("nodes", [])]:
            # Find the specific nested location
            for node in loc.get("nodes", []):
                if node["id"] == current_location_id:
                    current_location_name = node.get("name", current_location_id)
                    break
            break
    
    # Build visual metadata
    metadata = {
        "current_location": current_location_id,
        "location_name": current_location_name,
        "map_asset": None,
        "map_asset_path": None,
        "room_asset": None,
        "room_asset_path": None,
        "textures": [],
        "items": [],
        "tokens": [],
        "generated": {
            "map": None,
            "room": None,
            "textures": {},
            "items": {},
            "tokens": {}
        }
    }
    
    # Get generated map asset (priority: map.breakroom)
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "maps" and asset["asset_id"] == "map.breakroom":
            metadata["map_asset"] = f"{root}/{asset['path']}"
            metadata["generated"]["map"] = asset
            break
    
    # Get generated room asset (priority: matching current location, fallback to central_table)
    room_asset_id = current_location_id.replace("location.", "room.")
    found_room = False
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "rooms" and asset["asset_id"] == room_asset_id:
            metadata["room_asset"] = f"{root}/{asset['path']}"
            metadata["generated"]["room"] = asset
            found_room = True
            break
    if not found_room:
        for asset in generated_manifest["generated_assets"]:
            if asset["category"] == "rooms" and asset["asset_id"] == "room.breakroom.central_table":
                metadata["room_asset"] = f"{root}/{asset['path']}"
                metadata["generated"]["room"] = asset
                break
    
    # Get generated textures (priority: texture.wet_table)
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "textures" and asset["asset_id"] == "texture.wet_table":
            metadata["generated"]["textures"][asset["asset_id"]] = asset
            break
    
    # Get remaining generated textures
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "textures":
            metadata["generated"]["textures"][asset["asset_id"]] = asset
    
    # Get generated items (priority: item.wetberry)
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "items" and asset["asset_id"] == "item.wetberry":
            metadata["generated"]["items"][asset["asset_id"]] = asset
            break
    
    # Get remaining generated items
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "items":
            metadata["generated"]["items"][asset["asset_id"]] = asset
    
    # Get generated tokens (priority: token.darla)
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "tokens" and asset["asset_id"] == "token.darla":
            metadata["generated"]["tokens"][asset["asset_id"]] = asset
            break
    
    # Get remaining generated tokens
    for asset in generated_manifest["generated_assets"]:
        if asset["category"] == "tokens":
            metadata["generated"]["tokens"][asset["asset_id"]] = asset
    
    # For backward compatibility with existing code
    for asset in visual_manifest["assets"]["textures"]:
        metadata["textures"].append(asset["asset_id"])
    
    for asset in visual_manifest["assets"]["items"]:
        metadata["items"].append(asset["asset_id"])
    
    for asset in visual_manifest["assets"]["tokens"]:
        metadata["tokens"].append(asset["asset_id"])
    
    return metadata


def _print_help() -> None:
    print("Available commands:")
    print("  <choice id> or <number>  Make a story choice")
    print("  state                    Show flags, stats, inventory, conditions, memories")
    print("  use <action id>          Use a contextual inventory action")
    print("  map                      Show current location and map asset")
    print("  look map                 Show map with status description")
    print("  room                     Show current room asset")
    print("  look room                Show room with status description")
    print("  assets                   List all visual assets")
    print("  save                     Save current game")
    print("  load                     Load saved game")
    print("  saves                    List save files")
    print("  delete save              Delete saved game")
    print("  help                     Show this help text")
    print("  quit                     Exit the game")


def main() -> None:
    module = CampaignModule("campaigns/strawberry_omen")
    state = module.new_state()
    module.enter_scene(state)
    saves = ModuleSaveSystem(module)

    print("THE STRAWBERRY OMEN - Reactive Lattice v0.6.0")
    print("Type a choice number/id, 'state', 'map', 'look map', 'room', 'look room', 'assets',")
    print("'save', 'load', 'saves', 'delete save', or 'quit'.")

    while True:
        scene = module.scene(state.current_scene)
        raw = input("> ").strip().lower()

        if raw in {"quit", "q", "exit"}:
            print("The breakroom returns to plausible deniability.")
            return
        if raw == "state":
            print({
                "flags": state.flags,
                "stats": state.stats,
                "inventory": state.inventory,
                "conditions": state.conditions,
                "npc_memory": state.npc_memory,
                "room_state": state.room_state.get(state.current_location, {}),
                "turn_count": state.turn_count,
            })
            print()
            print(render_scene_for_console(module, state))
            continue
        if raw == "save":
            print(saves.save_game(state))
            continue
        if raw == "load":
            loaded = saves.load_game()
            if loaded is not None:
                state = loaded
                print(f"Game loaded. Resumed at: {state.current_scene}")
                print()
                print(render_scene_for_console(module, state))
            continue
        if raw == "saves":
            available = saves.list_saves()
            if not available:
                print("No save files found.")
            else:
                print("\n=== SAVE FILES ===")
                for s in available:
                    print(f"  [{s['slot']}] {s['file']}  scene={s['current_scene']}  time={s['timestamp']}")
                print()
            continue
        if raw == "delete save":
            print(saves.delete_save())
            continue
        if raw in {"help", "h", "?"}:
            _print_help()
            continue
        if raw.startswith("use "):
            action_id = raw[4:].strip()
            try:
                result = module.use_item(state, action_id)
                print(result)
                print()
                print(render_scene_for_console(module, state))
            except (KeyError, PermissionError) as exc:
                print(f"Cannot use item: {exc}")
            continue

        if raw in {"map", "look map", "room", "look room", "assets"}:
            if raw == "map":
                metadata = get_visual_metadata(module, state)
                print(f"\n=== MAP ===")
                print(f"Current Location: {metadata['current_location']}")
                if metadata["generated"]["map"]:
                    print(f"Generated Map PNG: {metadata['generated']['map']['path']}")
                continue
            if raw == "look map":
                metadata = get_visual_metadata(module, state)
                print(f"\n=== LOOK MAP ===")
                print(f"Current Location: {metadata['current_location']}")
                if metadata["generated"]["map"]:
                    print(f"Generated Map PNG: {metadata['generated']['map']['path']}")
                    print(f"Status: This is the battlemap for {metadata['location_name']}")
                continue
            if raw == "room":
                metadata = get_visual_metadata(module, state)
                print(f"\n=== ROOM ===")
                print(f"Current Location: {metadata['current_location']}")
                if metadata["generated"]["room"]:
                    print(f"Generated Room PNG: {metadata['generated']['room']['path']}")
                continue
            if raw == "look room":
                metadata = get_visual_metadata(module, state)
                print(f"\n=== LOOK ROOM ===")
                print(f"Current Location: {metadata['current_location']}")
                if metadata["generated"]["room"]:
                    print(f"Generated Room PNG: {metadata['generated']['room']['path']}")
                    print(f"Status: This is the detailed room asset for {metadata['location_name']}")
                continue
            if raw == "assets":
                metadata = get_visual_metadata(module, state)
                print(f"\n=== ASSETS ===")
                print(f"Current Location: {metadata['current_location']}")
                print(f"Map Asset: {metadata['map_asset'] if metadata['map_asset'] else 'None'}")
                print(f"Room Asset: {metadata['room_asset'] if metadata['room_asset'] else 'None'}")
                print(f"\nTextures:")
                for texture_id, texture_asset in metadata["generated"]["textures"].items():
                    print(f"  - {texture_id}")
                    print(f"    Generated: {texture_asset['path']}")
                print(f"\nItems:")
                for item_id, item_asset in metadata["generated"]["items"].items():
                    print(f"  - {item_id}")
                    print(f"    Generated: {item_asset['path']}")
                print(f"\nTokens:")
                for token_id, token_asset in metadata["generated"]["tokens"].items():
                    print(f"  - {token_id}")
                    print(f"    Generated: {token_asset['path']}")
                continue

        choices = module.choice_views(state)
        choice_id = raw
        if raw.isdigit():
            idx = int(raw) - 1
            if 0 <= idx < len(choices):
                choice_id = choices[idx]["id"]
        try:
            prev_scene = state.current_scene
            result = module.choose(state, choice_id)
            print(result)
            # Completion-loop guard: if the scene did not change after a
            # choice in a completion_encounter, the game is over.
            if state.current_scene == prev_scene and scene.get("type") == "completion_encounter":
                print()
                print("THE GAME IS COMPLETE.")
                print("The breakroom has nothing left to show you.")
                return
            print()
            print(render_scene_for_console(module, state))
        except KeyError as exc:
            print(f"No such choice: {exc}")
        except PermissionError as exc:
            print(f"Choice locked: {exc}")


if __name__ == "__main__":
    main()
