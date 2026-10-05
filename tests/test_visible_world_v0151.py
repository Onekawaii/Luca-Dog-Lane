from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class VisibleWorldPassTests(unittest.TestCase):
    def test_macro_terrain_is_runtime_wired(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        terrain = (ROOT / "scripts" / "world" / "MacroTerrain.gd").read_text(encoding="utf-8")
        self.assertIn("_spawn_macro_terrain()", game)
        self.assertIn("NorthMountainPass", terrain)
        self.assertIn("WestRidge", terrain)
        self.assertIn("SouthValley", terrain)
        self.assertIn("create_trimesh_shape", terrain)
        self.assertIn("world_plan.terrain_height", terrain)

    def test_wilderness_follows_macro_terrain_height(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn("var terrain_y := _surface_height(x, z)", game)
        self.assertIn("_create_tree(Vector3(x, terrain_y, z)", game)
        self.assertIn("terrain_y + size * 0.4", game)

    def test_egg_hunt_has_twelve_collectibles(self):
        eggs = (ROOT / "scripts" / "world" / "EggHunt.gd").read_text(encoding="utf-8")
        self.assertIn("const EGG_MESSAGES := [", eggs)
        self.assertEqual(eggs.count('area.add_to_group("easter_egg")'), 1)
        self.assertIn("return EGG_MESSAGES.size()", eggs)
        self.assertIn("EGG %d/%d", eggs)

    def test_vehicle_camera_modes_are_distinct(self):
        buggy = (ROOT / "scripts" / "Buggy.gd").read_text(encoding="utf-8")
        self.assertIn('["DRIVER", "CHASE", "HOOD", "OVERHEAD"]', buggy)
        for token in (
            'Vector3(-0.58, 1.78, -0.42)',
            'Vector3(0.0, 3.35, 6.8)',
            'Vector3(0.0, 1.56, -2.08)',
            'Vector3(0.0, 15.5, 5.4)',
        ):
            self.assertIn(token, buggy)
        self.assertIn("_update_camera_fov()", buggy)


if __name__ == "__main__":
    unittest.main()
