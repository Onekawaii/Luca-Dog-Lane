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

    def test_player_has_independent_boundary_recovery(self):
        text = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        self.assertIn("_recover_if_outside", text)
        self.assertIn("global_position.y < -18.0", text)

    def test_sandbox_modes_are_real(self):
        text = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        for mode in ("GRAB", "REMOVE", "DUPLICATE", "INSPECT"):
            self.assertIn(mode, text)

    def test_spawn_menu_supports_world_objects(self):
        text = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        for item in ("CRATE", "BARREL", "BALL", "CONE", "RAMP", "NPC", "BUGGY"):
            self.assertIn(item, text)

    def test_old_runtime_names_absent_from_runtime(self):
        runtime_text = "\n".join(
            path.read_text(encoding="utf-8", errors="ignore").lower()
            for path in (ROOT / "scripts").glob("*.gd")
        )
        for forbidden in ("strawberry", "wetberry", "breakroom", "roommanager", "gameruntime", "eventbus"):
            self.assertNotIn(forbidden, runtime_text)

if __name__ == "__main__":
    unittest.main()
