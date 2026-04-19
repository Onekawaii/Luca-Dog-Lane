#!/usr/bin/env python3
# validate_content.py - Content validation script

import json
import os
import sys

class ContentValidator:
    def __init__(self, content_dir="content"):
        self.content_dir = content_dir
        self.errors = []
        self.warnings = []

    def validate_all(self):
        """Validate all content files."""
        print("Validating content...")

        # Load all data
        rooms = self.load_rooms()
        items = self.load_items()
        characters = self.load_characters()

        # Collect IDs/names
        item_names = set(items.keys())
        character_names = set(characters.keys())

        # Required keys for rooms
        required_room_keys = [
            "id", "chapter", "level_index", "name", "description",
            "short_description", "exits", "items", "npcs", "tags",
            "hazards", "required_flags", "set_flags_on_enter",
            "special_commands", "failure_table", "success_table",
            "chapter_progress_value"
        ]

        # Validate rooms
        room_ids_by_id = {}  # Map of ID to room object
        chapter_levels = {}

        # First pass: collect all room IDs
        for room in rooms:
            room_id = room.get("id")
            if room_id:
                room_ids_by_id[room_id] = room

        # Second pass: validate room content using complete ID set
        room_ids_check = set(room_ids_by_id.keys())
        for room in rooms:
            # Check required keys
            for key in required_room_keys:
                if key not in room:
                    self.errors.append(f"Room {room.get('name', 'unknown')} missing required key: {key}")

            # Check unique IDs
            room_id = room.get("id")
            if room_id in room_ids_by_id and room_ids_by_id[room_id] != room:
                # Check if this is a different room with same ID
                if room is not room_ids_by_id[room_id]:
                    self.errors.append(f"Duplicate room ID: {room_id}")

            # Check exits point to existing rooms (only if room was already added)
            for direction, dest in room.get("exits", {}).items():
                if dest not in room_ids_check:
                    self.errors.append(f"Room {room_id} exit '{direction}' points to non-existent room: {dest}")

            # Check items exist
            for item in room.get("items", []):
                if item not in item_names:
                    self.errors.append(f"Room {room_id} references non-existent item: {item}")

            # Check NPCs exist
            for npc in room.get("npcs", []):
                if npc not in character_names:
                    self.errors.append(f"Room {room_id} references non-existent NPC: {npc}")

            # Track chapter levels
            chapter = room.get("chapter", 1)
            level = room.get("level_index", 0)
            if chapter not in chapter_levels:
                chapter_levels[chapter] = []
            chapter_levels[chapter].append(level)

        # Check level indices are contiguous per chapter at end
        # (after all rooms have been processed)
        for chapter, levels in chapter_levels.items():
            levels.sort()
            if levels and levels[0] == 1:  # Level indices should start at 1
                expected = list(range(1, max(levels) + 1))
                if levels != expected:
                    self.warnings.append(f"Chapter {chapter} has gaps in level indices: {levels}, expected: {expected}")

        # Check for self-loops (unless tagged as loop)
        for room in rooms:
            room_id = room.get("id")
            for direction, dest in room.get("exits", {}).items():
                if dest == room_id and "loop" not in room.get("tags", []):
                    self.warnings.append(f"Room {room_id} has self-loop exit '{direction}' but not tagged 'loop'")

        return len(self.errors) == 0

    def load_rooms(self):
        """Load all room data."""
        rooms = []
        for filename in os.listdir(self.content_dir):
            if filename.startswith("rooms_ch") and filename.endswith(".json"):
                filepath = os.path.join(self.content_dir, filename)
                try:
                    with open(filepath, 'r') as f:
                        chapter_rooms = json.load(f)
                        rooms.extend(chapter_rooms)
                except Exception as e:
                    self.errors.append(f"Failed to load {filename}: {e}")
        return rooms

    def load_items(self):
        """Load item definitions."""
        items = {}
        filepath = os.path.join(self.content_dir, "items.json")
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r') as f:
                    item_data = json.load(f)
                    items = {item["name"]: item for item in item_data}
            except Exception as e:
                self.errors.append(f"Failed to load items.json: {e}")
        return items

    def load_characters(self):
        """Load character definitions."""
        characters = {}
        filepath = os.path.join(self.content_dir, "characters.json")
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r') as f:
                    char_data = json.load(f)
                    characters = {char["name"]: char for char in char_data}
            except Exception as e:
                self.errors.append(f"Failed to load characters.json: {e}")
        return characters

    def report(self):
        """Print validation report."""
        if self.errors:
            print(f"\n❌ {len(self.errors)} ERRORS:")
            for error in self.errors:
                print(f"  - {error}")

        if self.warnings:
            print(f"\n⚠️  {len(self.warnings)} WARNINGS:")
            for warning in self.warnings:
                print(f"  - {warning}")

        if not self.errors and not self.warnings:
            print("\n✅ All content validation passed!")

        return len(self.errors) == 0

if __name__ == "__main__":
    validator = ContentValidator()
    success = validator.validate_all()
    validator.report()
    sys.exit(0 if success else 1)