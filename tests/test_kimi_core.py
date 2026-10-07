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

    def test_build_identity_is_not_v0122(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/version="0.16.1-kimi"', project)
        self.assertIn("Luca-Dog-World-v0.16.1-KIMI-PLAYTEST-REPAIR-android.apk", presets)
        self.assertIn("version/code=19", presets)


if __name__ == "__main__":
    unittest.main()
