"""v0.7 World in Motion contract + runtime tests (no Flask required)."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from engine.module_runtime import CampaignModule
from engine.world_contracts import GameAction
from engine.world_runtime import WorldRuntime

ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT / "campaigns" / "strawberry_omen"


class TestWorldContract(unittest.TestCase):
    def setUp(self):
        self.module = CampaignModule(CAMPAIGN)
        self.state = self.module.new_state()
        self.module.enter_scene(self.state)
        self.world = WorldRuntime(self.module)
        self.world.ensure_state(self.state)

    def test_breakroom_snapshot_is_walkable(self):
        snapshot = self.world.snapshot(self.state)
        self.assertEqual(snapshot["schema"], "hive_world_snapshot_v1")
        self.assertTrue(snapshot["world"]["enabled"])
        self.assertEqual(snapshot["world"]["id"], "world.breakroom.main")
        self.assertIn("player", snapshot)

    def test_keith_is_server_authored_entity(self):
        snapshot = self.world.snapshot(self.state)
        keith = next(e for e in snapshot["entities"] if e["id"] == "npc.keith_janitor")
        self.assertEqual(keith["name"], "Keith the Janitor")
        self.assertIn("evidence_bag", [layer["shape"] for layer in keith["identity"]["layers"]])
        self.assertIn("dynamics", keith)

    def test_move_updates_world_position_without_advancing_story_turn(self):
        before_turn = self.state.turn_count
        before_history = len(self.state.event_history)
        before = dict(self.state.world_state["player"])
        result = self.world.apply_action(self.state, GameAction(kind="move", x=before["x"] + 5, y=before["y"] + 4))
        self.assertEqual(self.state.turn_count, before_turn)
        self.assertEqual(len(self.state.event_history), before_history)
        self.assertNotEqual(self.state.world_state["player"], before)
        self.assertEqual(result["event"]["kind"], "world.move")

    def test_interact_requires_proximity(self):
        with self.assertRaises(PermissionError):
            self.world.apply_action(self.state, GameAction(kind="interact", target_id="npc.keith_janitor"))

    def test_walk_to_keith_then_interact_enters_existing_scene(self):
        self.state.world_state["player"] = {"x": 79.0, "y": 75.0}
        result = self.world.apply_action(self.state, GameAction(kind="interact", target_id="npc.keith_janitor"))
        self.assertEqual(self.state.current_scene, "scene.act1.keith_corner")
        self.assertEqual(self.state.current_location, "location.breakroom.utility_corner")
        self.assertEqual(result["event"]["kind"], "world.interact")

    def test_wetberry_disappears_after_containment_flag(self):
        self.assertTrue(any(h["id"] == "hotspot.wetberry" for h in self.world.snapshot(self.state)["hotspots"]))
        self.state.flags["wetberry_contained"] = True
        self.assertFalse(any(h["id"] == "hotspot.wetberry" for h in self.world.snapshot(self.state)["hotspots"]))

    def test_character_identity_file_is_versioned(self):
        data = json.loads((CAMPAIGN / "game" / "character_identities.json").read_text(encoding="utf-8"))
        self.assertEqual(data["schema"], "character_identity_v1")
        self.assertIn("npc.keith_janitor", data["characters"])

    def test_frontend_has_walkable_canvas_and_no_scene_name_npc_inference(self):
        html = (ROOT / "hive_lattice/web_app/templates/index.html").read_text(encoding="utf-8")
        js = (ROOT / "hive_lattice/web_app/static/strawberry.js").read_text(encoding="utf-8")
        world_js = (ROOT / "hive_lattice/web_app/static/world_client.js").read_text(encoding="utf-8")
        self.assertIn('id="world-canvas"', html)
        self.assertIn('/api/action', js)
        self.assertIn('class HiveWorldClient', world_js)
        self.assertNotIn('sceneId.includes("keith_corner")', js)


class TestActorSignalIntegration(unittest.TestCase):
    def test_keith_state_changes_when_player_gets_evidence_bag(self):
        module = CampaignModule(CAMPAIGN)
        state = module.new_state()
        module.enter_scene(state, "scene.act1.keith_corner")
        self.assertNotIn("npc.keith_janitor", state.actor_dynamics)
        module.choose(state, "ask_for_evidence_bag")
        self.assertIn("npc.keith_janitor", state.actor_dynamics)
        view = WorldRuntime(module)._actor_view(state, "npc.keith_janitor")
        self.assertIn(view["behavior"], {"steady", "reintegrating", "withdrawn", "fixated", "agitated", "numb", "strained"})
        self.assertGreater(state.npc_memory["npc.keith_janitor"], 0)


if __name__ == "__main__":
    unittest.main()
