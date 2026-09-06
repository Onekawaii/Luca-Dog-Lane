#!/usr/bin/env python3
# test_parser.py - Unit tests for parser

import unittest
from engine.parser import Parser
from engine.game_state import GameState

class TestParser(unittest.TestCase):
    def setUp(self):
        self.game_state = GameState()
        self.parser = Parser(self.game_state)

    def test_look_command(self):
        intent = self.parser.parse_input("look")
        self.assertEqual(intent["intent"], "LOOK")

    def test_move_command(self):
        intent = self.parser.parse_input("go east")
        self.assertEqual(intent["intent"], "MOVE")
        self.assertEqual(intent["direction"], "east")

    def test_take_command(self):
        intent = self.parser.parse_input("take receipt")
        self.assertEqual(intent["intent"], "TAKE")
        self.assertEqual(intent["item"], "receipt")

    def test_eat_random_item(self):
        intent = self.parser.parse_input("eat random item")
        self.assertEqual(intent["intent"], "EAT_RANDOM_ITEM")

    def test_unknown_command(self):
        intent = self.parser.parse_input("xyzzy")
        self.assertEqual(intent["intent"], "UNKNOWN")

if __name__ == '__main__':
    unittest.main()