from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class KimiCoreIntegrationTests(unittest.TestCase):
    def test_runtime_uses_kimi_descriptor_generation(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn("KimiWorldGenerator", game)
        self.assertIn("KIMI_WORLD_CORE_READY", game)
        self.assertIn("world_generator.describe_chunk", game)

    def test_live_voxel_generator_uses_kimi_world_height(self):
        terrain = (ROOT / "scripts" / "world" / "TerrainSliceGenerator.gd").read_text(encoding="utf-8")
        self.assertIn("KimiWorldPlan.new", terrain)
        self.assertIn("world_plan.terrain_height", terrain)

    def test_kimi_core_files_exist(self):
        for name in (
            "KimiDeterministic.gd",
            "KimiWorldPlan.gd",
            "KimiChunkDescriptor.gd",
            "KimiWorldGenerator.gd",
        ):
            self.assertTrue((ROOT / "scripts" / "world" / name).is_file(), name)

    def test_kimi_substrate_survives_new_game_identity(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        self.assertIn('config/name="Spiral Field"', project)
        self.assertIn('config/version="0.1.0"', project)
        self.assertIn("Spiral-Field-v0.1.0-android.apk", presets)
        self.assertIn("version/code=1", presets)
        self.assertIn("KimiWorldGenerator", game)


if __name__ == "__main__":
    unittest.main()
