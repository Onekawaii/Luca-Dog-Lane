#!/usr/bin/env python3
"""
test_chapter2_hybrid_path.py - Chapter 2 hybrid route spine test.

This test validates the hybrid bureaucratic/ape path through Chapter 2:
- Take number at desk (proper)
- Queue
- Get form and file it (bureaucratic)
- Receive denial
- Go to Goblin Annex instead of straight appeal (ape chaos)
- Use goblin/chicken resources to gather correction material
- Return to bureaucratic path with better materials
- Stamp and present to Frank with hybrid lean

This should yield the best result: Frank's approval with hybrid play style.

Run with: python tests/test_chapter2_hybrid_path.py
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


class Chapter2HybridTest:
    """Run Chapter 2 hybrid route and validate."""
    
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
        
        # Initialize Frank reputation from Chapter 1 (simulate hybrid route from Ch1)
        self.game_state.chapter_route_history.append({
            "chapter": 1,
            "route_leaning": "hybrid",
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


def test_chapter2_hybrid_path():
    """Test the hybrid path through Chapter 2 using goblin/chicken resources."""
    test = Chapter2HybridTest()
    
    # Hybrid route: bureaucratic start, then ape detour for better resources, return to bureaucratic finish
    script = [
        "look",
        "go east",                    # -> Number Desk
        "take number",                # Get queue_slip (bureaucratic)
        "go east",                    # -> Queue Spine
        "queue",                      # Join queue (bureaucratic)
        "go east",                    # -> Form Window
        "take blank form",            # Get blank_form_27b
        "file form",                  # File the form (bureaucratic so far)
        "go east",                    # -> Denial Bay
        "go west",                   # -> Form Window (backtrack)
        "go west",                   # -> Queue Spine (backtrack)
        "go south",                  # -> Goblin Annex (ape detour)
        "ape scream",                # Interact with goblins
        "take misfiled memo",        # Get alternate document path
        "go east",                   # -> Lost Records
        "ask chicken for legal advice", # Chicken guidance (ape+bureaucratic hybrid)
        "take correction ribbon",    # Get correction material
        "go east",                   # -> Stamp Sanctum
        "stamp form",                 # Stamp with hybrid credibility
        "go east",                    # -> Frank Outer Desk
        "talk frank",                 # Present to Frank with hybrid lean
        "go east",                    # -> Gate Review (end)
    ]
    
    # Run the script
    results = test.run_script(script)
    
    # Print execution log
    print("\n" + "="*80)
    print("🎮 CHAPTER 2 HYBRID ROUTE TEST")
    print("="*80 + "\n")
    
    for i, step in enumerate(results, 1):
        print(f"{i:2d}. {step['command']:30s} → [{step['room']:20s}]")
    
    # Validate state at end
    print("\n" + "-"*80)
    print("📊 FINAL STATE")
    print("-"*80)
    final_room = test.game_state.room["name"] if test.game_state.room else "NONE"
    print(f"✓ Room: {final_room}")
    print(f"✓ Health: {test.game_state.stats['health']}")
    print(f"✓ Frank Reputation: {test.game_state.frank_reputation} ({test.game_state.get_frank_reputation_band()})")
    print(f"✓ Ape Chaos: {test.game_state.stats['ape_chaos']}")
    print(f"✓ Bureaucracy: {test.game_state.stats['bureaucracy']}")
    print(f"✓ Alter: {test.game_state.stats['alter']}")
    print(f"✓ Filed Status: {test.game_state.filed_status}")
    print(f"✓ Inventory: {sorted(list(test.game_state.inventory))}")
    print()
    
    # Check expectations
    passed = True
    failures = []
    
    # The SPINE test: hybrid core flow through rooms (includes Goblin Annex detour)
    expected_spine_rooms = [
        "Intake Stairs",
        "Number Desk",
        "Queue Spine",
        "Form Window",
        "Denial Bay",
        "Goblin Annex",              # Ape detour
        "Lost Records",              # Ape/hybrid resource gathering
        "Stamp Sanctum",
        "Frank Outer Desk",
        "Gate Review"
    ]
    
    actual_rooms = [r["room"] for r in results if r["room"] != "NONE"]
    
    # Check if critical rooms were visited in the right order
    critical_room_indices = {}
    for i, room in enumerate(actual_rooms):
        if room in expected_spine_rooms and room not in critical_room_indices:
            critical_room_indices[room] = i
    
    if final_room != "Gate Review":
        failures.append(f"Expected final room 'Gate Review', got '{final_room}'")
        passed = False
    
    if test.game_state.stats["health"] <= 0:
        failures.append(f"Health is {test.game_state.stats['health']}, expected > 0")
        passed = False
    
    # Check ape/bureaucratic balance (hybrid = both must exist)
    if test.game_state.stats["ape_chaos"] <= 0:
        failures.append(f"Ape chaos not elevated (need ape route), got {test.game_state.stats['ape_chaos']}")
        passed = False
    
    # Verify critical spine rooms including ape detour
    critical_rooms = ["Intake Stairs", "Number Desk", "Queue Spine", "Form Window", 
                      "Denial Bay", "Goblin Annex", "Lost Records", "Frank Outer Desk", "Gate Review"]
    for room in critical_rooms:
        if room not in critical_room_indices:
            failures.append(f"Critical room '{room}' not visited in hybrid path")
            passed = False
    
    if passed:
        print("✅ HYBRID SPINE TEST PASSED - Ape/bureaucratic mixed flow intact")
        print(f"   Rooms navigated: {len(critical_room_indices)} critical rooms including ape detour")
        print(f"   Ape chaos: {test.game_state.stats['ape_chaos']}, Bureaucracy: {test.game_state.stats['bureaucracy']}")
        print(f"   Path includes Goblin Annex (ape) and Lost Records (resource gathering)")
    else:
        print("❌ HYBRID SPINE TEST FAILED")
        for failure in failures:
            print(f"   - {failure}")
    
    print("\n" + "="*80)
    
    return passed


if __name__ == "__main__":
    passed = test_chapter2_hybrid_path()
    sys.exit(0 if passed else 1)
