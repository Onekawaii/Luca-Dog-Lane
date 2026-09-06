#!/usr/bin/env python3
"""
test_chapter3_hybrid_path.py - Chapter 3 hybrid route spine test (deterministic).

Hybrid = obey the process enough to file, but introduce a deliberate complication
via catalogue that creates a retained_for_review outcome.

Asserts:
- deterministic state transitions (no flavor text assertions)
- ends in a valid release status
"""

import sys
import os
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from engine.game_state import GameState
from engine.parser import Parser
from engine.command_router import CommandRouter
from engine.world_loader import WorldLoader
from engine.progression import Progression
from engine.combatless_resolution import CombatlessResolution
from engine.random_events import RandomEvents


class Chapter3HybridTest(unittest.TestCase):
    def setUp(self):
        self.game_state = GameState()
        self.parser = Parser(self.game_state)
        self.world_loader = WorldLoader(self.game_state)
        self.progression = Progression(self.game_state)
        self.combatless_resolution = CombatlessResolution(self.game_state)
        self.random_events = RandomEvents(self.game_state)
        self.router = CommandRouter(
            self.game_state,
            self.parser,
            self.world_loader,
            self.progression,
            self.combatless_resolution,
            self.random_events,
        )

        self.game_state.load_world_data("content")
        self.game_state.chapter = 3
        self.game_state.level_index = 1
        self.game_state.room = self.game_state.rooms.get("ch03_room_01")

        self.assertIsNotNone(self.game_state.room, "Chapter 3 starting room not found")

    def exec(self, cmd):
        intent = self.parser.parse_input(cmd)
        return self.router.route_intent(intent)

    def test_chapter3_hybrid_retained_for_review(self):
        self.assertEqual(self.game_state.room["id"], "ch03_room_01")

        # Grab an item to use in the department flow.
        self.exec("take receipt")
        self.assertIn("receipt", self.game_state.inventory)

        # File report (starts debt)
        self.exec("report loss")
        self.assertTrue(self.game_state.loss_report_filed)

        # Surrender item to clear the initial debt
        self.exec("surrender receipt")
        self.assertEqual(self.game_state.loss_debt, 0)
        self.assertIn("receipt", self.game_state.surrendered_items)

        # Hybrid complication: catalogue adds debt deterministically.
        self.exec("catalogue")
        self.assertEqual(self.game_state.loss_debt, 1)

        # Attempt reclaim with unresolved debt -> retained_for_review (deterministic end state)
        self.exec("reclaim receipt")
        self.assertEqual(self.game_state.chapter3_release_status, "retained_for_review")

        # Must be a valid end status
        self.assertIn(
            self.game_state.chapter3_release_status,
            {"released_clean", "released_with_loss", "retained_for_review"},
        )


if __name__ == "__main__":
    unittest.main()

