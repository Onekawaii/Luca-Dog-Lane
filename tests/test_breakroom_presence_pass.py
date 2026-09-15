"""Contract coverage for the breakroom presence/audio pass."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / "game_godot/scenes/fps/FirstPersonBreakroom.tscn"
ROOM = ROOT / "game_godot/scripts/fps/FirstPersonBreakroom.gd"
KEITH = ROOT / "game_godot/scripts/fps/KeithAmbientWorker.gd"
AUDIO = ROOT / "game_godot/assets/audio"


class TestBreakroomPresencePass(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scene = SCENE.read_text(encoding="utf-8")
        cls.room = ROOM.read_text(encoding="utf-8")
        cls.keith = KEITH.read_text(encoding="utf-8")

    def test_generated_interaction_audio_exists(self):
        for name in ("coffee_switch.wav", "coffee_brew.wav", "fridge_hinge.wav"):
            path = AUDIO / name
            self.assertTrue(path.exists(), name)
            self.assertGreater(path.stat().st_size, 1000, name)

    def test_audio_players_are_wired(self):
        self.assertIn('CoffeeSwitchSFX', self.scene)
        self.assertIn('CoffeeBrewSFX', self.scene)
        self.assertIn('FridgeHingeSFX', self.scene)
