"""Contracts for the first-person mobile HUD ergonomics overhaul."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HUD_GD = ROOT / "game_godot/scripts/fps/FirstPersonHUD.gd"
HUD_SCENE = ROOT / "game_godot/scenes/fps/FirstPersonHUD.tscn"


class TestMobileHUDOverhaul(unittest.TestCase):
    def setUp(self):
        self.hud_gd = HUD_GD.read_text(encoding="utf-8")
        self.hud_scene = HUD_SCENE.read_text(encoding="utf-8")

    def test_interact_button_is_bottom_centered(self):
        block = self.hud_scene.split('[node name="InteractButton"', 1)[1]
        self.assertIn("anchor_left = 0.5", block)
        self.assertIn("anchor_right = 0.5", block)
        self.assertIn("offset_left = -95.0", block)
        self.assertIn("offset_right = 95.0", block)

    def test_interact_button_has_action_styles(self):
        self.assertIn('Style_interact_pressed', self.hud_scene)
        self.assertIn('Style_interact_disabled', self.hud_scene)
        self.assertIn('theme_override_styles/pressed = SubResource("Style_interact_pressed")', self.hud_scene)

    def test_contextual_action_labels_are_supported(self):
        for expected in ["OPEN", "CLOSE", "TALK", "INSPECT", "PICK UP", "PLACE", "TURN ON", "TURN OFF"]:
            self.assertIn(f'return "{expected}"', self.hud_gd)
        self.assertIn("_action_label_for_prompt", self.hud_gd)

    def test_crosshair_feedback_tracks_actionability(self):
        self.assertIn("CROSSHAIR_IDLE", self.hud_gd)
        self.assertIn("CROSSHAIR_ACTIVE", self.hud_gd)
        self.assertIn("crosshair.modulate = CROSSHAIR_ACTIVE if actionable else CROSSHAIR_IDLE", self.hud_gd)

    def test_inspect_restores_previous_world_prompt(self):
        self.assertIn("pre_inspect_prompt = current_interaction_prompt", self.hud_gd)
        self.assertIn("var restored_prompt := pre_inspect_prompt", self.hud_gd)
        self.assertIn("_on_prompt_changed(restored_prompt)", self.hud_gd)

    def test_input_lock_disables_interaction_feedback(self):
        self.assertIn("gameplay_input_locked = locked", self.hud_gd)
        self.assertIn("interact_button.disabled = not actionable", self.hud_gd)


if __name__ == "__main__":
    unittest.main()
