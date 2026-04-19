#!/usr/bin/env python3
# test_progression.py - Test chapter progression

import unittest
from engine.game_state import GameState
from engine.progression import Progression

class TestProgression(unittest.TestCase):
    def setUp(self):
        self.game_state = GameState()
        self.progression = Progression(self.game_state)

    def test_chapter_advance(self):
        initial_chapter = self.game_state.chapter
        self.progression.advance_chapter()
        self.assertEqual(self.game_state.chapter, initial_chapter + 1)

    def test_win_condition(self):
        # Set up win condition
        self.game_state.room = {"name": "Core"}
        self.game_state.chapter = 10
        self.assertTrue(self.progression.check_win_condition())

if __name__ == '__main__':
    unittest.main()