#!/usr/bin/env python3
# save_system.py - Handle saving and loading game state

import json
import os

class SaveSystem:
    def __init__(self, game_state):
        self.game_state = game_state
        self.save_dir = "saves"
        os.makedirs(self.save_dir, exist_ok=True)

    def save_game(self, slot="auto"):
        """Save current game state."""
        save_data = {
            "rooms": self.game_state.rooms,
            "current_room": self.game_state.room["name"] if self.game_state.room else None,
            "inventory": list(self.game_state.inventory),
            "flags": dict(self.game_state.flags),
            "stats": dict(self.game_state.stats),
            "skills": dict(self.game_state.skills),
            "containers": dict(self.game_state.containers),
            "open_containers": list(self.game_state.open_containers),
            "locked_items": list(self.game_state.locked_items),
            "keys": dict(self.game_state.keys),
            "item_weights": dict(self.game_state.item_weights),
            "treasures": list(self.game_state.treasures),
            "characters": dict(self.game_state.characters),
            "room_details": dict(self.game_state.room_details),
            "lit_items": list(self.game_state.lit_items),
            "description_mode": self.game_state.description_mode,
            "last_command": self.game_state.last_command,
            "last_object": self.game_state.last_object,
            "chapter": self.game_state.chapter,
            "level_index": self.game_state.level_index,
            "checkpoint": self.game_state.checkpoint,
            "global_flags": list(self.game_state.global_flags),
            "chapter_flags": list(self.game_state.chapter_flags),
            "unlocked_commands": list(self.game_state.unlocked_commands),
            "visited_nodes": list(self.game_state.visited_nodes),
            "bad_idea_counters": dict(self.game_state.bad_idea_counters),
            "curse_counters": dict(self.game_state.curse_counters),
            "brother_ape_chaos_meter": self.game_state.brother_ape_chaos_meter
        }
        
        filename = f"save_{slot}.json"
        filepath = os.path.join(self.save_dir, filename)
        with open(filepath, 'w') as f:
            json.dump(save_data, f, indent=2)
        return f"Game saved to {filename}."

    def load_game(self, slot="auto"):
        """Load game state from file."""
        filename = f"save_{slot}.json"
        filepath = os.path.join(self.save_dir, filename)
        if not os.path.exists(filepath):
            return f"No save file found: {filename}."
        
        with open(filepath, 'r') as f:
            save_data = json.load(f)
        
        # Restore state
        self.game_state.rooms = save_data["rooms"]
        current_room_name = save_data["current_room"]
        self.game_state.room = self.game_state.rooms.get(current_room_name)
        self.game_state.inventory = set(save_data["inventory"])
        self.game_state.flags = save_data["flags"]
        self.game_state.stats = save_data["stats"]
        self.game_state.skills = save_data["skills"]
        self.game_state.containers = save_data["containers"]
        self.game_state.open_containers = set(save_data["open_containers"])
        self.game_state.locked_items = set(save_data["locked_items"])
        self.game_state.keys = save_data["keys"]
        self.game_state.item_weights = save_data["item_weights"]
        self.game_state.treasures = set(save_data["treasures"])
        self.game_state.characters = save_data["characters"]
        self.game_state.room_details = save_data["room_details"]
        self.game_state.lit_items = set(save_data["lit_items"])
        self.game_state.description_mode = save_data["description_mode"]
        self.game_state.last_command = save_data["last_command"]
        self.game_state.last_object = save_data["last_object"]
        self.game_state.chapter = save_data["chapter"]
        self.game_state.level_index = save_data["level_index"]
        self.game_state.checkpoint = save_data["checkpoint"]
        self.game_state.global_flags = set(save_data["global_flags"])
        self.game_state.chapter_flags = set(save_data["chapter_flags"])
        self.game_state.unlocked_commands = set(save_data["unlocked_commands"])
        self.game_state.visited_nodes = set(save_data["visited_nodes"])
        self.game_state.bad_idea_counters = save_data["bad_idea_counters"]
        self.game_state.curse_counters = save_data["curse_counters"]
        self.game_state.brother_ape_chaos_meter = save_data["brother_ape_chaos_meter"]
        
        return f"Game loaded from {filename}."