#!/usr/bin/env python3
# main.py - Enhanced entry point with rendering + context layer

import sys
import textwrap
import time
import os

# ---------- Console Fix ----------
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
    return "-" * WIDTH

def clear():
    os.system("clear")

# ---------- ANSI COLORS ----------
class C:
    TITLE = "\033[95m"
    SUB = "\033[94m"
    BODY = "\033[97m"
    EXIT = "\033[92m"
    WARN = "\033[91m"
    DIM = "\033[90m"
    END = "\033[0m"

# ---------- SIMPLE ANIMATIONS ----------
def drip_animation(frames=2):
    seq = [" . ", " o ", " O ", " | "]
    for i in range(frames):
        print(f"{C.DIM}[drip {seq[i % len(seq)]}]{C.END}", end="\r")
        time.sleep(0.1)

# ---------- ENGINE IMPORTS ----------
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

        self.game_state.load_world_data()

        from engine.validate_content import ContentValidator
        validator = ContentValidator()
        if not validator.validate_all():
            print("Content validation failed.")
            validator.report()
            exit(1)

    # ---------- SMART RENDER ----------
    def render(self, text):
        """
        Intercepts engine output and upgrades it visually.
        """
        if "[" in text and "]" in text:
            # Try to extract location name
            try:
                raw = text.split("[")[1].split("]")[0]

                # CLEAN NAME (remove chXX_)
                clean = raw.split("_", 1)[-1].replace("_", " ").title()

                print()
                print(f"{C.TITLE}[ {clean} ]{C.END}")
                drip_animation()

                # Remove raw header from body
                body = text.split("]", 1)[1].strip()

                print(f"{C.SUB}{wrap(body)}{C.END}\n")
                return
            except:
                pass

        # fallback
        print(wrap(text))
        print()

    def say(self, *lines):
        for line in lines:
            self.render(line)

    def banner(self):
        print(hr())
        self.say("🐔 HIVE-LATTICE BARD — Text Adventure")
        print(hr())

    def run(self):
        self.banner()
        self.say("Welcome to the Hive-Lattice. Type 'help' for commands.")

        self.command_router.handle_look()

        while True:
            try:
                user_input = input("> ").strip()
                if not user_input:
                    continue

                intent = self.parser.parse_input(user_input)
                response = self.command_router.route_intent(intent)

                self.say(response)

                if intent["intent"] == "QUIT":
                    break

                if self.progression.check_win_condition():
                    self.say("You have reached the Core. The lattice acknowledges you.")
                    break

                failure = self.progression.check_failure_conditions()
                if failure:
                    self.say(f"You have failed: {failure}")
                    break

                event = self.random_events.check_random_event()
                if event:
                    self.say(event)

            except KeyboardInterrupt:
                self.say("Interrupted. Type 'quit' to exit.")
            except Exception as e:
                self.say(f"Error: {e}")

if __name__ == "__main__":
    Game().run()