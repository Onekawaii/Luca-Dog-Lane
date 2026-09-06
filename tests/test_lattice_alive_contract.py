"""Static contract checks for v0.6.0-lattice-alive."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT / "campaigns" / "strawberry_omen"


class TestReactiveContract(unittest.TestCase):
    def test_manifest_registers_interaction_layer(self):
        manifest = json.loads((CAMPAIGN / "campaign.manifest.json").read_text())
        self.assertEqual(manifest["interaction_schema"], "strawberry_interactions_v1")
        self.assertEqual(manifest["game_files"]["interactions"], "game/interactions.json")

    def test_interaction_file_is_versioned(self):
        data = json.loads((CAMPAIGN / "game" / "interactions.json").read_text())
        self.assertEqual(data["schema"], "strawberry_interactions_v1")
        self.assertEqual(data["version"], "1.0.0")

    def test_web_state_exposes_reactive_systems(self):
        server = (ROOT / "hive_lattice/web_app/server.py").read_text()
        for field in ("inventory_details", "conditions", "npc_memory", "room_state", "last_outcome"):
            self.assertIn(f'"{field}"', server)
        self.assertIn('/api/item/use', server)

    def test_frontend_supports_locked_and_item_actions(self):
        js = (ROOT / "hive_lattice/web_app/static/strawberry.js").read_text()
        self.assertIn("locked-choice", js)
        self.assertIn("useItemAction", js)
        self.assertIn("inventory_details", js)
        self.assertIn("RELATIONSHIPS", js)
        self.assertIn("ACTIVE CONDITIONS", js)

    def test_mobile_ux_contract_preserved(self):
        css = (ROOT / "hive_lattice/web_app/static/strawberry.css").read_text()
        self.assertIn("min-height: 56px", css)
        self.assertIn("env(safe-area-inset-bottom)", css)
        html = (ROOT / "hive_lattice/web_app/templates/index.html").read_text()
        self.assertIn("viewport-fit=cover", html)
        self.assertNotIn("user-scalable=no", html)

    def test_pwa_cache_bumped(self):
        sw = (ROOT / "hive_lattice/web_app/static/sw.js").read_text()
        self.assertIn("wetberry-shell-v060-alive", sw)

    def test_frozen_bard_schema_file_not_repurposed(self):
        schemas = (ROOT / "SCHEMA_VERSIONS.md").read_text()
        self.assertIn("room_schema_v1", schemas)
        interactions = json.loads((CAMPAIGN / "game" / "interactions.json").read_text())
        self.assertIn("frozen Bard schemas untouched", interactions["description"])


if __name__ == "__main__":
    unittest.main()
