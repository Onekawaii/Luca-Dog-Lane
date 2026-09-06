"""Tests for the CampaignModule save/load system (v0.6)."""

import json
import os
import shutil
import tempfile
import unittest

from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem, SAVE_VERSION


class TestModuleSaveSystem(unittest.TestCase):
    """Test save/load lifecycle for Strawberry Omen module state."""

    def setUp(self):
        self.module = CampaignModule("campaigns/strawberry_omen")
        self.tmp_dir = tempfile.mkdtemp()
        self.save_sys = ModuleSaveSystem(self.module, save_dir=self.tmp_dir)

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _state_at_act1_start(self):
        state = self.module.new_state()
        self.module.enter_scene(state)
        return state

    def _state_with_fridge_unlocked(self):
        state = self._state_at_act1_start()
        self.module.choose(state, "inspect_label")
        self.module.choose(state, "file_boundary_statement")
        return state

    def _state_at_act2_door_shelf(self):
        state = self._state_with_fridge_unlocked()
        self.module.choose(state, "enter_fridge")
        return state

    def _state_act2_complete(self):
        state = self._state_at_act2_door_shelf()
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "help_moldric_reclaim")
        return state

    # =================================================================
    # 1. Save file is created
    # =================================================================

    def test_save_creates_file(self):
        state = self._state_at_act1_start()
        msg = self.save_sys.save_game(state)
        self.assertIn("saved", msg.lower())
        self.assertTrue(os.path.exists(os.path.join(self.tmp_dir, "default_save.json")))

    # =================================================================
    # 2. Save JSON contains required fields
    # =================================================================

    def test_save_json_has_required_fields(self):
        state = self._state_at_act1_start()
        self.save_sys.save_game(state)
        with open(os.path.join(self.tmp_dir, "default_save.json"), "r") as f:
            data = json.load(f)
        for key in ("save_version", "module_id", "timestamp", "current_scene",
                     "current_location", "flags", "stats", "inventory", "log"):
            self.assertIn(key, data, f"Missing required field: {key}")
        self.assertEqual(data["save_version"], SAVE_VERSION)
        self.assertEqual(data["module_id"], state.campaign_id)

    # =================================================================
    # 3. Load restores scene/location
    # =================================================================

    def test_load_restores_scene_and_location(self):
        state = self._state_at_act1_start()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.current_scene, state.current_scene)
        self.assertEqual(loaded.current_location, state.current_location)

    # =================================================================
    # 4. Load restores flags
    # =================================================================

    def test_load_restores_flags(self):
        state = self._state_with_fridge_unlocked()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.flags, state.flags)
        self.assertTrue(loaded.flags["fridge_unlocked"])

    # =================================================================
    # 5. Load restores Act II completion state
    # =================================================================

    def test_load_restores_act2_complete_state(self):
        state = self._state_act2_complete()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertTrue(loaded.flags["fridge_unlocked"])
        self.assertTrue(loaded.flags["entered_fridge"])
        self.assertTrue(loaded.flags["met_moldric"])
        self.assertTrue(loaded.flags["lunch_thief_confronted"])
        self.assertTrue(loaded.flags["ancient_mayonnaise_obtained"])
        self.assertTrue(loaded.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", loaded.inventory)

    # =================================================================
    # 6. Missing save file is handled gracefully
    # =================================================================

    def test_missing_save_file_returns_none(self):
        loaded = self.save_sys.load_game("nonexistent")
        self.assertIsNone(loaded)

    # =================================================================
    # 7. Corrupt save file is handled gracefully
    # =================================================================

    def test_corrupt_save_file_returns_none(self):
        corrupt_path = os.path.join(self.tmp_dir, "default_save.json")
        with open(corrupt_path, "w") as f:
            f.write("{not valid json!!!")
        loaded = self.save_sys.load_game()
        self.assertIsNone(loaded)

    # =================================================================
    # 8. Visual metadata still works after load
    # =================================================================

    def test_visual_metadata_works_after_load(self):
        from play_strawberry import get_visual_metadata
        state = self._state_at_act1_start()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        metadata = get_visual_metadata(self.module, loaded)
        self.assertEqual(metadata["current_location"], loaded.current_location)
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    # =================================================================
    # Existing tests still pass (no mutation of unrelated flags)
    # =================================================================

    def test_save_load_does_not_mutate_flags(self):
        state = self._state_with_fridge_unlocked()
        flags_before = dict(state.flags)
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.flags, flags_before)

    def test_save_load_roundtrip_inventory(self):
        state = self._state_with_fridge_unlocked()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.inventory, state.inventory)

    def test_save_load_roundtrip_stats(self):
        state = self._state_at_act1_start()
        self.module.choose(state, "thumbs_up")
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.stats, state.stats)

    def test_list_saves_after_save(self):
        state = self._state_at_act1_start()
        self.save_sys.save_game(state)
        saves = self.save_sys.list_saves()
        self.assertEqual(len(saves), 1)
        self.assertEqual(saves[0]["slot"], "default")

    def test_list_saves_empty_dir(self):
        saves = self.save_sys.list_saves()
        self.assertEqual(saves, [])

    def test_delete_save_removes_file(self):
        state = self._state_at_act1_start()
        self.save_sys.save_game(state)
        msg = self.save_sys.delete_save()
        self.assertIn("deleted", msg.lower())
        self.assertFalse(os.path.exists(os.path.join(self.tmp_dir, "default_save.json")))

    def test_delete_nonexistent_save(self):
        msg = self.save_sys.delete_save("ghost")
        self.assertIn("no save", msg.lower())

    def test_save_to_custom_slot(self):
        state = self._state_at_act1_start()
        self.save_sys.save_game(state, slot="slot1")
        self.assertTrue(os.path.exists(os.path.join(self.tmp_dir, "slot1_save.json")))

    def test_load_from_custom_slot(self):
        state = self._state_act2_complete()
        self.save_sys.save_game(state, slot="slot1")
        loaded = self.save_sys.load_game("slot1")
        self.assertIsNotNone(loaded)
        self.assertTrue(loaded.flags["act2_complete"])

    def test_visual_metadata_act2_after_load(self):
        from play_strawberry import get_visual_metadata
        state = self._state_at_act2_door_shelf()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        metadata = get_visual_metadata(self.module, loaded)
        self.assertEqual(metadata["current_location"], "location.breakroom.fridge.door_shelf")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    # =================================================================
    # Act III save/load tests
    # =================================================================

    def _state_act3_complete(self):
        """Helper: complete Act II and Act III."""
        state = self._state_act2_complete()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.module.choose(state, "deposit_accountability")
        return state

    def test_load_restores_act3_complete_state(self):
        """Prove load restores Act III completion state."""
        state = self._state_act3_complete()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertTrue(loaded.flags["act3_started"])
        self.assertTrue(loaded.flags["met_vendrick"])
        self.assertTrue(loaded.flags["vendrick_price_named"])
        self.assertTrue(loaded.flags["snack_wraiths_resolved"])
        self.assertTrue(loaded.flags["accountability_token_obtained"])
        self.assertTrue(loaded.flags["act3_complete"])
        self.assertIn("item.accountability_token", loaded.inventory)

    def test_visual_metadata_act3_after_load(self):
        """Prove visual metadata works in Act III after load."""
        from play_strawberry import get_visual_metadata
        state = self._state_act3_complete()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        metadata = get_visual_metadata(self.module, loaded)
        self.assertEqual(metadata["current_location"], "location.breakroom.accountability_slot")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    # =================================================================
    # Act IV save/load tests
    # =================================================================

    def _state_act4_entry(self):
        """Helper: complete Act III and enter Act IV."""
        state = self._state_act3_complete()
        self.module.choose(state, "proceed_to_act4")
        return state

    def _state_act4_complete(self):
        """Helper: complete Act IV via compassion path."""
        state = self._state_act4_entry()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.module.choose(state, "compassion_path")
        self.module.choose(state, "complete_act4")
        return state

    def test_load_restores_act4_entry_state(self):
        """Prove load restores Act IV entry state."""
        state = self._state_act4_entry()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertTrue(loaded.flags["act3_complete"])
        self.assertTrue(loaded.flags["act4_started"])
        self.assertEqual(loaded.current_scene, "scene.act4.labyrinth_entry")
        self.assertEqual(loaded.current_location, "location.fridge_labyrinth.entry")

    def test_load_restores_act4_complete_state(self):
        """Prove load restores Act IV completion state."""
        state = self._state_act4_complete()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        self.assertTrue(loaded.flags["act3_complete"])
        self.assertTrue(loaded.flags["act4_started"])
        self.assertTrue(loaded.flags["moldric_guiding"])
        self.assertTrue(loaded.flags["condiment_gate_opened"])
        self.assertTrue(loaded.flags["leftover_catacombs_crossed"])
        self.assertTrue(loaded.flags["freezer_shrine_visited"])
        self.assertTrue(loaded.flags["freezer_blessing_obtained"])
        self.assertTrue(loaded.flags["sentient_casserole_met"])
        self.assertTrue(loaded.flags["sentient_casserole_resolved"])
        self.assertTrue(loaded.flags["casserole_lid_fragment_obtained"])
        self.assertTrue(loaded.flags["act4_complete"])
        self.assertIn("item.casserole_lid_fragment", loaded.inventory)
        self.assertIn("item.freezer_blessing", loaded.inventory)
        self.assertIn("item.condiment_sigil", loaded.inventory)

    def test_visual_metadata_act4_after_load(self):
        """Prove visual metadata works in Act IV after load."""
        from play_strawberry import get_visual_metadata
        state = self._state_act4_entry()
        self.save_sys.save_game(state)
        loaded = self.save_sys.load_game()
        self.assertIsNotNone(loaded)
        metadata = get_visual_metadata(self.module, loaded)
        self.assertEqual(metadata["current_location"], "location.fridge_labyrinth.entry")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])


if __name__ == "__main__":
    unittest.main()
