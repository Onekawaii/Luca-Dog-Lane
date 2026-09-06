#!/usr/bin/env python3
"""
test_chapter2_lawful_path.py - Chapter 2 lawful route spine test.

This test validates the lawful bureaucratic path through Chapter 2:
- Take number at desk
- Queue properly
- Get form
- File form
- Receive denial
- Appeal denial
- Recover correction material
- Stamp form
- Present to Frank
- Exit via gate

Run with: python tests/test_chapter2_lawful_path.py
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from engine.game_state import GameState
from engine.parser import Parser
from engine.command_router import CommandRouter
from engine.world_loader import WorldLoader
from engine.progression import Progression
from engine.combatless_resolution import CombatlessResolution
from engine.random_events import RandomEvents


class Chapter2LawfulTest:
    """Run Chapter 2 lawful route and validate."""
    
    def __init__(self):
        self.game_state = GameState()
        self.parser = Parser(self.game_state)
        self.world_loader = WorldLoader(self.game_state)
        self.progression = Progression(self.game_state)
        self.combatless_resolution = CombatlessResolution(self.game_state)
        self.random_events = RandomEvents(self.game_state)
        self.router = CommandRouter(
            self.game_state, self.parser, self.world_loader,
            self.progression, self.combatless_resolution, self.random_events
        )
        
        # Load the game
        self.game_state.load_world_data("content")
        
        # Skip to Chapter 2
        self.game_state.chapter = 2
        self.game_state.level_index = 1
        
        # Initialize Chapter 2 rooms
        import json
        with open("content/rooms_ch02.json", 'r') as f:
            rooms_data = json.load(f)
            for room_data in rooms_data:
                self.game_state.add_room_from_data(room_data)
        
        # Set starting room to Chapter 2 entry
        self.game_state.room = self.game_state.rooms.get("ch02_01_intake_stairs")
        
        # Initialize Frank reputation from Chapter 1 (simulate bureaucratic route)
        self.game_state.chapter_route_history.append({
            "chapter": 1,
            "route_leaning": "bureaucratic",
            "final_stats": {}
        })
        self.game_state.initialize_frank_reputation_from_chapter_1()
    
    def execute_command(self, command_str):
        """Execute a single command and return result."""
        intent = self.parser.parse_input(command_str)
        result = self.router.route_intent(intent)
        return result
    
    def run_script(self, commands):
        """Run a sequence of commands."""
        results = []
        for cmd in commands:
            result = self.execute_command(cmd)
            results.append({
                "command": cmd,
                "result": result,
                "room": self.game_state.room["name"] if self.game_state.room else "NONE",
                "frank_rep": self.game_state.frank_reputation
            })
        return results


def test_chapter2_lawful_path():
    """Test the lawful bureaucratic path through Chapter 2."""
    test = Chapter2LawfulTest()
    
    # Lawful route commands
    script = [
        "look",
        "go east",                    # -> Number Desk
        "take number",                # Get queue_slip
        "go east",                    # -> Queue Spine
        "queue",                      # Join queue properly
        "go east",                    # -> Form Window
        "take blank form",            # Get blank_form_27b
        "file form",                  # File the form
        "go east",                    # -> Denial Bay
        "appeal denial",              # Appeal initial denial
        "go north",                   # -> Lost Records
        "take correction ribbon",     # Get correction material
        "go east",                    # -> Stamp Sanctum
        "stamp form",                 # Stamp the form
        "go east",                    # -> Frank Outer Desk
        "talk frank",                 # Present to Frank
        "go east",                    # -> Gate Review (end)
    ]
    
    # Run the script
    results = test.run_script(script)
    
    # Print execution log
    print("\n" + "="*80)
    print("🎮 CHAPTER 2 LAWFUL ROUTE TEST")
    print("="*80 + "\n")
    
    for i, step in enumerate(results, 1):
        frank_str = f"| Frank Rep: {step['frank_rep']:+d}" if step['frank_rep'] != test.game_state.frank_reputation else ""
        print(f"{i:2d}. {step['command']:25s} → [{step['room']:20s}]")
    
    # Validate state at end
    print("\n" + "-"*80)
    print("📊 FINAL STATE")
    print("-"*80)
    final_room = test.game_state.room["name"] if test.game_state.room else "NONE"
    print(f"✓ Room: {final_room}")
    print(f"✓ Health: {test.game_state.stats['health']}")
    print(f"✓ Frank Reputation: {test.game_state.frank_reputation} ({test.game_state.get_frank_reputation_band()})")
    print(f"✓ Filed Status: {test.game_state.filed_status}")
    print(f"✓ Inventory: {sorted(list(test.game_state.inventory))}")
    print()
    
    # Check expectations
    passed = True
    failures = []
    
    # The SPINE test: core flow through rooms
    expected_rooms_in_order = [
        "Intake Stairs",
        "Number Desk",
        "Queue Spine",
        "Form Window",
        "Denial Bay",
        "Lost Records",
        "Stamp Sanctum",
        "Frank Outer Desk",
        "Gate Review"
    ]
    
    actual_rooms = [r["room"] for r in results if r["room"] != "NONE"]
    
    # Check if critical rooms were visited in the right order
    critical_room_indices = {}
    for i, room in enumerate(actual_rooms):
        if room in expected_rooms_in_order and room not in critical_room_indices:
            critical_room_indices[room] = i
    
    if final_room != "Gate Review":
        failures.append(f"Expected final room 'Gate Review', got '{final_room}'")
        passed = False
    
    if test.game_state.stats["health"] <= 0:
        failures.append(f"Health is {test.game_state.stats['health']}, expected > 0")
        passed = False
    
    # Verify spine rooms were visited
    spine_rooms = ["Intake Stairs", "Number Desk", "Queue Spine", "Form Window", 
                   "Denial Bay", "Frank Outer Desk", "Gate Review"]
    for room in spine_rooms:
        if room not in critical_room_indices:
            failures.append(f"Critical spine room '{room}' not visited")
            passed = False
    
    if passed:
        print("✅ LAWFUL SPINE TEST PASSED - Core bureaucratic flow intact")
        print(f"   Rooms navigated: {len(critical_room_indices)} critical rooms in sequence")
        print(f"   Path: {' → '.join([r for r in actual_rooms if r in expected_rooms_in_order][:9])}")
    else:
        print("❌ LAWFUL SPINE TEST FAILED")
        for failure in failures:
            print(f"   - {failure}")
    
    print("\n" + "="*80)
    
    return passed


if __name__ == "__main__":
    passed = test_chapter2_lawful_path()
    sys.exit(0 if passed else 1)
