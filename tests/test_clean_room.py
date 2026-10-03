from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CleanRoomContractTests(unittest.TestCase):
    def test_direct_boot_has_no_autoloads(self):
        text = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('run/main_scene="res://scenes/Main.tscn"', text)
        self.assertNotIn("[autoload]", text)

    def test_world_has_continuous_ground_and_boundaries(self):
        text = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        for name in ("WorldGround", "NorthBoundary", "SouthBoundary", "WestBoundary", "EastBoundary"):
            self.assertIn(name, text)
        self.assertIn("GROUND_THICKNESS", text)
        self.assertIn("_create_boundary_wall", text)

    def test_player_has_independent_boundary_recovery(self):
        text = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        self.assertIn("_recover_if_outside", text)
        self.assertIn("FALL_RECOVERY_Y", text)
        self.assertIn("last_safe_ground_position", text)

    def test_buffered_jump_exists(self):
        text = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        self.assertIn("JUMP_BUFFER_TIME", text)
        self.assertIn("COYOTE_TIME", text)
        self.assertIn("func request_jump()", text)
        self.assertIn("velocity.y = JUMP_SPEED", text)

    def test_mobile_look_is_right_side(self):
        text = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        self.assertIn("position.x >= size.x * 0.5", text)
        self.assertNotIn("if position.x > 900", text)
        self.assertIn("DRAG RIGHT SIDE TO LOOK", text)

    def test_mobile_has_real_jump_button(self):
        text = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        self.assertIn('_button("JUMP"', text)
        self.assertIn('player.call("request_jump")', text)

    def test_flat_surfaces_do_not_create_collision_curbs(self):
        text = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        for name in ("MainRoadNS", "MainRoadEW", "SandboxPad", "SkateFloor", "PlazaBridge"):
            self.assertIn(f'_create_surface_box("{name}"', text)

    def test_luca_personal_space_and_eyes(self):
        text = (ROOT / "scripts" / "Luca.gd").read_text(encoding="utf-8")
        self.assertIn("PERSONAL_SPACE := 4.5", text)
        self.assertIn("FOLLOW_DISTANCE := 7.0", text)
        for name in ("EyeWhite_L", "EyeWhite_R", "Pupil_L", "Pupil_R"):
            self.assertIn(name.split("_")[0], text)
        self.assertIn("eye_white", text)
        self.assertIn("pupil_mesh", text)

    def test_billboard_labels_face_camera(self):
        luca = (ROOT / "scripts" / "Luca.gd").read_text(encoding="utf-8")
        npc = (ROOT / "scripts" / "NPC.gd").read_text(encoding="utf-8")
        self.assertIn("BILLBOARD_ENABLED", luca)
        self.assertIn("BILLBOARD_ENABLED", npc)

    def test_spawn_menu_supports_world_objects_and_spacing(self):
        hud = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        for item in ("CRATE", "BARREL", "BALL", "CONE", "RAMP", "NPC", "BUGGY"):
            self.assertIn(item, hud)
        self.assertIn("_menu_spawn_point", game)
        self.assertIn("2.399963", game)

    def test_sandbox_modes_are_real(self):
        text = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        for mode in ("GRAB", "REMOVE", "DUPLICATE", "INSPECT"):
            self.assertIn(mode, text)

    def test_exports_exclude_repo_only_artifacts(self):
        text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        rule = 'exclude_filter="dist/*,tests/*,tools/*,README.md,BUILD_RELEASE.ps1"'
        self.assertEqual(text.count(rule), 2)

    def test_old_runtime_names_absent_from_runtime(self):
        runtime_text = "\n".join(
            path.read_text(encoding="utf-8", errors="ignore").lower()
            for path in (ROOT / "scripts").glob("*.gd")
        )
        for forbidden in ("strawberry", "wetberry", "breakroom", "roommanager", "gameruntime", "eventbus"):
            self.assertNotIn(forbidden, runtime_text)


if __name__ == "__main__":
    unittest.main()
