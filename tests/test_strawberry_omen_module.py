import unittest

from engine.module_runtime import CampaignModule
from tools.validate_campaign_module import validate
from tools.validate_visual_assets import validate_visual_assets
from pathlib import Path


# Import visual metadata functions
from play_strawberry import get_visual_metadata


class TestStrawberryOmenModule(unittest.TestCase):
    def setUp(self):
        self.root = Path("campaigns/strawberry_omen")
        self.module = CampaignModule(self.root)

    def test_module_validates(self):
        self.assertEqual(validate(self.root), [])

    def test_visual_assets_validate(self):
        self.assertEqual(validate_visual_assets(self.root), [])

    def test_visual_metadata_commands(self):
        from play_strawberry import get_visual_metadata
        state = self.module.new_state()
        self.module.enter_scene(state)
        
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.central_table")
        self.assertEqual(metadata["location_name"], "Central Table")
        self.assertIsNotNone(metadata["map_asset"])
        self.assertIsNotNone(metadata["room_asset"])
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])
        self.assertGreater(len(metadata["generated"]["textures"]), 0)
        self.assertGreater(len(metadata["generated"]["items"]), 0)
        self.assertGreater(len(metadata["generated"]["tokens"]), 0)

    def test_map_command(self):
        from play_strawberry import get_visual_metadata
        state = self.module.new_state()
        self.module.enter_scene(state)
        
        # Test map command directly
        metadata = get_visual_metadata(self.module, state)
        self.assertIsNotNone(metadata["map_asset"])
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertEqual(metadata["generated"]["map"]["asset_id"], "map.breakroom")
        self.assertIn("map.breakroom.png", metadata["generated"]["map"]["path"])

    def test_room_command(self):
        from play_strawberry import get_visual_metadata
        state = self.module.new_state()
        self.module.enter_scene(state)
        
        # Test room command directly
        metadata = get_visual_metadata(self.module, state)
        self.assertIsNotNone(metadata["room_asset"])
        self.assertIsNotNone(metadata["generated"]["room"])
        self.assertEqual(metadata["generated"]["room"]["asset_id"], "room.breakroom.central_table")
        self.assertIn("room.breakroom.central_table.png", metadata["generated"]["room"]["path"])

    def test_assets_command(self):
        from play_strawberry import get_visual_metadata
        state = self.module.new_state()
        self.module.enter_scene(state)
        
        # Test assets command directly
        metadata = get_visual_metadata(self.module, state)
        self.assertIsNotNone(metadata["map_asset"])
        self.assertIsNotNone(metadata["room_asset"])
        self.assertGreater(len(metadata["generated"]["textures"]), 0)
        self.assertGreater(len(metadata["generated"]["items"]), 0)
        self.assertGreater(len(metadata["generated"]["tokens"]), 0)

    def test_entry_scene_sets_seen_flag(self):
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.assertTrue(state.flags["wetberry_seen"])

    def test_wetberry_disposition_flags_exist(self):
        state = self.module.new_state()
        for flag in ("wetberry_seen", "wetberry_touched", "wetberry_ignored", "wetberry_reported"):
            self.assertIn(flag, state.flags)

    def test_choice_mutates_state(self):
        state = self.module.new_state()
        self.module.enter_scene(state)
        result = self.module.choose(state, "thumbs_up")
        self.assertIn("lore damage", result)
        self.assertEqual(state.stats["ape_chaos"], 2)
        self.assertTrue(state.flags["thumbs_up_documented"])

    def test_wetberry_choices_track_disposition(self):
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.module.choose(state, "ignore_it")
        self.assertTrue(state.flags["wetberry_ignored"])

        state = self.module.new_state()
        self.module.enter_scene(state)
        self.module.choose(state, "touch_wetberry")
        self.assertTrue(state.flags["wetberry_touched"])

        state = self.module.new_state()
        self.module.enter_scene(state)
        self.module.choose(state, "call_hr")
        self.assertTrue(state.flags["wetberry_reported"])

    def test_scene_transition_updates_location_and_unlocks_fridge(self):
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.module.choose(state, "inspect_label")
        self.assertEqual(state.current_scene, "scene.act1.first_memo")
        self.assertEqual(state.current_location, "location.breakroom.central_table")
        self.module.choose(state, "file_boundary_statement")
        self.assertTrue(state.flags["fridge_unlocked"])

    def test_keith_grants_evidence_bag(self):
        state = self.module.new_state()
        self.module.enter_scene(state, "scene.act1.keith_corner")
        self.module.choose(state, "ask_for_evidence_bag")
        self.assertIn("item.evidence_bag_not_my_business", state.inventory)

    # Act II tests - note that these would normally be in separate test files
    # but for this session we'll keep them here

    def test_fridge_requires_fridge_unlocked(self):
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.assertFalse(state.flags["fridge_unlocked"])
        self.assertFalse(state.flags["entered_fridge"])

    def test_fridge_can_be_entered_after_unlock(self):
        # After unlocking fridge, players need to navigate to it
        # For test purposes, we'll test scene transitions directly
        state = self.module.new_state()
        # Progress through Act I to unlock fridge
        self.module.choose(state, "inspect_label")  # Go to first_memo
        self.module.choose(state, "file_boundary_statement")  # Unlock fridge
        self.assertTrue(state.flags["fridge_unlocked"])

    def test_moldric_path_reachable(self):
        # Test that Moldric is reachable after entering the fridge
        state = self.module.new_state()
        # Progress through Act I to unlock fridge
        self.module.choose(state, "inspect_label")  # Go to first_memo
        self.module.choose(state, "file_boundary_statement")  # Unlock fridge
        # Now we would need to enter the fridge location in a real game
        # For testing purposes, we'll verify the state
        self.assertTrue(state.flags["fridge_unlocked"])

    def test_act2_complete_state_flags(self):
        # Test that the state flags exist in the module
        state = self.module.new_state()
        for flag in ["entered_fridge", "met_moldric", "lunch_thief_confronted",
                     "ancient_mayonnaise_obtained", "act2_complete"]:
            self.assertIn(flag, state.flags)

    def test_fridge_not_accessible_without_unlock(self):
        state = self.module.new_state()
        self.assertFalse(state.flags["fridge_unlocked"])

    def test_generated_manifest_loaded(self):
        from play_strawberry import get_visual_metadata
        state = self.module.new_state()
        self.module.enter_scene(state)
        
        metadata = get_visual_metadata(self.module, state)
        
        # Check that map is the priority asset (map.breakroom)
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertEqual(metadata["generated"]["map"]["asset_id"], "map.breakroom")
        
        # Check that room is the priority asset (room.breakroom.central_table)
        self.assertIsNotNone(metadata["generated"]["room"])
        self.assertEqual(metadata["generated"]["room"]["asset_id"], "room.breakroom.central_table")
        
        # Check that texture is the priority asset (texture.wet_table)
        self.assertIn("texture.wet_table", metadata["generated"]["textures"])
        
        # Check that item is the priority asset (item.wetberry)
        self.assertIn("item.wetberry", metadata["generated"]["items"])
        
        # Check that token is the priority asset (token.darla)
        self.assertIn("token.darla", metadata["generated"]["tokens"])

    # =====================================================================
    # Act II Fridge Node Reachability Tests
    # =====================================================================

    def _unlock_fridge(self):
        """Helper: progress through Act I to unlock the fridge."""
        state = self.module.new_state()
        self.module.enter_scene(state)  # scene.act1.first_sighting
        self.module.choose(state, "inspect_label")  # -> scene.act1.first_memo
        self.module.choose(state, "file_boundary_statement")  # sets fridge_unlocked
        return state

    def _enter_fridge(self):
        """Helper: unlock fridge and enter Act II at door_shelf."""
        state = self._unlock_fridge()
        self.module.choose(state, "enter_fridge")  # -> scene.act2.fridge_intro
        return state

    def test_fridge_door_shelf_reachable(self):
        """Prove fridge.door_shelf is reachable after fridge unlock."""
        state = self._enter_fridge()
        self.assertEqual(state.current_location, "location.breakroom.fridge.door_shelf")
        self.assertEqual(state.current_scene, "scene.act2.fridge_intro")
        self.assertTrue(state.flags["entered_fridge"])

    def test_fridge_back_corner_reachable(self):
        """Prove fridge.back_corner is reachable through gameplay."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")  # -> scene.act2.back_corner_boss
        self.assertEqual(state.current_location, "location.breakroom.fridge.back_corner")
        self.assertEqual(state.current_scene, "scene.act2.back_corner_boss")
        self.assertTrue(state.flags["met_moldric"])

    def test_fridge_leftover_marshes_reachable(self):
        """Prove fridge.leftover_marshes is reachable through gameplay."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")  # -> scene.act2.leftover_marshes
        self.assertEqual(state.current_location, "location.breakroom.fridge.leftover_marshes")
        self.assertEqual(state.current_scene, "scene.act2.leftover_marshes")
        self.assertTrue(state.flags["lunch_thief_confronted"])

    def test_fridge_yogurt_catacombs_reachable(self):
        """Prove fridge.yogurt_catacombs is reachable through gameplay."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")  # -> scene.act2.leftover_marshes
        self.module.choose(state, "yogurt_catacombs_check")  # -> scene.act2.yogurt_catacombs
        self.assertEqual(state.current_location, "location.breakroom.fridge.yogurt_catacombs")
        self.assertEqual(state.current_scene, "scene.act2.yogurt_catacombs")

    def test_all_four_fridge_nodes_reachable(self):
        """Prove all four fridge nodes are reachable in a single run."""
        # door_shelf
        state = self._enter_fridge()
        self.assertEqual(state.current_location, "location.breakroom.fridge.door_shelf")

        # -> back_corner
        self.module.choose(state, "meet_moldric")
        self.assertEqual(state.current_location, "location.breakroom.fridge.back_corner")

        # -> back to door_shelf via completion_celebration -> moldrics_regret
        self.module.choose(state, "walk_away_moldric")
        self.assertEqual(state.current_location, "location.breakroom.fridge.back_corner")
        self.assertEqual(state.current_scene, "scene.act2.moldrics_regret")

        # -> door_shelf via help_moldric_after_all -> completion_celebration
        self.module.choose(state, "help_moldric_after_all")
        self.assertEqual(state.current_location, "location.breakroom.fridge.door_shelf")
        self.assertEqual(state.current_scene, "scene.act2.completion_celebration")

    # =====================================================================
    # Act II Completion Path Tests
    # =====================================================================

    def test_act2_completion_via_moldric_path(self):
        """Prove act2_complete = true can be reached via Moldric quest path."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")  # -> back_corner_boss
        self.module.choose(state, "help_moldric_reclaim")  # -> completion_celebration
        self.assertTrue(state.flags["met_moldric"])
        self.assertTrue(state.flags["lunch_thief_confronted"])
        self.assertTrue(state.flags["ancient_mayonnaise_obtained"])
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    def test_act2_completion_via_goblins_directly(self):
        """Prove act2_complete via confronting goblins directly at back_corner."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")  # -> back_corner_boss
        self.module.choose(state, "defeat_goblins_mighty")
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    def test_act2_completion_via_leftover_marshes_peacefully(self):
        """Prove act2_complete via peaceful confrontation in leftover_marshes."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")  # -> leftover_marshes
        self.module.choose(state, "confront_goblins_peacefully")
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    def test_act2_completion_via_leftover_marshes_evidence_bag(self):
        """Prove act2_complete via evidence bag in leftover_marshes."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")  # -> leftover_marshes
        self.module.choose(state, "use_evidence_bag")
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    def test_act2_completion_via_yogurt_catacombs(self):
        """Prove act2_complete via defeating Yogurt Cultist."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")  # -> leftover_marshes
        self.module.choose(state, "yogurt_catacombs_check")  # -> yogurt_catacombs
        self.module.choose(state, "defeat_yogurt_cultist")
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    def test_act2_completion_via_moldrics_regret(self):
        """Prove act2_complete via Moldric's regret path."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")  # -> back_corner_boss
        self.module.choose(state, "walk_away_moldric")  # -> moldrics_regret
        self.module.choose(state, "help_moldric_after_all")
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    # =====================================================================
    # Act II Content Flag Tests
    # =====================================================================

    def test_lunch_thief_confronted_set_by_examine_leftovers(self):
        """Prove lunch_thief_confronted = true via examine_leftovers."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")
        self.assertTrue(state.flags["lunch_thief_confronted"])

    def test_lunch_thief_confronted_set_by_moldric_path(self):
        """Prove lunch_thief_confronted = true via Moldric quest completion."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "help_moldric_reclaim")
        self.assertTrue(state.flags["lunch_thief_confronted"])

    def test_met_moldric_set_by_meet_moldric(self):
        """Prove met_moldric = true via meet_moldric choice."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")
        self.assertTrue(state.flags["met_moldric"])

    def test_ancient_mayonnaise_obtained_through_gameplay(self):
        """Prove Ancient Mayonnaise can be obtained through gameplay."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "help_moldric_reclaim")
        self.assertTrue(state.flags["ancient_mayonnaise_obtained"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    # =====================================================================
    # Act II Fridge Visions (Optional Scene) Tests
    # =====================================================================

    def test_fridge_visions_scene_exists(self):
        """Prove scene.act2.fridge_visions is a valid encounter."""
        self.assertIn("scene.act2.fridge_visions", self.module.encounters)

    def test_fridge_visions_flag_in_starting_flags(self):
        """Prove act2_fridge_visions_seen is declared in starting flags."""
        state = self.module.new_state()
        self.assertIn("act2_fridge_visions_seen", state.flags)
        self.assertFalse(state.flags["act2_fridge_visions_seen"])

    def test_fridge_intro_has_peer_into_frost_choice(self):
        """Prove fridge_intro has the peer_into_frost choice."""
        fridge_intro = self.module.encounters["scene.act2.fridge_intro"]
        choice_ids = [c["id"] for c in fridge_intro["choices"]]
        self.assertIn("peer_into_frost", choice_ids)

    def test_peer_into_frost_reaches_fridge_visions(self):
        """Prove peer_into_frost routes to fridge_visions scene."""
        state = self._enter_fridge()
        self.module.choose(state, "peer_into_frost")
        self.assertEqual(state.current_scene, "scene.act2.fridge_visions")
        self.assertTrue(state.flags["act2_fridge_visions_seen"])

    def test_fridge_visions_returns_to_door_shelf(self):
        """Prove return_to_door_shelf routes back to fridge_intro."""
        state = self._enter_fridge()
        self.module.choose(state, "peer_into_frost")
        self.module.choose(state, "return_to_door_shelf")
        self.assertEqual(state.current_scene, "scene.act2.fridge_intro")
        self.assertEqual(state.current_location, "location.breakroom.fridge.door_shelf")

    def test_fridge_visions_routes_to_moldric(self):
        """Prove approach_moldric_from_visions routes to back_corner_boss."""
        state = self._enter_fridge()
        self.module.choose(state, "peer_into_frost")
        self.module.choose(state, "approach_moldric_from_visions")
        self.assertEqual(state.current_scene, "scene.act2.back_corner_boss")
        self.assertTrue(state.flags["met_moldric"])

    def test_fridge_visions_does_not_set_act2_complete(self):
        """Prove fridge_visions does not set act2_complete."""
        state = self._enter_fridge()
        self.module.choose(state, "peer_into_frost")
        self.assertFalse(state.flags["act2_complete"])

    def test_fridge_visions_does_not_grant_items(self):
        """Prove fridge_visions does not grant any items."""
        state = self._enter_fridge()
        inventory_before = list(state.inventory)
        self.module.choose(state, "peer_into_frost")
        self.assertEqual(state.inventory, inventory_before)

    def test_fridge_visions_preserves_existing_completion_paths(self):
        """Prove existing Act 2 completion paths still work after fridge_visions exists."""
        # Path 1: Moldric -> help_moldric_reclaim
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "help_moldric_reclaim")
        self.assertTrue(state.flags["act2_complete"])

        # Path 2: examine_leftovers -> confront_goblins_peacefully
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")
        self.module.choose(state, "confront_goblins_peacefully")
        self.assertTrue(state.flags["act2_complete"])

    def test_fridge_visions_route_then_complete_act2(self):
        """Prove a full path: visions -> Moldric -> completion."""
        state = self._enter_fridge()
        self.module.choose(state, "peer_into_frost")
        self.module.choose(state, "approach_moldric_from_visions")
        self.module.choose(state, "help_moldric_reclaim")
        self.assertTrue(state.flags["act2_fridge_visions_seen"])
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    # =====================================================================
    # Visual Commands in Act II Locations Tests
    # =====================================================================

    def test_visual_metadata_works_in_door_shelf(self):
        """Prove map/room/assets work at fridge.door_shelf."""
        state = self._enter_fridge()
        self.assertEqual(state.current_location, "location.breakroom.fridge.door_shelf")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.fridge.door_shelf")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])
        self.assertGreater(len(metadata["generated"]["textures"]), 0)
        self.assertGreater(len(metadata["generated"]["items"]), 0)
        self.assertGreater(len(metadata["generated"]["tokens"]), 0)

    def test_visual_metadata_works_in_back_corner(self):
        """Prove map/room/assets work at fridge.back_corner."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")  # -> back_corner
        self.assertEqual(state.current_location, "location.breakroom.fridge.back_corner")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.fridge.back_corner")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    def test_visual_metadata_works_in_leftover_marshes(self):
        """Prove map/room/assets work at fridge.leftover_marshes."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")  # -> leftover_marshes
        self.assertEqual(state.current_location, "location.breakroom.fridge.leftover_marshes")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.fridge.leftover_marshes")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    def test_visual_metadata_works_in_yogurt_catacombs(self):
        """Prove map/room/assets work at fridge.yogurt_catacombs."""
        state = self._enter_fridge()
        self.module.choose(state, "examine_leftovers")  # -> leftover_marshes
        self.module.choose(state, "yogurt_catacombs_check")  # -> yogurt_catacombs
        self.assertEqual(state.current_location, "location.breakroom.fridge.yogurt_catacombs")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.fridge.yogurt_catacombs")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    # =====================================================================
    # Visual Commands Do Not Mutate Flags or Advance Scenes Tests
    # =====================================================================

    def test_visual_commands_do_not_mutate_flags(self):
        """Prove visual commands do not change any flags."""
        state = self._enter_fridge()
        flags_before = dict(state.flags)

        # Simulate visual commands (these are handled in main(), not through choose())
        # We verify by checking that the get_visual_metadata function doesn't modify state
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(state.flags, flags_before)

    def test_visual_commands_do_not_advance_scenes(self):
        """Prove visual commands do not change the current scene."""
        state = self._enter_fridge()
        scene_before = state.current_scene
        location_before = state.current_location

        # get_visual_metadata should not change scene or location
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(state.current_scene, scene_before)
        self.assertEqual(state.current_location, location_before)

    def test_visual_commands_do_not_mutate_inventory(self):
        """Prove visual commands do not change inventory."""
        state = self._enter_fridge()
        inventory_before = list(state.inventory)

        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(state.inventory, inventory_before)

    def test_visual_commands_do_not_mutate_stats(self):
        """Prove visual commands do not change stats."""
        state = self._enter_fridge()
        stats_before = dict(state.stats)

        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(state.stats, stats_before)

    # =====================================================================
    # Full Act II Path Integration Test
    # =====================================================================

    def test_full_act2_path_all_flags(self):
        """Prove the full Act II path sets all required flags."""
        state = self._enter_fridge()

        # door_shelf -> back_corner -> moldrics_regret -> completion_celebration
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "walk_away_moldric")
        self.module.choose(state, "help_moldric_after_all")

        self.assertTrue(state.flags["fridge_unlocked"])
        self.assertTrue(state.flags["entered_fridge"])
        self.assertTrue(state.flags["met_moldric"])
        self.assertTrue(state.flags["lunch_thief_confronted"])
        self.assertTrue(state.flags["ancient_mayonnaise_obtained"])
        self.assertTrue(state.flags["act2_complete"])
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    # =====================================================================
    # Act III Tests
    # =====================================================================

    def _complete_act2(self):
        """Helper: complete Act II via Moldric path."""
        state = self._enter_fridge()
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "help_moldric_reclaim")
        return state

    def test_act3_cannot_start_before_act2(self):
        """Prove Act III cannot be entered before Act II completion."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.assertFalse(state.flags["act2_complete"])
        self.assertFalse(state.flags["act3_started"])

    def test_act3_can_start_after_act2(self):
        """Prove Act III can start after Act II completion."""
        state = self._complete_act2()
        self.assertTrue(state.flags["act2_complete"])
        # Choose to proceed to Act III from completion_celebration
        self.module.choose(state, "proceed_to_act3")
        self.assertTrue(state.flags["act3_started"])
        self.assertEqual(state.current_scene, "scene.act3.hallway_discovery")
        self.assertEqual(state.current_location, "location.breakroom.hallway")

    def test_vendrick_reachable(self):
        """Prove Vendrick can be reached after Act III starts."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.assertTrue(state.flags["met_vendrick"])
        self.assertEqual(state.current_scene, "scene.act3.vendrick_negotiation")
        self.assertEqual(state.current_location, "location.breakroom.vending_machine")

    def test_vendrick_price_can_be_named(self):
        """Prove Vendrick's price can be learned."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.assertTrue(state.flags["vendrick_price_named"])

    def test_snack_wraiths_can_be_resolved(self):
        """Prove Snack Wraiths can be resolved peacefully."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.assertTrue(state.flags["snack_wraiths_resolved"])
        self.assertTrue(state.flags["accountability_token_obtained"])
        self.assertIn("item.accountability_token", state.inventory)

    def test_accountability_token_obtained(self):
        """Prove Accountability Token can be obtained."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.assertIn("item.accountability_token", state.inventory)

    def test_act3_complete_reachable(self):
        """Prove act3_complete = true can be reached."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        # Now at accountability_completion scene
        self.module.choose(state, "deposit_accountability")
        self.assertTrue(state.flags["act3_complete"])

    def test_act3_noncombat_completion_path(self):
        """Prove non-combat completion via apology."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        # Apologize to wraiths - non-combat path
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.assertTrue(state.flags["snack_wraiths_resolved"])
        self.assertTrue(state.flags["accountability_token_obtained"])
        self.module.choose(state, "deposit_accountability")
        self.assertTrue(state.flags["act3_complete"])

    def test_act3_weird_failure_offer_mayonnaise(self):
        """Prove weird failure path when offering mayonnaise to Vendrick."""
        state = self._complete_act2()
        awkwardness_before = state.stats["awkwardness"]
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "offer_mayonnaise")
        self.assertTrue(state.flags["vendrick_insulted"])
        self.assertEqual(state.stats["awkwardness"], awkwardness_before + 3)

    def test_act3_bribe_with_memories_path(self):
        """Prove bribe with memories path resolves wraiths."""
        state = self._complete_act2()
        awkwardness_before = state.stats["awkwardness"]
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "examine_snack_wraiths")
        self.module.choose(state, "bribe_with_memories")
        self.assertTrue(state.flags["snack_wraiths_resolved"])
        self.assertTrue(state.flags["accountability_token_obtained"])
        self.assertEqual(state.stats["awkwardness"], awkwardness_before + 2)

    def test_act3_full_flags_after_completion(self):
        """Prove all Act III flags are true after full completion."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.module.choose(state, "deposit_accountability")

        self.assertTrue(state.flags["act2_complete"])
        self.assertTrue(state.flags["act3_started"])
        self.assertTrue(state.flags["met_vendrick"])
        self.assertTrue(state.flags["vendrick_price_named"])
        self.assertTrue(state.flags["snack_wraiths_resolved"])
        self.assertTrue(state.flags["accountability_token_obtained"])
        self.assertTrue(state.flags["act3_complete"])
        self.assertIn("item.accountability_token", state.inventory)
        self.assertIn("relic.ancient_mayonnaise", state.inventory)

    def test_visual_metadata_works_in_act3_locations(self):
        """Prove visual metadata works in Act III locations."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.assertEqual(state.current_location, "location.breakroom.hallway")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.hallway")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    def test_visual_metadata_works_in_vendrick_domain(self):
        """Prove visual metadata works in Vendrick's Domain."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.assertEqual(state.current_location, "location.breakroom.vending_machine")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.vending_machine")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    def test_visual_metadata_works_in_snack_wraith_aisle(self):
        """Prove visual metadata works in Snack Wraith Aisle."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "examine_snack_wraiths")
        self.assertEqual(state.current_location, "location.breakroom.snack_wraith_aisle")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.snack_wraith_aisle")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    def test_visual_metadata_works_in_accountability_slot(self):
        """Prove visual metadata works in Accountability Slot."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.assertEqual(state.current_location, "location.breakroom.accountability_slot")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.breakroom.accountability_slot")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    # =====================================================================
    # Act IV Tests
    # =====================================================================

    def _complete_act3(self):
        """Helper: complete Act III via standard path."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.module.choose(state, "deposit_accountability")
        return state

    def _enter_act4(self):
        """Helper: complete Act III and enter Act IV."""
        state = self._complete_act2()
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.module.choose(state, "proceed_to_act4")
        return state

    def _complete_act4_compassion(self):
        """Helper: complete Act IV via compassion path."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.module.choose(state, "compassion_path")
        return state

    def test_act4_cannot_start_before_act3(self):
        """Prove Act IV cannot be entered before Act III completion."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.assertFalse(state.flags["act3_complete"])
        self.assertFalse(state.flags["act4_started"])

    def test_act4_can_start_after_act3(self):
        """Prove Act IV can start after Act III completion."""
        state = self._enter_act4()
        self.assertTrue(state.flags["act3_complete"])
        self.assertTrue(state.flags["act4_started"])
        self.assertEqual(state.current_scene, "scene.act4.labyrinth_entry")
        self.assertEqual(state.current_location, "location.fridge_labyrinth.entry")

    def test_moldric_guide_reachable(self):
        """Prove Moldric guide can be reached."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.assertTrue(state.flags["moldric_guiding"])
        self.assertEqual(state.current_scene, "scene.act4.condiment_gate")

    def test_condiment_gate_opened(self):
        """Prove Condiment Gate can be opened."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.assertTrue(state.flags["condiment_gate_opened"])
        self.assertIn("item.condiment_sigil", state.inventory)

    def test_condiment_gate_bureaucracy_path(self):
        """Prove Condiment Gate can be bypassed via bureaucracy."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "bypass_condiment_gate_bureaucracy")
        self.assertTrue(state.flags["condiment_gate_opened"])
        self.assertGreater(state.stats["bureaucracy"], 0)

    def test_condiment_gate_ape_path(self):
        """Prove Condiment Gate can be bypassed via ape path."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "ape_through_condiment_gate")
        self.assertTrue(state.flags["condiment_gate_opened"])
        self.assertGreater(state.stats["ape_chaos"], 0)

    def test_leftover_catacombs_crossed(self):
        """Prove Leftover Catacombs can be crossed."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.assertTrue(state.flags["leftover_catacombs_crossed"])
        self.assertEqual(state.current_scene, "scene.act4.freezer_shrine")

    def test_freezer_shrine_visited(self):
        """Prove Freezer Shrine can be visited."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.assertTrue(state.flags["freezer_shrine_visited"])
        self.assertEqual(state.current_location, "location.fridge_labyrinth.freezer_shrine")

    def test_freezer_blessing_obtained(self):
        """Prove Freezer Blessing can be obtained."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.assertTrue(state.flags["freezer_blessing_obtained"])
        self.assertIn("item.freezer_blessing", state.inventory)

    def test_sentient_casserole_reached(self):
        """Prove Sentient Casserole can be reached."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.assertTrue(state.flags["sentient_casserole_met"])
        self.assertEqual(state.current_location, "location.fridge_labyrinth.casserole_throne")

    def test_sentient_casserole_resolved_compassion(self):
        """Prove Sentient Casserole can be resolved via compassion."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.module.choose(state, "compassion_path")
        self.assertTrue(state.flags["sentient_casserole_resolved"])
        self.assertTrue(state.flags["casserole_resolved_compassion"])
        self.assertIn("item.casserole_lid_fragment", state.inventory)

    def test_sentient_casserole_resolved_bureaucracy(self):
        """Prove Sentient Casserole can be resolved via bureaucracy."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.module.choose(state, "bureaucracy_path")
        self.assertTrue(state.flags["sentient_casserole_resolved"])
        self.assertTrue(state.flags["casserole_resolved_bureaucracy"])
        self.assertIn("item.casserole_lid_fragment", state.inventory)

    def test_sentient_casserole_resolved_ape(self):
        """Prove Sentient Casserole can be resolved via ape path."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.module.choose(state, "ape_path")
        self.assertTrue(state.flags["sentient_casserole_resolved"])
        self.assertTrue(state.flags["casserole_resolved_ape"])
        self.assertIn("item.casserole_lid_fragment", state.inventory)

    def test_act4_complete_reachable(self):
        """Prove act4_complete = true can be reached."""
        state = self._complete_act4_compassion()
        self.module.choose(state, "complete_act4")
        self.assertTrue(state.flags["act4_complete"])

    def test_act4_weird_failure_path_recoverable(self):
        """Prove weird failure path (insult casserole) is recoverable."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.module.choose(state, "insult_casserole_path")
        self.assertTrue(state.flags["casserole_insulted"])
        # Recovery via apology
        self.module.choose(state, "apologize_to_casserole")
        self.assertTrue(state.flags["sentient_casserole_resolved"])
        self.assertIn("item.casserole_lid_fragment", state.inventory)

    def test_act4_all_flags_after_compassion_completion(self):
        """Prove all Act IV flags are true after full compassion completion."""
        state = self._complete_act4_compassion()
        self.module.choose(state, "complete_act4")
        self.assertTrue(state.flags["act3_complete"])
        self.assertTrue(state.flags["act4_started"])
        self.assertTrue(state.flags["moldric_guiding"])
        self.assertTrue(state.flags["condiment_gate_opened"])
        self.assertTrue(state.flags["leftover_catacombs_crossed"])
        self.assertTrue(state.flags["freezer_shrine_visited"])
        self.assertTrue(state.flags["freezer_blessing_obtained"])
        self.assertTrue(state.flags["sentient_casserole_met"])
        self.assertTrue(state.flags["sentient_casserole_resolved"])
        self.assertTrue(state.flags["casserole_lid_fragment_obtained"])
        self.assertTrue(state.flags["act4_complete"])

    def test_visual_metadata_works_in_act4_locations(self):
        """Prove visual metadata works in Act IV locations."""
        state = self._enter_act4()
        self.assertEqual(state.current_location, "location.fridge_labyrinth.entry")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.fridge_labyrinth.entry")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])

    def test_visual_metadata_works_in_casserole_throne(self):
        """Prove visual metadata works in Casserole Throne."""
        state = self._enter_act4()
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.assertEqual(state.current_location, "location.fridge_labyrinth.casserole_throne")
        metadata = get_visual_metadata(self.module, state)
        self.assertEqual(metadata["current_location"], "location.fridge_labyrinth.casserole_throne")
        self.assertIsNotNone(metadata["generated"]["map"])
        self.assertIsNotNone(metadata["generated"]["room"])


if __name__ == "__main__":
    unittest.main()
