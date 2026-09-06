#!/usr/bin/env python3
"""
test_chapter3_lawful_path.py - Chapter 3 lawful route spine test (deterministic).

Asserts:
- deterministic state transitions (no flavor text assertions)
- surrender path exists
- reclaim path exists
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


class Chapter3LawfulTest(unittest.TestCase):
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

    def test_chapter3_lawful_release_clean(self):
        # Start in Ch3 room 01
        self.assertEqual(self.game_state.room["id"], "ch03_room_01")
        self.assertIsNone(self.game_state.chapter3_release_status)

        # Acquire an item to surrender from the room
        self.exec("take receipt")
        self.assertIn("receipt", self.game_state.inventory)

        # File the loss report
        self.exec("report loss")
        self.assertTrue(self.game_state.loss_report_filed)
        self.assertGreaterEqual(self.game_state.loss_debt, 1)

        # Surrender a specific item (surrender path)
        self.exec("surrender receipt")
        self.assertNotIn("receipt", self.game_state.inventory)
        self.assertIn("receipt", self.game_state.surrendered_items)

        # Debt should be cleared for lawful reclaim
        self.assertEqual(self.game_state.loss_debt, 0)

        # Reclaim that item (reclaim path)
        self.exec("reclaim receipt")
        self.assertIn("receipt", self.game_state.inventory)
        self.assertIn("receipt", self.game_state.reclaimed_losses)
        self.assertNotIn("receipt", self.game_state.surrendered_items)

        # End status must be a valid release status and deterministic
        self.assertIn(
            self.game_state.chapter3_release_status,
            {"released_clean", "released_with_loss", "retained_for_review"},
        )
        self.assertEqual(self.game_state.chapter3_release_status, "released_clean")


if __name__ == "__main__":
    unittest.main()

