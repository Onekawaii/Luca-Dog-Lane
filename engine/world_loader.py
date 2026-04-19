#!/usr/bin/env python3
# world_loader.py - Load world data from JSON files

import json
import os

class WorldLoader:
    def __init__(self, game_state):
        self.game_state = game_state

    def load_chapter(self, chapter_num):
        """Load rooms for a specific chapter."""
        filename = f"rooms_ch{chapter_num:02d}.json"
        filepath = os.path.join("content", filename)
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                rooms_data = json.load(f)
                for room_data in rooms_data:
                    self.game_state.add_room_from_data(room_data)
            return True
        return False

    def load_items(self):
        """Load item definitions."""
        filepath = os.path.join("content", "items.json")
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                items_data = json.load(f)
                self.game_state.item_weights = {item["name"]: item.get("weight", 1) for item in items_data}
                # Could load more item properties here

    def load_characters(self):
        """Load character definitions."""
        filepath = os.path.join("content", "characters.json")
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                characters_data = json.load(f)
                # Process characters

    def load_commands(self):
        """Load command definitions and rules."""
        filepath = os.path.join("content", "commands.json")
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                commands_data = json.load(f)
                # Process commands

    def load_level_rules(self):
        """Load level progression rules."""
        filepath = os.path.join("content", "level_rules.json")
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                rules_data = json.load(f)
                # Process rules