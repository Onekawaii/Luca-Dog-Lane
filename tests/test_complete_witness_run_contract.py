import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "game_godot"
RENDERER = GODOT / "scripts/procgen/HiveProcGenChunkRenderer.gd"
BREAKROOM = GODOT / "scripts/fps/FirstPersonBreakroom.gd"
ENDING = GODOT / "scenes/ui/EndingScreen.tscn"
ENDING_SCRIPT = GODOT / "scripts/ui/EndingScreen.gd"
EXPORTS = GODOT / "export_presets.cfg"


class CompleteWitnessRunContractTests(unittest.TestCase):
    def test_open_world_route_has_optional_side_chambers(self):
        source = RENDERER.read_text(encoding="utf-8")
        self.assertIn('"kind": "branch"', source)
        self.assertIn("_build_branch_site", source)
        self.assertIn("LatticeEcho_", source)
        self.assertIn("branch_cell_count", source)

    def test_campaign_has_a_real_terminal_and_ending(self):
        renderer = RENDERER.read_text(encoding="utf-8")
        breakroom = BREAKROOM.read_text(encoding="utf-8")
        self.assertIn("LatticeCompletionTerminal", renderer)
        self.assertIn('"lattice_terminal"', breakroom)
        self.assertIn("_complete_campaign_and_show_ending", breakroom)
        self.assertTrue(ENDING.exists())
        self.assertTrue(ENDING_SCRIPT.exists())

    def test_release_metadata_matches_v011(self):
        project = (GODOT / "project.godot").read_text(encoding="utf-8")
        exports = EXPORTS.read_text(encoding="utf-8")
        self.assertIn('config/version="0.11.0"', project)
        self.assertIn('application/file_version="0.11.0"', exports)
        self.assertIn('application/product_version="0.11.0"', exports)
        self.assertIn('version/name="0.11.0"', exports)
        self.assertIn("version/code=11", exports)

    def test_ending_has_return_and_revisit_actions(self):
        scene = ENDING.read_text(encoding="utf-8")
        script = ENDING_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('name="ReturnButton"', scene)
        self.assertIn('name="RevisitButton"', scene)
        self.assertIn("_return_to_title", script)
        self.assertIn("_revisit_world", script)


if __name__ == "__main__":
    unittest.main()
