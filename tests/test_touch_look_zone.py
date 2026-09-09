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


class TestVisualPassIntegrationContract(unittest.TestCase):
    def test_staged_assets_and_provenance_exist(self):
        staging_dir = ROOT / "game_godot/assets/staging/borrowed_visuals"
        self.assertTrue(staging_dir.exists(), "Staging directory exists")
        self.assertTrue((staging_dir / "PROVENANCE.json").exists(), "PROVENANCE.json exists in staging")
        self.assertTrue((staging_dir / "README.md").exists(), "README.md exists in staging")
        self.assertTrue((staging_dir / "AG_VISUAL_PASS_TASK.md").exists(), "AG_VISUAL_PASS_TASK.md exists in staging")
        self.assertTrue((staging_dir / "originals").exists(), "Originals folder exists")
        self.assertTrue((staging_dir / "derived").exists(), "Derived folder exists")

    def test_derived_game_ready_textures_exist(self):
        fps_mats = ROOT / "game_godot/assets/fps/materials"
        fps_props = ROOT / "game_godot/assets/fps/props"
        fps_actors = ROOT / "game_godot/assets/fps/actors"

        self.assertTrue((fps_props / "wetberry_carton_512.png").exists(), "Wetberry carton texture exists")
        self.assertTrue((fps_actors / "keith_uniform_512.png").exists(), "Keith uniform texture exists")
        self.assertTrue((fps_props / "breakroom_fridge_512.png").exists(), "Breakroom fridge texture exists")
        self.assertTrue((fps_props / "coffee_maker_512.png").exists(), "Coffee maker texture exists")
        self.assertTrue((fps_mats / "breakroom_floor_512.png").exists(), "Breakroom floor texture exists")
        self.assertTrue((fps_mats / "breakroom_wall_512.png").exists(), "Breakroom wall texture exists")
        self.assertTrue((fps_mats / "breakroom_table_512.png").exists(), "Breakroom table texture exists")
        self.assertTrue((fps_mats / "pda_arkheo_watermark.png").exists(), "PDA watermark texture exists")
        self.assertTrue((fps_props / "hidden_anomaly_plate_256.png").exists(), "Hidden anomaly plate texture exists")

    def test_breakroom_scene_uses_textured_materials(self):
        breakroom_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonBreakroom.tscn").read_text(encoding="utf-8")
        self.assertIn("wetberry_carton_512.png", breakroom_tscn)
        self.assertIn("keith_uniform_512.png", breakroom_tscn)
        self.assertIn("breakroom_fridge_512.png", breakroom_tscn)
        self.assertIn("coffee_maker_512.png", breakroom_tscn)
        self.assertIn("HiddenAnomalyPlate", breakroom_tscn)

    def test_pda_hud_has_watermark(self):
        hud_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonHUD.tscn").read_text(encoding="utf-8")
        self.assertIn("pda_arkheo_watermark.png", hud_tscn)
        self.assertIn("Watermark", hud_tscn)


if __name__ == "__main__":
    unittest.main()
