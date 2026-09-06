#!/usr/bin/env python3
"""Automated smoke test for Act V: Department of Adjudication."""

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


def _play_through_act4(module, state):
    """Replay the verified Act I-IV path (mirrors test_act3_smoke.py) up to
    the labyrinth completion scene, without invoking the pre-existing
    'complete_act4' choice — Act V is reached via the new 'proceed_to_act5'
    choice instead, so the original Act IV regression path is untouched."""
    module.enter_scene(state)
    module.choose(state, "inspect_label")
    module.choose(state, "file_boundary_statement")
    module.choose(state, "enter_fridge")
    module.choose(state, "meet_moldric")
    module.choose(state, "help_moldric_reclaim")
    module.choose(state, "proceed_to_act3")
    module.choose(state, "approach_vending_machine")
    module.choose(state, "name_your_price")
    module.choose(state, "confront_snack_wraiths_peacefully")
    module.choose(state, "proceed_to_act4")
    module.choose(state, "accept_moldric_guide")
    module.choose(state, "acknowledge_condiments")
    module.choose(state, "acknowledge_leftovers")
    module.choose(state, "take_freezer_blessing_with_respect")
    module.choose(state, "compassion_path")
    assert state.current_scene == "scene.act4.labyrinth_completion"
    # act4_complete is set by labyrinth_completion's on_enter_flags itself
    assert state.flags.get("act4_complete") is True


def smoke_test():
    module = CampaignModule("campaigns/strawberry_omen")
    tmp_dir = tempfile.mkdtemp()
    saves = ModuleSaveSystem(module, save_dir=tmp_dir)

    try:
        state = module.new_state()
        _play_through_act4(module, state)

        # 1. Cross into Act V via the additive hook (original 'complete_act4'
        #    choice is left completely untouched by this path)
        module.choose(state, "proceed_to_act5")
        assert state.flags["act5_started"], "Act V not started"
        assert state.current_scene == "scene.act5.summons"
        assert state.current_location == "location.department_of_adjudication.antechamber"

        # 2. Accept the summons
        module.choose(state, "accept_summons")
        assert state.flags["summons_received"], "Summons not received"
        assert "item.writ_of_summons" in state.inventory
        assert state.current_scene == "scene.act5.records_hall"

        # 3. Gather evidence
        module.choose(state, "search_the_files")
        assert state.flags["evidence_gathered"], "Evidence not gathered"
        assert "item.evidence_ledger" in state.inventory
        assert state.current_scene == "scene.act5.holding_pen"

        # 4. Give honest testimony
        module.choose(state, "give_testimony_honestly")
        assert state.flags["testimony_given"], "Testimony not given"
        assert state.current_scene == "scene.act5.hearing_arena_entry"
        assert state.current_location == "location.department_of_adjudication.hearing_arena"

        # 5. Confirm the current scene is a real arena_encounter and the
        #    renderer bridge can build a real, non-fake ArenaState from it
        scene = module.scene(state.current_scene)
        assert scene.get("type") == "arena_encounter"
        from engine.render_bridge import build_arena_state_from_module
        arena = build_arena_state_from_module(state)
        assert arena.arena_id == "arena.hearing_chamber"
        assert 0.0 <= arena.damage <= 1.0
        assert 0.0 <= arena.crowd_heat <= 1.0
        assert arena.faction_control in ("solar", "void")
        assert arena.match_phase == "broadcast"

        # 6. Step into the arena
        module.choose(state, "step_into_the_arena")
        assert state.current_scene == "scene.act5.hearing_arena_verdict"

        # 7. Present evidence for the verdict
        module.choose(state, "present_evidence_ledger")
        assert state.flags["verdict_rendered"], "Verdict not rendered"
        assert state.current_scene == "scene.act5.verdict_vault"

        # 8. Complete Act V
        module.enter_scene(state, "scene.act5.verdict_vault")
        assert state.flags["act5_complete"], "Act V not marked complete on enter"
        module.choose(state, "receive_verdict_seal")
        assert state.flags["act5_complete"], "Act V not complete"
        assert "item.verdict_seal" in state.inventory

        # 9. Save
        msg = saves.save_game(state)
        assert "saved" in msg.lower(), f"Save failed: {msg}"

        # 10. Load
        loaded = saves.load_game()
        assert loaded is not None, "Load returned None"
        module.enter_scene(loaded, loaded.current_scene)

        # 11. Confirm Act IV -> Act V flags all survive load
        assert loaded.flags["act4_complete"], "act4_complete lost after load"
        assert loaded.flags["act5_started"], "act5_started lost after load"
        assert loaded.flags["summons_received"], "summons_received lost after load"
        assert loaded.flags["evidence_gathered"], "evidence_gathered lost after load"
        assert loaded.flags["testimony_given"], "testimony_given lost after load"
        assert loaded.flags["verdict_rendered"], "verdict_rendered lost after load"
        assert loaded.flags["act5_complete"], "act5_complete lost after load"
        assert "item.writ_of_summons" in loaded.inventory
        assert "item.evidence_ledger" in loaded.inventory
        assert "item.verdict_seal" in loaded.inventory
        assert "item.casserole_lid_fragment" in loaded.inventory, "Act IV items lost across the boundary"

        # 12. Visual metadata still resolves (falls back gracefully, no crash)
        metadata = get_visual_metadata(module, loaded)
        assert metadata["current_location"] == "location.department_of_adjudication.verdict_vault"

        print("ALL ACT V SMOKE TESTS PASSED")
        print(f"  act4_complete: {loaded.flags['act4_complete']}")
        print(f"  act5_started: {loaded.flags['act5_started']}")
        print(f"  summons_received: {loaded.flags['summons_received']}")
        print(f"  evidence_gathered: {loaded.flags['evidence_gathered']}")
        print(f"  testimony_given: {loaded.flags['testimony_given']}")
        print(f"  verdict_rendered: {loaded.flags['verdict_rendered']}")
        print(f"  act5_complete: {loaded.flags['act5_complete']}")
        print(f"  inventory: {loaded.inventory}")

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    smoke_test()
