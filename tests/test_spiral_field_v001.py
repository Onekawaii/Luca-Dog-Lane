from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SpiralFieldV02Contracts(unittest.TestCase):
    def test_identity_and_exports_are_v02(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/name="Spiral Field"', project)
        self.assertIn('config/version="0.2.3"', project)
        self.assertIn("Spiral-Field-v0.2.3-windows.exe", presets)
        self.assertIn("Spiral-Field-v0.2.3-android.apk", presets)
        self.assertIn('package/unique_name="com.onekawaii.spiralfield"', presets)
        self.assertIn("version/code=5", presets)

    def test_encounter_verbs_are_contextual_not_tool_belt(self):
        tools = json.loads((ROOT / "data" / "tools_v016.json").read_text(encoding="utf-8"))
        self.assertNotIn("act", tools["order"])
        self.assertNotIn("mercy", tools["order"])
        self.assertNotIn("act", tools["tools"])
        self.assertNotIn("mercy", tools["tools"])
        player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        hud = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        director = (ROOT / "scripts" / "systems" / "SpiralWorldDirector.gd").read_text(encoding="utf-8")
        self.assertIn('open_encounter', player)
        self.assertIn('func spiral_choice', player)
        self.assertIn('func open_encounter', hud)
        for verb in ("TALK", "PET", "FEED", "MERCY", "BEHOLD", "AVERT", "TOUCH", "ANSWER", "LISTEN", "HUSH"):
            self.assertIn(verb, director)

    def test_desktop_and_debug_ui_are_separated(self):
        hud = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        self.assertIn('mobile_ui = _is_mobile_platform()', hud)
        self.assertIn('event.keycode == KEY_F3', hud)
        self.assertIn('spawn_button.visible = developer_ui', hud)
        self.assertIn('move_base.visible = mobile_ui', hud)
        self.assertIn('crosshair.visible = not mobile_ui', hud)
        self.assertIn('DEVELOPER SPAWN', hud)

    def test_new_world_identity_replaces_player_facing_luca_map_labels(self):
        maps = json.loads((ROOT / "data" / "maps_v016.json").read_text(encoding="utf-8"))
        labels = {spec["label"] for spec in maps["maps"].values()}
        self.assertIn("THE FIRST FIELD", labels)
        self.assertIn("WITNESS RIDGE", labels)
        self.assertIn("THE HOLLOW QUARRY", labels)
        self.assertNotIn("LUCA'S FIELD", labels)
        self.assertNotIn("RED PINE HIGHLANDS", labels)

    def test_spiral_world_has_visible_identity_and_versioned_persistence(self):
        director = (ROOT / "scripts" / "systems" / "SpiralWorldDirector.gd").read_text(encoding="utf-8")
        for token in (
            "spiral_field_state_v2.json", "LEGACY_SAVE_PATH", '"schema_version": 3',
            "DistantBeacon", "WhiskerTentacle", "Ear_", "Leg_", "Tail_",
            "ProceduralSpiralInfection", "pressure()", "player_status_text",
        ):
            self.assertIn(token, director)

    def test_spiral_landmarks_keep_camera_standoff(self):
        director = (ROOT / "scripts" / "systems" / "SpiralWorldDirector.gd").read_text(encoding="utf-8")
        self.assertIn("const SPIRAL_STANDOFF_RADIUS := 7.5", director)
        self.assertIn("shape.radius = SPIRAL_STANDOFF_RADIUS", director)

    def test_world_state_drives_environment(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn("func apply_spiral_world_state", game)
        self.assertIn("field_environment.fog_density", game)
        self.assertIn("field_sky_material.sky_top_color", game)
        self.assertIn("field_sun.light_energy", game)

    def test_export_probe_exercises_actual_player_terrain_path(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        build = (ROOT / "BUILD_SPIRAL_FIELD.ps1").read_text(encoding="utf-8")
        self.assertIn("SPIRAL_PLAYER_TERRAIN_PROBE", game)
        self.assertIn("get_voxel_tool_for_test", game)
        self.assertIn("[ALL PLAYER TERRAIN TOOL GATES PASSED]", game)
        self.assertIn("SPIRAL_PLAYER_TERRAIN_PROBE", build)
        self.assertIn("ALL PLAYER TERRAIN TOOL GATES PASSED", build)

    def test_android_uses_mobile_vulkan_renderer(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn('renderer/rendering_method="gl_compatibility"', project)
        self.assertIn('renderer/rendering_method.mobile="mobile"', project)
        self.assertIn('rendering_device/driver.android="vulkan"', project)
        self.assertIn("RENDERER_READY", game)
        self.assertIn("get_current_rendering_method", game)
        self.assertIn("get_current_rendering_driver_name", game)

    def test_mobile_hud_recognizes_authoritative_export_tags(self):
        hud = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        self.assertIn('OS.has_feature("android")', hud)
        self.assertIn('OS.has_feature("ios")', hud)
        self.assertIn('OS.has_feature("mobile")', hud)

    def test_luca_open_world_substrate_remains_present(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        for token in ("KimiWorldGenerator", "MacroTerrain", "_spawn_buggy", "_spawn_luca", "_spawn_spiral_world"):
            self.assertIn(token, game)

if __name__ == "__main__":
    unittest.main()
