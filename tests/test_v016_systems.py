from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]


class V016SystemsContracts(unittest.TestCase):
    def _json(self, name):
        return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))

    def test_content_catalogs_are_versioned_and_cross_referenced(self):
        items = self._json("items_v016.json")
        tools = self._json("tools_v016.json")
        maps = self._json("maps_v016.json")
        recipes = self._json("recipes_v016.json")
        self.assertEqual(items["schema_version"], 1)
        self.assertEqual(tools["schema_version"], 1)
        self.assertEqual(maps["schema_version"], 1)
        self.assertEqual(recipes["schema_version"], 2)
        self.assertIn("field_hammer", items["items"])
        self.assertEqual(tools["tools"]["field_hammer"]["action"], "strike")
        self.assertEqual(tools["tools"]["field_hammer"]["damage"], 25.0)
        self.assertEqual(len(maps["maps"]), 3)
        self.assertEqual(maps["default_map"], "lucas_field")
        self.assertEqual(maps["maps"]["lucas_field"]["seed"], 6060)
        self.assertNotEqual(
            maps["maps"]["red_pine_highlands"]["seed"],
            maps["maps"]["quarry_basin"]["seed"],
        )

    def test_registry_is_runtime_authority(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        registry = (ROOT / "scripts" / "systems" / "ContentRegistry.gd").read_text(encoding="utf-8")
        self.assertIn("ContentRegistry.new()", game)
        self.assertIn("get_tool_definition", game)
        self.assertIn("get_map_options", game)
        self.assertIn("request_map", game)
        for catalog in ("items_v016.json", "tools_v016.json", "maps_v016.json", "recipes_v016.json"):
            self.assertIn(catalog, registry)

    def test_vehicle_uses_real_vehicle_physics(self):
        buggy = (ROOT / "scripts" / "Buggy.gd").read_text(encoding="utf-8")
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertTrue(buggy.startswith("extends VehicleBody3D"))
        self.assertEqual(buggy.count("VehicleWheel3D.new()"), 1)
        for name in ("FrontLeft", "FrontRight", "RearLeft", "RearRight"):
            self.assertIn(name, buggy)
        for token in (
            "wheel_rest_length",
            "suspension_stiffness",
            "wheel_friction_slip",
            "use_as_steering",
            "use_as_traction",
            "get_wheel_contact_count_for_test",
        ):
            self.assertIn(token, buggy)
        self.assertIn("VehicleBody3D.new()", game)
        self.assertNotIn("var buggy := CharacterBody3D.new()", game)
        self.assertIn("_build_impact_sensor()", buggy)
        self.assertIn('sensor.name = "FrontImpactSensor"', buggy)
        self.assertIn("sensor.body_entered.connect(_on_body_entered)", buggy)

    def test_luca_anchor_is_translation_driven_not_camera_yaw_driven(self):
        luca = (ROOT / "scripts" / "Luca.gd").read_text(encoding="utf-8")
        self.assertIn("_update_follow_anchor_from_player_motion", luca)
        self.assertIn("follow_heading = motion.normalized()", luca)
        self.assertIn("Preserve the formation slot when the player only rotates the camera", luca)
        self.assertIn("get_follow_anchor_for_test", luca)
        follow_logic = luca.split("func _update_follow_anchor_from_player_motion", 1)[1].split(
            "func _compute_follow_anchor", 1
        )[0]
        self.assertNotIn("player.global_transform.basis", follow_logic)

    def test_npcs_have_health_damage_and_anatomy(self):
        npc = (ROOT / "scripts" / "NPC.gd").read_text(encoding="utf-8")
        self.assertIn("MAX_HEALTH := 100.0", npc)
        self.assertIn("func take_damage", npc)
        self.assertIn('add_to_group("damageable")', npc)
        for part in (
            "Pelvis",
            "Torso",
            "Head",
            "UpperArm_",
            "Forearm_",
            "Hand_",
            "Leg_",
            "Foot_",
        ):
            self.assertIn(part, npc)

    def test_map_seed_propagates_into_voxel_generator_and_persistence(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        slice_text = (ROOT / "scripts" / "world" / "TerrainSlice.gd").read_text(encoding="utf-8")
        generator = (ROOT / "scripts" / "world" / "TerrainSliceGenerator.gd").read_text(encoding="utf-8")
        persistence = (ROOT / "scripts" / "systems" / "SlicePersistence.gd").read_text(encoding="utf-8")
        self.assertIn('node.set("world_seed", world_seed)', game)
        self.assertIn('generator.call("configure", world_seed)', slice_text)
        self.assertIn("func configure(seed: int)", generator)
        self.assertIn("v016_terrain_slice_%d.json", slice_text)
        self.assertIn('parsed.get("world_seed"', persistence)

    def test_player_tool_execution_uses_catalog_actions(self):
        player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        self.assertNotIn("TOOL_MODES", player)
        self.assertIn("get_tool_ids", player)
        self.assertIn("get_tool_definition", player)
        self.assertIn('action == "strike"', player)
        self.assertIn("_strike_target", player)


if __name__ == "__main__":
    unittest.main()
