#!/usr/bin/env python3
"""
generate_chapter_shell.py - Generate valid but empty chapter files.

Creates rooms_chXX.json with proper structure for authoring.
Ensures no malformed content enters the repo.

Usage:
    python tools/generate_chapter_shell.py 2      # Generate chapter 2
    python tools/generate_chapter_shell.py 2 3 4  # Generate chapters 2, 3, 4
"""

import json
import os
import sys

def generate_room_template(chapter, level_index, room_name):
    """Generate a single room template."""
    return {
        "id": f"ch{chapter:02d}_room_{level_index:02d}",
        "chapter": chapter,
        "level_index": level_index,
        "name": f"Room {level_index}",
        "description": f"[Placeholder description for Chapter {chapter}, Node {level_index}]",
        "short_description": f"A room.",
        "exits": {},
        "items": [],
        "npcs": [],
        "tags": [],
        "hazards": [],
        "required_flags": [],
        "set_flags_on_enter": [],
        "events": [],
        "special_commands": {},
        "failure_table": [],
        "success_table": [],
        "chapter_progress_value": 0,
        "visited": False
    }

def generate_chapter(chapter_num, output_dir="content"):
    """Generate a complete chapter shell (10 rooms)."""
    rooms = []
    for level_index in range(1, 11):  # 10 rooms per chapter
        room = generate_room_template(chapter_num, level_index, f"room_{level_index:02d}")
        rooms.append(room)
    
    # Add placeholder exit from room 1 to room 2
    rooms[0]["exits"]["forward"] = rooms[1]["id"]
    for i in range(1, 9):
        rooms[i]["exits"]["back"] = rooms[i-1]["id"]
        rooms[i]["exits"]["forward"] = rooms[i+1]["id"]
    rooms[9]["exits"]["back"] = rooms[8]["id"]
    
    output_file = os.path.join(output_dir, f"rooms_ch{chapter_num:02d}.json")
    with open(output_file, 'w') as f:
        json.dump(rooms, f, indent=2)
    
    return output_file

def main():
    """Generate chapter shells from command line."""
    if len(sys.argv) < 2:
        print("Usage: python tools/generate_chapter_shell.py <chapter_num> [<chapter_num> ...]")
        print("Example: python tools/generate_chapter_shell.py 2 3 4")
        return 1
    
    chapters = [int(arg) for arg in sys.argv[1:]]
    
    for chapter in chapters:
        output_file = generate_chapter(chapter)
        print(f"✅ Generated {output_file}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
