#!/usr/bin/env python3
# test_room_graph.py - Test room connectivity and reachability

import unittest
from engine.game_state import GameState

class TestRoomGraph(unittest.TestCase):
    def setUp(self):
        self.game_state = GameState()
        self.game_state.load_world_data()

    def test_starting_room_exists(self):
        self.assertIn("ch01_entry_mall", self.game_state.rooms)

    def test_all_rooms_reachable(self):
        # Simple BFS to check connectivity for Chapter 1
        chapter_rooms = {rid: room for rid, room in self.game_state.rooms.items() if room["chapter"] == 1}
        visited = set()
        queue = ["ch01_entry_mall"]
        visited.add("ch01_entry_mall")
        
        while queue:
            current = queue.pop(0)
            for direction, dest in self.game_state.rooms[current]["exits"].items():
                if dest in chapter_rooms and dest not in visited:
                    visited.add(dest)
                    queue.append(dest)
        
        # Check that all Chapter 1 rooms are visited
        all_rooms = set(chapter_rooms.keys())
        self.assertEqual(visited, all_rooms)

if __name__ == '__main__':
    unittest.main()