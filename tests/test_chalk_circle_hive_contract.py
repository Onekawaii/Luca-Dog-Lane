from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class TestChalkCircleHiveContract(unittest.TestCase):
    def test_layer_manifest_has_exact_six_layer_spine(self):
        path = ROOT / "game_godot" / "data" / "chalk_circle" / "layers.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(data["schema"], "hive_chalk_circle_layers_v1")
        self.assertEqual([x["id"] for x in data["layers"]], [1, 2, 3, 4, 5, 6])
        self.assertEqual(data["layers"][0]["name"], "THE GATE")
        self.assertEqual(data["layers"][-1]["name"], "THE REFUSAL")

    def test_router_persists_inside_existing_world_state_container(self):
        source = (ROOT / "game_godot" / "scripts" / "runtime" / "ChalkCircleRouter.gd").read_text(encoding="utf-8")
        self.assertIn('const SCHEMA := "hive_chalk_circle_v1"', source)
        self.assertIn('state.world_state["chalk_circle"]', source)
        self.assertIn("HashingContext.HASH_SHA256", source)
        self.assertIn("func request_archive_focus", source)
        self.assertIn("func request_refusal", source)

    def test_game_runtime_observes_choice_and_item_actions(self):
        source = (ROOT / "game_godot" / "scripts" / "runtime" / "GameRuntime.gd").read_text(encoding="utf-8")
        self.assertIn("var chalk_circle_router: ChalkCircleRouter", source)
        self.assertIn('_observe_chalk_circle("choice", choice_id, outcome)', source)
        self.assertIn('_observe_chalk_circle("item_use"', source)
        self.assertIn("func chalk_circle_snapshot()", source)

    def test_event_bus_exposes_additive_chalk_signals(self):
        source = (ROOT / "game_godot" / "scripts" / "runtime" / "EventBus.gd").read_text(encoding="utf-8")
        self.assertIn("signal chalk_circle_layer_changed", source)
        self.assertIn("signal chalk_circle_archived", source)
        self.assertIn("signal chalk_circle_refusal", source)

    def test_action_resolver_supports_opt_in_chalk_requirements(self):
        source = (ROOT / "game_godot" / "scripts" / "runtime" / "ActionResolver.gd").read_text(encoding="utf-8")
        self.assertIn('spec.has("chalk")', source)
        self.assertIn("ChalkCircleRouter.evaluate_requirement", source)

    def test_frozen_world_state_schema_not_extended(self):
        source = (ROOT / "game_godot" / "scripts" / "runtime" / "WorldState.gd").read_text(encoding="utf-8")
        self.assertNotIn("var chalk_", source)
        self.assertIn('"world_state": world_state.duplicate(true)', source)


if __name__ == "__main__":
    unittest.main()
