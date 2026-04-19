#!/usr/bin/env python3
# main.py - Main entry point for Hive-Lattice Bard

import sys
import textwrap

# Fix Windows console encoding
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except:
        pass

WIDTH = 78

def wrap(s):
    return "\n".join(textwrap.wrap(s, WIDTH))

def hr():
    return "-"*WIDTH

# Import engine components
from engine.game_state import GameState
from engine.parser import Parser
from engine.command_router import CommandRouter
from engine.world_loader import WorldLoader
from engine.progression import Progression
from engine.combatless_resolution import CombatlessResolution
from engine.random_events import RandomEvents
from engine.save_system import SaveSystem

class Game:
    def __init__(self):
        self.game_state = GameState()
        self.parser = Parser(self.game_state)
        self.world_loader = WorldLoader(self.game_state)
        self.progression = Progression(self.game_state)
        self.combatless_resolution = CombatlessResolution(self.game_state)
        self.random_events = RandomEvents(self.game_state)
        self.save_system = SaveSystem(self.game_state)
        self.command_router = CommandRouter(
            self.game_state, self.parser, self.world_loader, 
            self.progression, self.combatless_resolution, self.random_events
        )
        
        # Load initial world data
        self.game_state.load_world_data()

        # Validate content before starting
        from engine.validate_content import ContentValidator
        validator = ContentValidator()
        if not validator.validate_all():
            print("Content validation failed. Please fix errors before playing.")
            validator.report()
            exit(1)

    def say(self, *lines):
        for line in lines:
            print(wrap(line))
        print()

    def banner(self):
        print(hr())
        try:
            self.say("🐔 HIVE-LATTICE BARD — Text Adventure (Hugo-like)")
        except UnicodeEncodeError:
            self.say("HIVE-LATTICE BARD — Text Adventure (Hugo-like)")
        print(hr())

    def run(self):
        self.banner()
        self.say("Welcome to the Hive-Lattice. Type 'help' for commands.")
        self.command_router.handle_look()  # Initial look
        
        while True:
            try:
                user_input = input("> ").strip()
                if not user_input:
                    continue
                
                intent = self.parser.parse_input(user_input)
                response = self.command_router.route_intent(intent)
                self.say(response)
                
                # Check for quit
                if intent["intent"] == "QUIT":
                    break
                
                # Check win/loss conditions
                if self.progression.check_win_condition():
                    self.say("You have reached the Core. The lattice acknowledges you.")
                    break
                
                failure = self.progression.check_failure_conditions()
                if failure:
                    self.say(f"You have failed: {failure}")
                    break
                
                # Random events
                event = self.random_events.check_random_event()
                if event:
                    self.say(event)
                    
            except KeyboardInterrupt:
                self.say("Interrupted. Type 'quit' to exit.")
            except Exception as e:
                self.say(f"An error occurred: {e}")

if __name__ == "__main__":
    game = Game()
    game.run()