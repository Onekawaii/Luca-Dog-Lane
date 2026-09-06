#!/usr/bin/env python3
# random_events.py - Handle random events and encounters

import random

class RandomEvents:
    def __init__(self, game_state):
        self.game_state = game_state

    def check_random_event(self):
        """Check for random events on room enter or command."""
        if random.random() < 0.1:  # 10% chance
            return self.trigger_random_event()
        return None

    def trigger_random_event(self):
        """Trigger a random event."""
        events = [
            "A chicken appears and pecks at your shoe.",
            "The lights flicker in a pattern that might be Morse code.",
            "You hear distant paperwork shuffling.",
            "A security drone hovers briefly then leaves.",
            "The floor vibrates with the rhythm of bureaucracy."
        ]
        return random.choice(events)