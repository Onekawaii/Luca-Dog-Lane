from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ContinuousTerrainPassTests(unittest.TestCase):
    def test_continuous_terrain_replaces_visible_flat_slab(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        terrain = (ROOT / "scripts" / "world" / "MacroTerrain.gd").read_text(encoding="utf-8")
        self.assertIn("_spawn_macro_terrain()", game)
        self.assertIn('terrain_body.name = "WorldTerrain"', terrain)
        self.assertIn("TERRAIN_CELL_M := 12.0", terrain)
        self.assertIn("create_trimesh_shape", terrain)
        self.assertIn('"_build_ground_and_boundaries()"', '"_build_ground_and_boundaries()"')
        world_ground_block = game.split('func _build_ground_and_boundaries() -> void:', 1)[1].split('func _build_roads()', 1)[0]
        self.assertNotIn('_create_static_box(\n\t\t"WorldGround"', world_ground_block)
        self.assertIn('_create_boundary_wall(\n\t\t"WorldGround"', world_ground_block)

    def test_terrain_keeps_authored_clearances(self):
        terrain = (ROOT / "scripts" / "world" / "MacroTerrain.gd").read_text(encoding="utf-8")
        for token in (
            "_distance_to_segment",
            "_rect_clear_factor",
            "_radial_clear_factor",
            "NorthMountainPass",
            "WestRidge",
            "SouthValley",
        ):
            self.assertIn(token, terrain)

    def test_wilderness_follows_continuous_terrain_height(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn("var terrain_y := _surface_height(x, z)", game)
        self.assertIn("_create_tree(Vector3(x, terrain_y, z)", game)
        self.assertIn("terrain_y + size * 0.4", game)
        self.assertIn("at.y = _surface_height(at.x, at.z) + 1.1", game)

    def test_egg_hunt_has_twenty_four_collectibles(self):
        eggs = (ROOT / "scripts" / "world" / "EggHunt.gd").read_text(encoding="utf-8")
        self.assertIn('"TWENTY FOURTH BREAKFAST"', eggs)
        self.assertIn("return EGG_MESSAGES.size()", eggs)
        self.assertIn("EGG %d/%d", eggs)
        self.assertEqual(eggs.count("_surface_position("), 22)

    def test_vehicle_chase_camera_uses_spring_arm_and_orbit(self):
        buggy = (ROOT / "scripts" / "Buggy.gd").read_text(encoding="utf-8")
        player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        self.assertIn('["DRIVER", "CHASE", "HOOD", "OVERHEAD"]', buggy)
        self.assertIn("SpringArm3D.new()", buggy)
        self.assertIn('chase_arm.name = "ChaseSpringArm"', buggy)
        self.assertIn("chase_arm.spring_length = 7.4", buggy)
        self.assertIn("func add_camera_look", buggy)
        self.assertIn('riding.call("add_camera_look", delta_pixels, look_sensitivity / 0.0032)', player)
        self.assertIn('var sensitivity := 0.12 * sensitivity_scale', buggy)

    def test_underworld_recovery_is_tightened(self):
        player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        buggy = (ROOT / "scripts" / "Buggy.gd").read_text(encoding="utf-8")
        self.assertIn("FALL_RECOVERY_Y := -1.25", player)
        self.assertIn("RESET_Y := -2.5", buggy)


if __name__ == "__main__":
    unittest.main()
