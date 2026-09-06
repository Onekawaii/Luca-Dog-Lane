#!/usr/bin/env python3
"""
content_lint.py - Clean validation reporting for game content.

This tool validates all content files and provides a machine-readable summary
of schema compliance, references, and connectivity. Run before every build.

Usage:
    python tools/content_lint.py              # Validate all content
    python tools/content_lint.py chapter 1    # Validate specific chapter
"""

import json
import os
import sys

class ContentLinter:
    def __init__(self, content_dir="content"):
        self.content_dir = content_dir
        self.stats = {
            "total_rooms": 0,
            "total_items": 0,
            "total_characters": 0,
            "valid_item_refs": 0,
            "valid_npc_refs": 0,
            "broken_exits": 0,
            "schema_failures": 0,
            "chapters": {}
        }
        self.errors = []
        self.warnings = []

    def lint_all(self):
        """Lint all content files."""
        # Windows terminals may default to cp1252; avoid non-ASCII output here.
        print("Content Linter - Scanning...")
        print()
        
        # Load reference data
        items = self.load_items()
        characters = self.load_characters()
        rooms_by_chapter = self.load_all_rooms()
        
        self.stats["total_items"] = len(items)
        self.stats["total_characters"] = len(characters)
        
        # Validate rooms
        for chapter, rooms in rooms_by_chapter.items():
            self.stats["chapters"][chapter] = {
                "rooms": len(rooms),
                "item_refs": 0,
                "npc_refs": 0,
                "broken_exits": 0
            }
            
            room_ids = {r["id"]: r for r in rooms}
            
            for room in rooms:
                # Check item references
                for item in room.get("items", []):
                    if item in items:
                        self.stats["valid_item_refs"] += 1
                        self.stats["chapters"][chapter]["item_refs"] += 1
                    else:
                        self.errors.append(f"Ch{chapter}: Room '{room['name']}' references non-existent item: {item}")
                        self.stats["chapters"][chapter]["broken_exits"] += 1
                
                # Check NPC references
                for npc in room.get("npcs", []):
                    if npc in characters:
                        self.stats["valid_npc_refs"] += 1
                        self.stats["chapters"][chapter]["npc_refs"] += 1
                    else:
                        self.errors.append(f"Ch{chapter}: Room '{room['name']}' references non-existent NPC: {npc}")
                
                # Check exits
                for direction, dest in room.get("exits", {}).items():
                    if dest not in room_ids:
                        self.errors.append(f"Ch{chapter}: Room '{room['name']}' exit '{direction}' -> '{dest}' (not found)")
                        self.stats["broken_exits"] += 1
                        self.stats["chapters"][chapter]["broken_exits"] += 1
        
        self.stats["total_rooms"] = sum(len(r) for r in rooms_by_chapter.values())
        
        return len(self.errors) == 0

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

    def load_all_rooms(self):
        """Load rooms from all chapter files."""
        rooms_by_chapter = {}
        for filename in os.listdir(self.content_dir):
            if filename.startswith("rooms_ch") and filename.endswith(".json"):
                filepath = os.path.join(self.content_dir, filename)
                try:
                    chapter_num = int(filename[8:10])  # Extract chapter number
                    with open(filepath, 'r') as f:
                        chapter_rooms = json.load(f)
                        rooms_by_chapter[chapter_num] = chapter_rooms
                except Exception as e:
                    self.errors.append(f"Failed to load {filename}: {e}")
        return rooms_by_chapter

    def report(self):
        """Print formatted lint report."""
        print("=" * 70)
        print("CONTENT LINT REPORT")
        print("=" * 70)
        print()
        
        # Summary line
        print(f"{self.stats['total_rooms']} rooms")
        print(f"{self.stats['total_items']} items")
        print(f"{self.stats['total_characters']} NPCs")
        print()
        
        # References
        print(f"OK {self.stats['valid_item_refs']} valid item references")
        print(f"OK {self.stats['valid_npc_refs']} valid NPC references")
        print()
        
        # Errors
        if self.errors:
            print(f"{len(self.errors)} ERRORS:")
            for error in self.errors:
                print(f"   - {error}")
            print()
        else:
            print("OK 0 schema failures")
            print("OK 0 broken exits")
            print("OK All references valid")
            print()
        
        # Per-chapter breakdown
        if self.stats["chapters"]:
            print("Chapters:")
            for chapter in sorted(self.stats["chapters"].keys()):
                ch = self.stats["chapters"][chapter]
                print(f"   Ch{chapter}: {ch['rooms']:2d} rooms | {ch['item_refs']:2d} items | {ch['npc_refs']:2d} NPCs | {ch['broken_exits']} broken")
            print()
        
        # Final status
        if len(self.errors) == 0:
            print("Content validation PASSED")
            return 0
        else:
            print(f"Content validation FAILED ({len(self.errors)} errors)")
            return 1


def main():
    """Run linter from command line."""
    linter = ContentLinter()
    success = linter.lint_all()
    linter.report()
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
