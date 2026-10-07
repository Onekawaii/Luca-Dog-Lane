from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class V0154VisualRepairTests(unittest.TestCase):
    def test_terrain_uses_rendered_surface_contract(self):
        terrain = (ROOT / "scripts" / "world" / "MacroTerrain.gd").read_text(encoding="utf-8")
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        eggs = (ROOT / "scripts" / "world" / "EggHunt.gd").read_text(encoding="utf-8")
        self.assertIn("func rendered_height_at", terrain)
        self.assertIn("terrain_heights := PackedFloat32Array()", terrain)
        self.assertIn("macro_terrain.rendered_height_at(x, z)", game)
        self.assertIn("macro_terrain.rendered_height_at(x, z)", eggs)

    def test_terrain_density_and_smoothing_are_upgraded(self):
        terrain = (ROOT / "scripts" / "world" / "MacroTerrain.gd").read_text(encoding="utf-8")
        self.assertIn("TERRAIN_CELL_M := 8.0", terrain)
        self.assertIn("surface.index()", terrain)
        self.assertIn("surface.generate_normals()", terrain)

    def test_underworld_recovery_is_surface_relative(self):
        player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn('game.has_method("surface_height_at")', player)
        self.assertIn("fell_below_local_surface", player)
        self.assertIn("surface_y - 0.75", player)
        self.assertIn("func surface_height_at", game)

    def test_hud_version_is_not_hardcoded(self):
        hud = (ROOT / "scripts" / "HUD.gd").read_text(encoding="utf-8")
        self.assertIn('ProjectSettings.get_setting("application/config/version"', hud)
        self.assertNotIn("v0.15.2 KIMI", hud)

    def test_verifier_runs_visual_repair_acceptance(self):
        verifier = (ROOT / "tools" / "verify.py").read_text(encoding="utf-8")
        self.assertIn("v0154_visual_repair_acceptance.gd", verifier)
        self.assertIn("[ALL V0154 VISUAL REPAIR GATES PASSED]", verifier)

if __name__ == "__main__":
    unittest.main()
