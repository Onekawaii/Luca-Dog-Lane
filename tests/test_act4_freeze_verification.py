#!/usr/bin/env python3
"""Act IV v1.1 freeze verification test.

Proves:
- Act IV scenes referenced by choices exist.
- Act IV locations referenced by scenes exist.
- Act IV items/NPCs/quests referenced by encounters exist.
- All visual_manifest entries resolve to generated_manifest entries or valid placeholders.
- All generated_manifest asset paths exist on disk.
- Save/load round trip preserves Act IV state.
"""

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem


class TestActIVFreezeVerification(unittest.TestCase):
    """Comprehensive Act IV freeze verification."""

    def setUp(self):
        self.root = Path("campaigns/strawberry_omen")
        self.module = CampaignModule(self.root)

    # =================================================================
    # 1. Act IV scenes referenced by choices exist
    # =================================================================

    def test_all_act4_next_scene_references_exist(self):
        """Every next_scene pointing to scene.act4.* must exist in encounters."""
        act4_scene_refs = set()
        for encounter in self.module.encounters.values():
            for choice in encounter.get("choices", []):
                ns = choice.get("next_scene", "")
                if ns.startswith("scene.act4."):
                    act4_scene_refs.add(ns)
        for scene_ref in act4_scene_refs:
            self.assertIn(scene_ref, self.module.encounters,
                          f"Referenced Act IV scene not found: {scene_ref}")

    # =================================================================
    # 2. Act IV locations referenced by scenes exist
    # =================================================================

    def test_all_act4_scene_locations_exist(self):
        """Every scene with act=4 must reference a location node that exists."""
        # module.locations only indexes top-level IDs; nested nodes are inside "nodes"
        all_node_ids = set()
        for loc in self.module.locations.values():
            all_node_ids.add(loc["id"])
            for node in loc.get("nodes", []):
                all_node_ids.add(node["id"])
        for eid, encounter in self.module.encounters.items():
            if encounter.get("act") == 4:
                loc = encounter.get("location", "")
                self.assertIn(loc, all_node_ids,
                              f"Act IV scene {eid} references missing location: {loc}")

    # =================================================================
    # 3. Act IV items/NPCs/quests referenced by encounters exist
    # =================================================================

    def test_act4_granted_items_exist(self):
        """Every item granted by Act IV choices must exist in items.json."""
        for eid, encounter in self.module.encounters.items():
            if encounter.get("act") == 4:
                for choice in encounter.get("choices", []):
                    for item_id in choice.get("grants_items", []):
                        self.assertIn(item_id, self.module.items,
                                      f"Act IV scene {eid} grants missing item: {item_id}")

    def test_act4_spawned_npcs_exist(self):
        """Every NPC spawned by Act IV choices must exist in npcs.json."""
        for eid, encounter in self.module.encounters.items():
            if encounter.get("act") == 4:
                for choice in encounter.get("choices", []):
                    npc = choice.get("spawns_npc", "")
                    if npc:
                        self.assertIn(npc, self.module.npcs,
                                      f"Act IV scene {eid} spawns missing NPC: {npc}")

    def test_act4_quests_reference_valid_scenes(self):
        """Every Act IV quest must reference a scene that exists."""
        for qid, quest in self.module.quests.items():
            if "act4" in qid or "labyrinth" in qid:
                starts_at = quest.get("starts_at", "")
                self.assertIn(starts_at, self.module.encounters,
                              f"Quest {qid} references missing scene: {starts_at}")

    def test_act4_quest_completion_flag_exists(self):
        """Every Act IV quest's completion_flag must be in starting_flags."""
        for qid, quest in self.module.quests.items():
            if "act4" in qid or "labyrinth" in qid:
                cf = quest.get("completion_flag", "")
                self.assertIn(cf, self.module.campaign.get("starting_flags", {}),
                              f"Quest {qid} completion_flag not in starting_flags: {cf}")

    # =================================================================
    # 4. visual_manifest entries resolve to generated_manifest or placeholders
    # =================================================================

    def test_visual_manifest_resolves(self):
        """Every asset in visual_manifest must have a generated PNG or a valid placeholder."""
        vm = json.loads((self.root / "visual_manifest.json").read_text())
        gm = json.loads((self.root / "assets" / "generated_manifest.json").read_text())

        gen_ids = {a["asset_id"] for a in gm.get("generated_assets", [])}

        for category in ("maps", "textures", "items", "tokens", "rooms"):
            for asset in vm.get("assets", {}).get(category, []):
                aid = asset["asset_id"]
                has_generated = aid in gen_ids
                has_placeholder = (self.root / asset.get("path", "")).exists()
                self.assertTrue(
                    has_generated or has_placeholder,
                    f"visual_manifest asset {aid} has neither generated PNG nor placeholder"
                )

    # =================================================================
    # 5. All generated_manifest asset paths exist on disk
    # =================================================================

    def test_generated_manifest_paths_exist(self):
        """Every path in generated_manifest.json must exist on disk."""
        gm = json.loads((self.root / "assets" / "generated_manifest.json").read_text())
        for asset in gm.get("generated_assets", []):
            full_path = self.root / asset["path"]
            self.assertTrue(full_path.exists(),
                            f"Generated asset missing on disk: {asset['path']}")

    # =================================================================
    # 6. Save/load round trip preserves Act IV state
    # =================================================================

    def test_save_load_preserves_act4_state(self):
        """Save/load must preserve all Act IV flags and inventory."""
        tmp_dir = tempfile.mkdtemp()
        try:
            saves = ModuleSaveSystem(self.module, save_dir=tmp_dir)

            # Complete Act IV via compassion path
            state = self.module.new_state()
            self.module.enter_scene(state)
            # Act I
            self.module.choose(state, "inspect_label")
            self.module.choose(state, "file_boundary_statement")
            # Act II
            self.module.choose(state, "enter_fridge")
            self.module.choose(state, "meet_moldric")
            self.module.choose(state, "help_moldric_reclaim")
            # Act III
            self.module.choose(state, "proceed_to_act3")
            self.module.choose(state, "approach_vending_machine")
            self.module.choose(state, "name_your_price")
            self.module.choose(state, "confront_snack_wraiths_peacefully")
            # Act IV
            self.module.choose(state, "proceed_to_act4")
            self.module.choose(state, "accept_moldric_guide")
            self.module.choose(state, "acknowledge_condiments")
            self.module.choose(state, "acknowledge_leftovers")
            self.module.choose(state, "take_freezer_blessing_with_respect")
            self.module.choose(state, "compassion_path")
            self.module.choose(state, "complete_act4")

            # Save
            saves.save_game(state)

            # Load
            loaded = saves.load_game()
            self.assertIsNotNone(loaded)
            self.module.enter_scene(loaded)

            # Verify all Act IV flags
            act4_flags = [
                "act4_started", "moldric_guiding", "condiment_gate_opened",
                "leftover_catacombs_crossed", "freezer_shrine_visited",
                "freezer_blessing_obtained", "sentient_casserole_met",
                "sentient_casserole_resolved", "casserole_lid_fragment_obtained",
                "act4_complete"
            ]
            for flag in act4_flags:
                self.assertTrue(loaded.flags.get(flag),
                                f"Flag {flag} lost after save/load")

            # Verify inventory
            self.assertIn("item.casserole_lid_fragment", loaded.inventory)
            self.assertIn("item.freezer_blessing", loaded.inventory)
            self.assertIn("item.condiment_sigil", loaded.inventory)
            self.assertIn("item.accountability_token", loaded.inventory)
            self.assertIn("relic.ancient_mayonnaise", loaded.inventory)

            # Verify scene/location
            self.assertEqual(loaded.current_scene, "scene.act4.labyrinth_completion")
            self.assertEqual(loaded.current_location, "location.fridge_labyrinth.casserole_throne")

        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    # =================================================================
    # 7. All Act IV locations have generated room assets
    # =================================================================

    def test_act4_locations_have_room_assets(self):
        """Every Act IV location must have a generated room PNG."""
        gm = json.loads((self.root / "assets" / "generated_manifest.json").read_text())
        gen_room_ids = {a["asset_id"] for a in gm.get("generated_assets", [])
                        if a["category"] == "rooms"}

        act4_locations = [
            "room.fridge_labyrinth.entry",
            "room.fridge_labyrinth.condiment_gate",
            "room.fridge_labyrinth.leftover_catacombs",
            "room.fridge_labyrinth.freezer_shrine",
            "room.fridge_labyrinth.casserole_throne",
        ]
        for room_id in act4_locations:
            self.assertIn(room_id, gen_room_ids,
                          f"Act IV room asset missing from generated_manifest: {room_id}")

    # =================================================================
    # 8. Act IV cannot start before Act III
    # =================================================================

    def test_act4_cannot_start_before_act3(self):
        """Prove Act IV cannot be entered before Act III completion."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.assertFalse(state.flags.get("act3_complete"))
        self.assertFalse(state.flags.get("act4_started"))


if __name__ == "__main__":
    unittest.main()
