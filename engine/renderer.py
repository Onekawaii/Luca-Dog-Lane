from __future__ import annotations

import sys
import textwrap
import time

WIDTH = 78


def wrap(s: str) -> str:
    return "\n".join(textwrap.wrap(s, WIDTH))


class C:
    TITLE = "\033[95m"
    SUB = "\033[94m"
    BODY = "\033[97m"
    DIM = "\033[90m"
    EXIT = "\033[92m"
    OBJ = "\033[96m"
    WARN = "\033[91m"
    END = "\033[0m"

    @classmethod
    def enabled(cls) -> bool:
        return sys.stdout.isatty()


def color(code: str, text: str) -> str:
    if not C.enabled():
        return text
    return f"{code}{text}{C.END}"


class Renderer:
    def __init__(self, game_state):
        self.game_state = game_state

    def hr(self) -> str:
        return "-" * WIDTH

    def banner(self) -> None:
        print(self.hr())
        print(color(C.TITLE, wrap("🐔 HIVE-LATTICE BARD — Full Context Mode")))
        print(self.hr())

    def say(self, text: str) -> None:
        print(wrap(text))
        print()

    def error(self, text: str) -> None:
        print(color(C.WARN, wrap(text)))
        print()

    def _animate(self, style: str) -> None:
        if not C.enabled():
            return
        frames = {
            "drip": ["   .", "   o", "   O", "   |"],
            "neon": ["[ neon ]", "[ NEON ]", "[ nEoN ]"],
            "escalator": ["===>", " ->>", "  =>"],
            "flicker": ["[glass]", "[GLASS]", "[glass]"],
            "queue": ["000", "001", "000"],
            "void": ["   ", " . ", "   "],
        }.get(style)
        if not frames:
            return
        for frame in frames[:2]:
            print(color(C.DIM, frame), end="\r")
            time.sleep(0.06)
        print(" " * 10, end="\r")

    def render_room(self, room_id: str, force_full: bool = False) -> None:
        room = self.game_state.world[room_id]
        visited_before = self.game_state.has_visited(room_id)

        print(color(C.TITLE, f"[ {room['title']} ]"))
        if room.get("tagline"):
            print(color(C.SUB, wrap(room["tagline"])))
        print()

        self._animate(room.get("animation", ""))

        primary = room["repeat_desc"] if visited_before and not force_full else room["first_desc"]
        print(wrap(primary))
        print()
        print(color(C.BODY, wrap(room["long_desc"])))
        print()

        objects = sorted(obj["name"] for obj in room.get("objects", {}).values())
        if objects:
            print(color(C.OBJ, "You notice: " + ", ".join(objects)))

        exits = ", ".join(room.get("exits", {}).keys())
        print(color(C.EXIT, f"Exits: {exits}"))
        print()

        self.game_state.mark_visited(room_id)

    def render_inventory(self) -> None:
        if not self.game_state.inventory:
            print("Inventory: empty\n")
            return
        print("Inventory: " + ", ".join(self.game_state.inventory) + "\n")

    def render_ambient(self, verb: str, text: str) -> None:
        print(color(C.DIM, verb.capitalize() + ":"))
        print(wrap(text))
        print()

    def render_object(self, name: str, desc: str) -> None:
        print(color(C.OBJ, name.title()))
        print(wrap(desc))
        print()
