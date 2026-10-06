from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class V0153EnvironmentTests(unittest.TestCase):
    def test_exact_ten_biome_contract(self):
        plan = (ROOT / "scripts" / "world" / "KimiWorldPlan.gd").read_text(encoding="utf-8")
        expected = (
            "riverlands",
            "marsh",
            "alpine_highlands",
            "rocky_scree",
            "cedar_swamp",
            "badlands",
            "dry_meadow",
            "pine_forest",
            "birch_grove",
            "mixed_forest",
        )
        self.assertIn("GENERATOR_VERSION := 2", plan)
        self.assertIn("BIOME_SCHEMA_VERSION := 1", plan)
        for biome in expected:
            self.assertIn(f'&"{biome}"', plan)
        biome_block = plan.split("const BIOME_IDS", 1)[1].split("= [", 1)[1].split("]", 1)[0]
        self.assertEqual(sum(biome_block.count(f'&"{b}"') for b in expected), 10)

    def test_hydrology_is_seeded_world_logic_not_decoration_only(self):
        plan = (ROOT / "scripts" / "world" / "KimiWorldPlan.gd").read_text(encoding="utf-8")
        terrain = (ROOT / "scripts" / "world" / "MacroTerrain.gd").read_text(encoding="utf-8")
        for token in (
            "primary_river_center_z",
            "primary_river_half_width",
            "tributary_center_x",
            "lake_center",
            "hydrology_influence",
            "water_kind_at",
        ):
            self.assertIn(token, plan)
        for token in (
            "_hydrology_influence_at",
            "_build_primary_river",
            "_build_tributary(0)",
            "_build_tributary(1)",
            "_build_marsh_lake",
            "PrimaryRiverWater",
            "MarshLakeWater",
        ):
            self.assertIn(token, terrain)
        self.assertIn("height = lerpf(", terrain)
        self.assertIn("hydrology_nodes", terrain)

    def test_ecology_consumes_biome_decisions(self):
        generator = (ROOT / "scripts" / "world" / "KimiWorldGenerator.gd").read_text(encoding="utf-8")
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn("_tree_range_for_biome", generator)
        self.assertIn("_rock_range_for_biome", generator)
        self.assertIn('"biome": String(local_biome)', generator)
        self.assertIn('body.add_to_group("biome_tree")', game)
        self.assertIn('body.add_to_group("biome_rock")', game)
        self.assertIn('tuft.add_to_group("biome_groundcover")', game)
        self.assertIn("macro_terrain.is_water_at(x, z)", game)

    def test_v0153_release_identity(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/version="0.15.3-kimi"', project)
        self.assertIn("Luca-Dog-World-v0.15.3-KIMI-ENVIRONMENT-android.apk", presets)
        self.assertIn("version/code=18", presets)


if __name__ == "__main__":
    unittest.main()
