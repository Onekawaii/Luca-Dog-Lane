import wave
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "game_godot/assets/audio"
AUDIO_MANAGER = ROOT / "game_godot/scripts/audio/AudioManager.gd"
ATMOSPHERE = ROOT / "game_godot/scripts/runtime/AtmosphereDirector.gd"
BREAKROOM = ROOT / "game_godot/scripts/fps/FirstPersonBreakroom.gd"
RUNTIME = ROOT / "game_godot/scripts/procgen/HiveProcGenRuntime.gd"
HUD = ROOT / "game_godot/scripts/fps/FirstPersonHUD.gd"
HUD_SCENE = ROOT / "game_godot/scenes/fps/FirstPersonHUD.tscn"
GAME_RUNTIME = ROOT / "game_godot/scripts/runtime/GameRuntime.gd"


def wav_peak(path: Path) -> float:
    with wave.open(str(path), "rb") as handle:
        raw = handle.readframes(handle.getnframes())
    samples = [int.from_bytes(raw[i:i+2], "little", signed=True) for i in range(0, len(raw), 2)]
    return max(abs(v) for v in samples) / 32767.0


class FeedbackAudioInventoryContractTests(unittest.TestCase):
    def test_breakroom_audio_stops_at_physical_threshold(self):
        runtime = RUNTIME.read_text(encoding="utf-8")
        self.assertIn("BREAKROOM_AUDIO_EXIT_X := 8.5", runtime)
        self.assertIn("_update_audio_boundary()", runtime)
        self.assertIn("_player.global_position.x <= BREAKROOM_AUDIO_EXIT_X", runtime)
        self.assertNotIn("_set_breakroom_audio_active(level_index < 0)", runtime)
    def test_containment_uses_dedicated_quiet_zipper(self):
        manager = AUDIO_MANAGER.read_text(encoding="utf-8")
        atmosphere = ATMOSPHERE.read_text(encoding="utf-8")
        breakroom = BREAKROOM.read_text(encoding="utf-8")
        runtime = GAME_RUNTIME.read_text(encoding="utf-8")
        self.assertIn('"bag_zip": "res://assets/audio/bag_zip.wav"', manager)
        self.assertIn("func play_bag_zip()", manager)
        self.assertIn("AudioManager.play_bag_zip()", breakroom)
        self.assertNotIn("play_waterdrop", atmosphere)
        self.assertNotIn("AudioManager.play_item_pickup()\n\t\tEventBus.notification_posted.emit(res", runtime)
        self.assertTrue((AUDIO / "bag_zip.wav").exists())
        self.assertLess(wav_peak(AUDIO / "bag_zip.wav"), 0.10)

    def test_keith_dialogue_acknowledges_player_and_state(self):
        source = BREAKROOM.read_text(encoding="utf-8")
        self.assertIn("Hey — yeah, you.", source)
        self.assertIn("You're back. Good", source)
        self.assertIn("You got it sealed? Good.", source)
        self.assertNotIn('"You already have the bag."', source)
    def test_first_person_inventory_is_real_overlay(self):
        scene = HUD_SCENE.read_text(encoding="utf-8")
        script = HUD.read_text(encoding="utf-8")
        for token in (
            'name="InventoryButton"', 'name="InventoryPanel"',
            'name="Items"', 'name="Detail"', 'name="CloseInventoryButton"',
        ):
            self.assertIn(token, scene)
        self.assertIn("func _toggle_inventory()", script)
        self.assertIn("func _refresh_inventory_panel()", script)
        self.assertIn("func _select_inventory_item(item: Dictionary)", script)
        self.assertIn("btn.icon = load(icon_path) as Texture2D", script)
        self.assertIn("READY FOR USE", script)

    def test_breakroom_shutdown_stops_persistent_local_noise(self):
        manager = AUDIO_MANAGER.read_text(encoding="utf-8")
        breakroom = BREAKROOM.read_text(encoding="utf-8")
        self.assertIn("pulse_player.stop()", manager)
        self.assertIn("keith_worker.pause_cleaning()", breakroom)
        self.assertIn("coffee_brew_sfx.stop()", breakroom)


if __name__ == "__main__":
    unittest.main()
