"""v0.6.0 Reactive Lattice acceptance tests."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem, SAVE_VERSION

ROOT = Path("campaigns/strawberry_omen")


class ReactiveHelpers:
    def module_state(self):
        module = CampaignModule(ROOT)
        state = module.new_state()
        module.enter_scene(state)
        return module, state

    def drive_to_act5_verdict(self, module, state):
        # Stable pre-v0.6 path. The reactive layer must remain additive.
        for choice in (
            "inspect_label",
            "file_boundary_statement",
            "enter_fridge",
            "meet_moldric",
            "help_moldric_reclaim",
            "proceed_to_act3",
            "approach_vending_machine",
            "name_your_price",
            "confront_snack_wraiths_peacefully",
            "proceed_to_act4",
            "accept_moldric_guide",
            "acknowledge_condiments",
            "acknowledge_leftovers",
            "take_freezer_blessing_with_respect",
            "compassion_path",
            "proceed_to_act5",
            "accept_summons",
            "search_the_files",
            "give_testimony_honestly",
            "step_into_the_arena",
        ):
            module.choose(state, choice)
        self.assertEqual(state.current_scene, "scene.act5.hearing_arena_verdict")


class TestInteractionLayer(unittest.TestCase, ReactiveHelpers):
    def test_interaction_schema_loaded(self):
        module, _ = self.module_state()
        self.assertEqual(module.interactions["schema"], "strawberry_interactions_v1")
        self.assertTrue(module.item_actions)
        self.assertIn("department_verdict", module.interactions["rule_tables"])

    def test_hidden_item_choice_reveals_after_acquiring_bag(self):
        module, state = self.module_state()
        ids = {c["id"] for c in module.choice_views(state)}
        self.assertNotIn("bag_wetberry_now", ids)
        module.choose(state, "find_keith")
        module.choose(state, "ask_for_evidence_bag")
        module.choose(state, "return_from_keith")
        ids = {c["id"] for c in module.choice_views(state)}
        self.assertIn("bag_wetberry_now", ids)

    def test_locked_choice_rejected_by_runtime(self):
        module, state = self.module_state()
        with self.assertRaises(PermissionError):
            module.choose(state, "bag_wetberry_now")

    def test_bag_route_changes_inventory_world_and_relationship(self):
        module, state = self.module_state()
        module.choose(state, "find_keith")
        module.choose(state, "ask_for_evidence_bag")
        module.choose(state, "return_from_keith")
        before = state.stats["moisture_pressure"]
        module.choose(state, "bag_wetberry_now")
        self.assertTrue(state.flags["wetberry_contained"])
        self.assertNotIn("item.evidence_bag_not_my_business", state.inventory)
        self.assertIn("item.bagged_wetberry_evidence", state.inventory)
        self.assertLess(state.stats["moisture_pressure"], before)
        self.assertEqual(state.room_state[state.current_location]["wetberry_status"], "contained")
        self.assertGreaterEqual(state.npc_memory["npc.keith_janitor"], 3)
        self.assertEqual(len(state.event_history), 1)

    def test_item_action_can_contain_wetberry(self):
        module, state = self.module_state()
        module.choose(state, "find_keith")
        module.choose(state, "ask_for_evidence_bag")
        module.choose(state, "return_from_keith")
        actions = {a["id"] for a in module.item_action_views(state)}
        self.assertIn("use.evidence_bag.wetberry", actions)
        module.use_item(state, "use.evidence_bag.wetberry")
        self.assertTrue(state.flags["wetberry_contained"])
        self.assertIn("item.bagged_wetberry_evidence", state.inventory)

    def test_deterministic_event_is_reproducible(self):
        def run_once():
            module, state = self.module_state()
            state.inventory.append("item.evidence_bag_not_my_business")
            module.use_item(state, "use.evidence_bag.wetberry")
            return state.event_history[-1]["text"], dict(state.stats), dict(state.flags)
        self.assertEqual(run_once(), run_once())

    def test_touch_wetberry_adds_temporary_conditions(self):
        module, state = self.module_state()
        module.choose(state, "touch_wetberry")
        self.assertIn("condition.socially_stunned", state.conditions)
        self.assertIn("condition.recently_associated", state.conditions)
        module.choose(state, "ignore_it")
        self.assertNotIn("condition.socially_stunned", state.conditions)
        self.assertIn("condition.recently_associated", state.conditions)

    def test_npc_memory_tracks_behavior(self):
        module, state = self.module_state()
        module.choose(state, "find_keith")
        module.choose(state, "ask_for_evidence_bag")
        self.assertEqual(state.npc_memory["npc.keith_janitor"], 2)

    def test_room_state_survives_departure_and_return(self):
        module, state = self.module_state()
        module.choose(state, "inspect_stain")
        self.assertTrue(state.room_state["location.breakroom.central_table"]["stain_sampled"])
        module.choose(state, "ask_darla")
        module.choose(state, "return_from_darla")
        self.assertTrue(state.room_state["location.breakroom.central_table"]["stain_sampled"])
        self.assertGreaterEqual(state.room_state["location.breakroom.central_table"]["visits"], 2)

    def test_stat_route_reveals_when_requirements_met(self):
        module, state = self.module_state()
        # Reach Vendrick with low stats first.
        state.current_scene = "scene.act3.vendrick_negotiation"
        state.current_location = "location.breakroom.vending_machine"
        ids = {c["id"] for c in module.choice_views(state)}
        self.assertNotIn("invoke_form_9a", ids)
        state.flags["professional_composure"] = True
        state.stats["bureaucracy"] = 4
        ids = {c["id"] for c in module.choice_views(state)}
        self.assertIn("invoke_form_9a", ids)
        module.choose(state, "invoke_form_9a")
        self.assertTrue(state.flags["form_9a_invoked"])
        self.assertIn("item.accountability_token", state.inventory)
        self.assertEqual(state.current_scene, "scene.act3.accountability_completion")

    def test_feral_route_reveals_at_high_chaos(self):
        module, state = self.module_state()
        state.current_scene = "scene.act3.vendrick_negotiation"
        state.current_location = "location.breakroom.vending_machine"
        state.stats["ape_chaos"] = 5
        ids = {c["id"] for c in module.choice_views(state)}
        self.assertIn("bite_procedural_seal", ids)


class TestReactiveVerdict(unittest.TestCase, ReactiveHelpers):
    def test_clean_record_is_exonerated(self):
        module, state = self.module_state()
        self.drive_to_act5_verdict(module, state)
        result = module.choose(state, "present_evidence_ledger")
        self.assertIn("EXONERATED", result)
        self.assertEqual(state.flags["department_verdict"], "exonerated")
        self.assertTrue(state.flags["verdict_exonerated"])
        self.assertEqual(state.current_scene, "scene.act5.verdict_vault")

    def test_bad_record_without_evidence_is_guilty(self):
        module, state = self.module_state()
        state.current_scene = "scene.act5.hearing_arena_verdict"
        state.current_location = "location.department_of_adjudication.hearing_arena"
        state.flags["casserole_insulted"] = True
        result = module.choose(state, "remain_silent")
        self.assertIn("GUILTY", result)
        self.assertEqual(state.flags["department_verdict"], "guilty")
        self.assertIn("condition.under_scrutiny", state.conditions)

    def test_high_ape_chaos_produces_cosmic_compromise(self):
        module, state = self.module_state()
        state.current_scene = "scene.act5.hearing_arena_verdict"
        state.current_location = "location.department_of_adjudication.hearing_arena"
        state.stats["ape_chaos"] = 9
        result = module.choose(state, "remain_silent")
        self.assertIn("COSMIC COMPROMISE", result)
        self.assertEqual(state.flags["department_verdict"], "cosmic_compromise")

    def test_evidence_ledger_has_contextual_item_action(self):
        module, state = self.module_state()
        state.current_scene = "scene.act5.hearing_arena_verdict"
        state.current_location = "location.department_of_adjudication.hearing_arena"
        state.inventory.append("item.evidence_ledger")
        actions = {a["id"] for a in module.item_action_views(state)}
        self.assertIn("use.evidence_ledger.hearing", actions)


class TestReactiveSaveV2(unittest.TestCase, ReactiveHelpers):
    def test_v2_round_trip_preserves_reactive_state(self):
        module, state = self.module_state()
        state.inventory.append("item.evidence_bag_not_my_business")
        module.use_item(state, "use.evidence_bag.wetberry")
        state.npc_memory["npc.tammy_hr"] = -2
        state.conditions["condition.under_scrutiny"] = 4
        with tempfile.TemporaryDirectory() as td:
            saves = ModuleSaveSystem(module, td)
            saves.save_game(state)
            loaded = saves.load_game()
        self.assertEqual(SAVE_VERSION, 2)
        self.assertEqual(loaded.room_state, state.room_state)
        self.assertEqual(loaded.npc_memory, state.npc_memory)
        self.assertEqual(loaded.conditions, state.conditions)
        self.assertEqual(loaded.event_history, state.event_history)
        self.assertEqual(loaded.turn_count, state.turn_count)
        self.assertEqual(loaded.rng_seed, state.rng_seed)

    def test_v1_save_is_backward_compatible(self):
        module, state = self.module_state()
        legacy = {
            "save_version": 1,
            "module_id": state.campaign_id,
            "current_scene": state.current_scene,
            "current_location": state.current_location,
            "flags": state.flags,
            "stats": state.stats,
            "inventory": ["item.damp_napkin"],
            "log": ["legacy"],
        }
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "default_save.json"
            path.write_text(json.dumps(legacy), encoding="utf-8")
            loaded = ModuleSaveSystem(module, td).load_game()
        self.assertEqual(loaded.inventory, ["item.damp_napkin"])
        self.assertEqual(loaded.room_state, {})
        self.assertEqual(loaded.npc_memory, {})
        self.assertEqual(loaded.turn_count, 0)


if __name__ == "__main__":
    unittest.main()
