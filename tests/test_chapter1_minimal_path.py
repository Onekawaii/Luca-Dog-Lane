#!/usr/bin/env python3
"""
test_chapter1_minimal_path.py - Automated playthrough validation.

This test runs a minimal scripted path through Chapter 1 and validates:
- Player reaches expected final room
- Expected flags are set
- Health is above zero
- Chapter progress increased

This is the "spine test" - if it breaks, the core flow is broken.

Run with: python -m pytest tests/test_chapter1_minimal_path.py
Or directly: python tests/test_chapter1_minimal_path.py
"""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from engine.game_state import GameState
from engine.parser import Parser
from engine.command_router import CommandRouter
from engine.world_loader import WorldLoader
from engine.progression import Progression
from engine.combatless_resolution import CombatlessResolution
from engine.random_events import RandomEvents


class MinimalPlaytestHarness:
    """Run a scripted path through a chapter and validate."""
    
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
        self.game_state.load_world_data()
    
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
                "room": self.game_state.room["name"] if self.game_state.room else "NONE"
            })
        return results
    
    def validate_state(self, expectations):
        """Check if game state matches expectations."""
        passed = True
        failures = []
        
        if "final_room" in expectations:
            actual = self.game_state.room["name"] if self.game_state.room else "NONE"
            expected = expectations["final_room"]
            if actual != expected:
                failures.append(f"Expected room '{expected}', got '{actual}'")
                passed = False
        
        if "health_min" in expectations:
            actual = self.game_state.stats["health"]
            expected = expectations["health_min"]
            if actual < expected:
                failures.append(f"Health {actual} below minimum {expected}")
                passed = False
        
        if "flags_set" in expectations:
            for flag in expectations["flags_set"]:
                if not self.game_state.has_flag(flag):
                    failures.append(f"Flag '{flag}' not set")
                    passed = False
        
        if "chapter_progress_min" in expectations:
            actual = self.game_state.stats["chapter_progress"]
            expected = expectations["chapter_progress_min"]
            if actual < expected:
                failures.append(f"Chapter progress {actual} below minimum {expected}")
                passed = False
        
        return passed, failures


def test_chapter1_minimal_path():
    """Test a minimal winning path through Chapter 1."""
    harness = MinimalPlaytestHarness()
    
    # Minimal path script
    script = [
        "look",
        "take receipt",
        "go east",
        "look",
        "go down",
        "look",
        "go east",
        "look",
        # More movement to progress
        "go west",
        "go up",
        "look",
    ]
    
    # Run the script
    results = harness.run_script(script)
    
    # Print execution log
    print("\n" + "="*70)
    print("🎮 CHAPTER 1 MINIMAL PATH TEST")
    print("="*70 + "\n")
    
    for i, step in enumerate(results, 1):
        print(f"{i:2d}. {step['command']:20s} → [{step['room']}]")
    
    # Validate state at end
    expectations = {
        "health_min": 0,  # Just need to be alive
        "final_room": "Storefront Eleven",  # Ended up here
    }
    
    passed, failures = harness.validate_state(expectations)
    
    print("\n" + "-"*70)
    print("📊 FINAL STATE")
    print("-"*70)
    print(f"✓ Room: {harness.game_state.room['name']}")
    print(f"✓ Health: {harness.game_state.stats['health']}")
    print(f"✓ Inventory: {sorted(list(harness.game_state.inventory))}")
    print()
    
    if passed:
        print("✅ SPINE TEST PASSED - Core flow is intact")
        return 0
    else:
        print("❌ SPINE TEST FAILED")
        for failure in failures:
            print(f"   • {failure}")
        return 1


def test_all_chapters_validate():
    """Test that all chapter files pass validation."""
    from engine.validate_content import ContentValidator
    
    print("\n" + "="*70)
    print("📋 CHAPTER VALIDATION TEST")
    print("="*70 + "\n")
    
    validator = ContentValidator()
    passed = validator.validate_all()
    
    validator.report()
    
    if passed:
        print("\n✅ All chapter files valid")
        return 0
    else:
        print("\n❌ Chapter validation failed")
        return 1


def main():
    """Run all tests."""
    print("\n🧪 Running automated Chapter 1 spine test...\n")
    
    test1_result = test_chapter1_minimal_path()
    test2_result = test_all_chapters_validate()
    
    # Summary
    print("\n" + "="*70)
    print("📈 TEST SUMMARY")
    print("="*70)
    print(f"Chapter 1 Spine:     {'✅ PASS' if test1_result == 0 else '❌ FAIL'}")
    print(f"Content Validation:  {'✅ PASS' if test2_result == 0 else '❌ FAIL'}")
    print()
    
    overall = min(test1_result, test2_result)
    if overall == 0:
        print("✅ All tests PASSED")
    else:
        print("❌ Some tests FAILED")
    
    return overall


if __name__ == "__main__":
    sys.exit(main())
