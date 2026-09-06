"""Phone-playtest save -> mutate -> load round-trip regression."""

from __future__ import annotations

import tempfile
import unittest
from copy import deepcopy

from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem


class TestMobileSaveRoundTrip(unittest.TestCase):
    def test_save_mutate_load_restores_exact_state(self):
        module = CampaignModule("campaigns/strawberry_omen")
        state = module.new_state()
        module.enter_scene(state)

        # Move into First Memo so the saved snapshot contains a non-trivial log,
        # flags, stats and a scene transition, matching real phone play.
        module.choose(state, "inspect_label")
        saved_snapshot = {
            "current_scene": state.current_scene,
            "current_location": state.current_location,
            "flags": deepcopy(state.flags),
            "stats": deepcopy(state.stats),
            "inventory": deepcopy(state.inventory),
            "log": deepcopy(state.log),
        }

        with tempfile.TemporaryDirectory() as td:
            saves = ModuleSaveSystem(module, save_dir=td)
            saves.save_game(state)

            # Perform a real state-changing action after save.
            before_mutation = deepcopy(saved_snapshot)
            scene = module.scene(state.current_scene)
            mutating_choice = next(
                c for c in scene["choices"]
                if c.get("sets_flags") or c.get("stat_delta") or c.get("grants_items") or c.get("next_scene")
            )
            module.choose(state, mutating_choice["id"])

            mutated = {
                "current_scene": state.current_scene,
                "current_location": state.current_location,
                "flags": state.flags,
                "stats": state.stats,
                "inventory": state.inventory,
                "log": state.log,
            }
            self.assertNotEqual(mutated, before_mutation)

            loaded = saves.load_game()
            self.assertIsNotNone(loaded)
            restored = {
                "current_scene": loaded.current_scene,
                "current_location": loaded.current_location,
                "flags": loaded.flags,
                "stats": loaded.stats,
                "inventory": loaded.inventory,
                "log": loaded.log,
            }
            self.assertEqual(restored, saved_snapshot)


if __name__ == "__main__":
    unittest.main()
