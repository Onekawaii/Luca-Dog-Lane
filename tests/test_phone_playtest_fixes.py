"""Regression tests for Phone Playtest Fix Batch:
1. Interaction prompt hidden during DialoguePanel or PDAPanel open.
2. Platform-aware control labels (Android/mobile removes [P], [E/A], WASD, mouse, Shift, F5/F9).
3. Notification toast positioning cleared from Current Objective.
4. PDA quantum diagnostic field renamed to 'Last confirmed anchor'.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class TestPhonePlaytestFixBatch(unittest.TestCase):
    def setUp(self):
        self.hud_gd = (ROOT / "game_godot/scripts/fps/FirstPersonHUD.gd").read_text(encoding="utf-8")
        self.hud_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonHUD.tscn").read_text(encoding="utf-8")
        self.interactable_gd = (ROOT / "game_godot/scripts/fps/FirstPersonInteractable.gd").read_text(encoding="utf-8")
        self.overlays_gd = (ROOT / "game_godot/scripts/ui/Overlays.gd").read_text(encoding="utf-8")

    def test_fix1_interaction_prompt_hidden_during_modals(self):
        """Verify prompt visibility is suppressed when dialogue or PDA is active."""
        self.assertIn("_update_prompt_visibility", self.hud_gd)
        self.assertIn("prompt_label.visible = not modal_open", self.hud_gd)
        # Check that dialogue open/close and PDA toggle update prompt visibility
        self.assertIn("_on_dialogue_requested", self.hud_gd)
        self.assertIn("_close_dialogue", self.hud_gd)
        self.assertIn("_toggle_pda", self.hud_gd)
        self.assertTrue(self.hud_gd.count("_update_prompt_visibility()") >= 4)

    def test_fix2_platform_aware_control_labels(self):
        """Verify mobile platforms strip keyboard/mouse artifacts and present touch labels."""
        self.assertIn("_apply_platform_labels", self.hud_gd)
        self.assertIn("pda_button.text = \"PDA\"", self.hud_gd)
        self.assertIn("hint_label.text = \"Touch: Left stick move • Drag to look • INTERACT button • Save/Load buttons\"", self.hud_gd)
        
        # Verify prompt formatter cleans desktop prefix strings
        self.assertIn("_format_prompt", self.hud_gd)
        self.assertIn("cleaned.replace(\"[E / A] \", \"\")", self.hud_gd)
        self.assertIn("cleaned.replace(\"[P] \", \"\")", self.hud_gd)

        # Verify interactable script also has mobile awareness
        self.assertIn("get_interaction_prompt", self.interactable_gd)
        self.assertIn("cleaned.replace(\"[E / A] \", \"\")", self.interactable_gd)

        # Verify Overlays script removes F5/F9 shortcut strings on mobile
        self.assertIn("save_btn.text = \"Save State (Slot 1)\"", self.overlays_gd)
        self.assertIn("load_btn.text = \"Load State (Slot 1)\"", self.overlays_gd)

    def test_fix3_notification_toasts_never_overlap_objective(self):
        """Verify NotificationPanel Y offset sits clear below ObjectivePanel."""
        self.assertIn('offset_top = 120.0', self.hud_tscn)
        self.assertIn('offset_bottom = 174.0', self.hud_tscn)
        # Objective panel reaches Y=105, notification starts at Y=120
        self.assertIn('offset_bottom = 105.0', self.hud_tscn)

    def test_fix4_pda_quantum_anchor_renamed(self):
        """Verify PDA quantum diagnostic string uses 'Last confirmed anchor' instead of 'Confirmed'."""
        self.assertIn("Last confirmed anchor: %s", self.hud_gd)
        self.assertNotIn("Confirmed: %s", self.hud_gd)


if __name__ == "__main__":
    unittest.main()
