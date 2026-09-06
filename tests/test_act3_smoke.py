#!/usr/bin/env python3
"""Automated smoke test for Act IV v1.1."""

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem
from play_strawberry import get_visual_metadata
import tempfile
import shutil

def smoke_test():
    module = CampaignModule("campaigns/strawberry_omen")
    tmp_dir = tempfile.mkdtemp()
    saves = ModuleSaveSystem(module, save_dir=tmp_dir)

    try:
        # 1. Complete Act II
        state = module.new_state()
        module.enter_scene(state)
        module.choose(state, "inspect_label")
        module.choose(state, "file_boundary_statement")
        module.choose(state, "enter_fridge")
        module.choose(state, "meet_moldric")
        module.choose(state, "help_moldric_reclaim")
        assert state.flags["act2_complete"], "Act II not complete"

        # 2. Enter Act III
        module.choose(state, "proceed_to_act3")
        assert state.flags["act3_started"], "Act III not started"
        assert state.current_scene == "scene.act3.hallway_discovery"

        # 3. Meet Vendrick
        module.choose(state, "approach_vending_machine")
        assert state.flags["met_vendrick"], "Vendrick not met"
        assert state.current_scene == "scene.act3.vendrick_negotiation"

        # 4. Learn the price
        module.choose(state, "name_your_price")
        assert state.flags["vendrick_price_named"], "Price not named"

        # 5. Resolve Snack Wraiths
        module.choose(state, "confront_snack_wraiths_peacefully")
        assert state.flags["snack_wraiths_resolved"], "Wraiths not resolved"
        assert state.flags["accountability_token_obtained"], "Token not obtained"
        assert "item.accountability_token" in state.inventory

        # 6. Enter Act IV through back panel
        module.choose(state, "proceed_to_act4")
        assert state.flags["act3_complete"], "Act III not complete"
        assert state.flags["act4_started"], "Act IV not started"
        assert state.current_scene == "scene.act4.labyrinth_entry"
        assert state.current_location == "location.fridge_labyrinth.entry"

        # 7. Accept Moldric as guide
        module.choose(state, "accept_moldric_guide")
        assert state.flags["moldric_guiding"], "Moldric not guiding"
        assert state.current_scene == "scene.act4.condiment_gate"

        # 8. Open Condiment Gate
        module.choose(state, "acknowledge_condiments")
        assert state.flags["condiment_gate_opened"], "Condiment gate not opened"
        assert "item.condiment_sigil" in state.inventory

        # 9. Cross Leftover Catacombs
        module.choose(state, "acknowledge_leftovers")
        assert state.flags["leftover_catacombs_crossed"], "Catacombs not crossed"
        assert state.current_scene == "scene.act4.freezer_shrine"

        # 10. Visit Freezer Shrine and obtain Blessing
        module.choose(state, "take_freezer_blessing_with_respect")
        assert state.flags["freezer_shrine_visited"], "Shrine not visited"
        assert state.flags["freezer_blessing_obtained"], "Blessing not obtained"
        assert "item.freezer_blessing" in state.inventory

        # 11. Resolve Sentient Casserole via compassion
        module.choose(state, "compassion_path")
        assert state.flags["sentient_casserole_met"], "Casserole not met"
        assert state.flags["sentient_casserole_resolved"], "Casserole not resolved"
        assert state.flags["casserole_lid_fragment_obtained"], "Lid fragment not obtained"
        assert "item.casserole_lid_fragment" in state.inventory

        # 12. Complete Act IV
        module.choose(state, "complete_act4")
        assert state.flags["act4_complete"], "Act IV not complete"

        # 13. Save
        msg = saves.save_game(state)
        assert "saved" in msg.lower(), f"Save failed: {msg}"

        # 14. Load
        loaded = saves.load_game()
        assert loaded is not None, "Load returned None"
        module.enter_scene(loaded)

        # 15. Confirm all Act IV flags
        assert loaded.flags["act3_complete"], "act3_complete lost after load"
        assert loaded.flags["act4_started"], "act4_started lost after load"
        assert loaded.flags["moldric_guiding"], "moldric_guiding lost after load"
        assert loaded.flags["condiment_gate_opened"], "condiment_gate_opened lost after load"
        assert loaded.flags["leftover_catacombs_crossed"], "leftover_catacombs_crossed lost after load"
        assert loaded.flags["freezer_shrine_visited"], "freezer_shrine_visited lost after load"
        assert loaded.flags["freezer_blessing_obtained"], "freezer_blessing_obtained lost after load"
        assert loaded.flags["sentient_casserole_met"], "sentient_casserole_met lost after load"
        assert loaded.flags["sentient_casserole_resolved"], "sentient_casserole_resolved lost after load"
        assert loaded.flags["casserole_lid_fragment_obtained"], "casserole_lid_fragment_obtained lost after load"
        assert loaded.flags["act4_complete"], "act4_complete lost after load"
        assert "item.casserole_lid_fragment" in loaded.inventory, "Lid fragment lost from inventory"
        assert "item.freezer_blessing" in loaded.inventory, "Blessing lost from inventory"
        assert "item.condiment_sigil" in loaded.inventory, "Sigil lost from inventory"
        assert "item.accountability_token" in loaded.inventory, "Token lost from inventory"
        assert "relic.ancient_mayonnaise" in loaded.inventory, "Mayonnaise lost from inventory"

        # 16. Visual metadata works after load
        metadata = get_visual_metadata(module, loaded)
        assert metadata["current_location"] == "location.fridge_labyrinth.casserole_throne"
        assert metadata["generated"]["map"] is not None
        assert metadata["generated"]["room"] is not None

        print("ALL SMOKE TESTS PASSED")
        print(f"  act2_complete: {loaded.flags['act2_complete']}")
        print(f"  act3_complete: {loaded.flags['act3_complete']}")
        print(f"  act4_started: {loaded.flags['act4_started']}")
        print(f"  moldric_guiding: {loaded.flags['moldric_guiding']}")
        print(f"  condiment_gate_opened: {loaded.flags['condiment_gate_opened']}")
        print(f"  leftover_catacombs_crossed: {loaded.flags['leftover_catacombs_crossed']}")
        print(f"  freezer_blessing_obtained: {loaded.flags['freezer_blessing_obtained']}")
        print(f"  sentient_casserole_resolved: {loaded.flags['sentient_casserole_resolved']}")
        print(f"  casserole_lid_fragment_obtained: {loaded.flags['casserole_lid_fragment_obtained']}")
        print(f"  act4_complete: {loaded.flags['act4_complete']}")
        print(f"  inventory: {loaded.inventory}")

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    smoke_test()
