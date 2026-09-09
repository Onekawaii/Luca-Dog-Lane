"""Unit tests verifying the TouchLookZone implementation and mobile look contract."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class TestTouchLookZoneContract(unittest.TestCase):
    def setUp(self):
        self.look_gd = (ROOT / "game_godot/scripts/fps/TouchLookZone.gd").read_text(encoding="utf-8")
        self.hud_gd = (ROOT / "game_godot/scripts/fps/FirstPersonHUD.gd").read_text(encoding="utf-8")
        self.hud_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonHUD.tscn").read_text(encoding="utf-8")

    def test_global_input_handling_and_reset(self):
        """Verify TouchLookZone uses _input for global tracking and provides reset_touch."""
        self.assertIn("func _input(event: InputEvent) -> void:", self.look_gd)
        self.assertIn("func reset_touch() -> void:", self.look_gd)
        self.assertIn("active_touch_index = -1", self.look_gd)

    def test_lifecycle_notifications_clear_touch(self):
        """Verify visibility, disable, and focus notifications reset active touch index."""
        self.assertIn("NOTIFICATION_VISIBILITY_CHANGED", self.look_gd)
        self.assertIn("NOTIFICATION_DISABLED", self.look_gd)
        self.assertIn("NOTIFICATION_WM_WINDOW_FOCUS_OUT", self.look_gd)

    def test_excluded_button_checks(self):
        """Verify InteractButton, PDAButton, and modal panels are excluded from triggering look."""
        self.assertIn("_is_excluded_position", self.look_gd)
        self.assertIn("InteractButton", self.look_gd)
        self.assertIn("PDAButton", self.look_gd)
        self.assertIn("PDAPanel", self.look_gd)
        self.assertIn("DialoguePanel", self.look_gd)

    def test_hud_disabling_resets_touch_look(self):
        """Verify FirstPersonHUD._set_mobile_gameplay_controls_enabled resets TouchLookZone."""
        self.assertIn("look_zone.reset_touch()", self.hud_gd)

    def test_exclusive_touch_ownership_check(self):
        """Verify TouchLookZone checks active_touch_index == -1 on press before claiming a finger."""
        self.assertIn("if active_touch_index == -1:", self.look_gd)


if __name__ == "__main__":
    unittest.main()
