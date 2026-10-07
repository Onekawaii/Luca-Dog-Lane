from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SpiralFieldV001Contracts(unittest.TestCase):
    def test_identity_and_exports_are_new_game(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/name="Spiral Field"', project)
        self.assertIn('config/version="0.1.0"', project)
        self.assertIn("Spiral-Field-v0.1.0-windows.exe", presets)
        self.assertIn("Spiral-Field-v0.1.0-android.apk", presets)
        self.assertIn('package/unique_name="com.onekawaii.spiralfield"', presets)

    def test_act_and_mercy_are_catalog_driven(self):
        tools = json.loads((ROOT / "data" / "tools_v016.json").read_text(encoding="utf-8"))
        self.assertEqual(tools["order"][:2], ["act", "mercy"])
        self.assertEqual(tools["tools"]["act"]["action"], "act")
        self.assertEqual(tools["tools"]["mercy"]["action"], "mercy")
        player = (ROOT / "scripts" / "Player.gd").read_text(encoding="utf-8")
        self.assertIn('action == "act" or action == "mercy"', player)
        self.assertIn('is_in_group("spiral_interactable")', player)

    def test_spiral_world_has_donor_mechanics_and_persistence(self):
        director = (ROOT / "scripts" / "systems" / "SpiralWorldDirector.gd").read_text(encoding="utf-8")
        for token in (
            "affection", "corruption", "witnessing", "wailing",
            "tabbytulhu", "ProceduralSpiralInfection",
            "spiral_field_state_v1.json", "schema_version",
            "WITNESS_POS", "WAIL_POS", "TABBY_POS",
        ):
            self.assertIn(token, director)

    def test_luca_open_world_substrate_remains_present(self):
        game = (ROOT / "scripts" / "Game.gd").read_text(encoding="utf-8")
        for token in ("KimiWorldGenerator", "MacroTerrain", "_spawn_buggy", "_spawn_luca", "_spawn_spiral_world"):
            self.assertIn(token, game)

if __name__ == "__main__":
    unittest.main()
