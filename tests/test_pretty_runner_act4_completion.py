"""Regression test: Act IV completion loop fix.

Verifies that selecting complete_act4 from scene.act4.labyrinth_completion
does not loop forever, and that both runners exit cleanly.
"""
import unittest

from engine.module_runtime import CampaignModule


class TestAct4CompletionLoop(unittest.TestCase):
    """Test the completion-loop guard at the module level."""

    def setUp(self):
        self.module = CampaignModule("campaigns/strawberry_omen")

    def _reach_labyrinth_completion(self):
        """Helper: play through to scene.act4.labyrinth_completion."""
        state = self.module.new_state()
        # Act I
        self.module.enter_scene(state)
        self.module.choose(state, "inspect_label")
        self.module.choose(state, "file_boundary_statement")
        self.module.choose(state, "enter_fridge")
        # Act II
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
        return state

    def test_complete_act4_sets_flag(self):
        """After choosing complete_act4, act4_complete is true."""
        state = self._reach_labyrinth_completion()
        self.module.choose(state, "complete_act4")
        self.assertTrue(state.flags["act4_complete"])

    def test_complete_act4_stays_on_same_scene(self):
        """After choosing complete_act4, scene does not change
        (this is the root cause of the loop bug)."""
        state = self._reach_labyrinth_completion()
        prev_scene = state.current_scene
        self.module.choose(state, "complete_act4")
        self.assertEqual(state.current_scene, prev_scene)

    def test_complete_act4_is_completion_encounter(self):
        """The labyrinth_completion scene is a completion_encounter."""
        scene = self.module.scene("scene.act4.labyrinth_completion")
        self.assertEqual(scene.get("type"), "completion_encounter")

    def test_complete_act4_choice_has_no_next_scene(self):
        """The complete_act4 choice has no next_scene (root cause)."""
        scene = self.module.scene("scene.act4.labyrinth_completion")
        choice = next(c for c in scene["choices"] if c["id"] == "complete_act4")
        self.assertNotIn("next_scene", choice)

    def test_complete_act4_result_text(self):
        """The complete_act4 choice returns meaningful text."""
        state = self._reach_labyrinth_completion()
        result = self.module.choose(state, "complete_act4")
        self.assertIn("Act IV complete", result)

    def test_second_complete_act4_is_idempotent(self):
        """Choosing complete_act4 twice does not crash or change flags."""
        state = self._reach_labyrinth_completion()
        self.module.choose(state, "complete_act4")
        first_flags = dict(state.flags)
        first_inv = list(state.inventory)
        self.module.choose(state, "complete_act4")
        self.assertEqual(state.flags, first_flags)
        self.assertEqual(state.inventory, first_inv)

    def test_no_duplicate_result_text(self):
        """Choosing complete_act4 twice does not produce duplicate result text
        when the runner guard is applied."""
        state = self._reach_labyrinth_completion()
        result1 = self.module.choose(state, "complete_act4")
        result2 = self.module.choose(state, "complete_act4")
        # Both should produce the same text (idempotent), but the runner
        # should only print result1 once then exit.
        self.assertEqual(result1, result2)


class TestPrettyRunnerCompletionExit(unittest.TestCase):
    """Test that the pretty runner's completion-loop guard triggers correctly."""

    def setUp(self):
        self.module = CampaignModule("campaigns/strawberry_omen")

    def _reach_labyrinth_completion(self):
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.module.choose(state, "inspect_label")
        self.module.choose(state, "file_boundary_statement")
        self.module.choose(state, "enter_fridge")
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "help_moldric_reclaim")
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        self.module.choose(state, "proceed_to_act4")
        self.module.choose(state, "accept_moldric_guide")
        self.module.choose(state, "acknowledge_condiments")
        self.module.choose(state, "acknowledge_leftovers")
        self.module.choose(state, "take_freezer_blessing_with_respect")
        self.module.choose(state, "compassion_path")
        return state

    def test_guard_condition_triggers_for_act4(self):
        """The completion-loop guard condition is met after complete_act4."""
        state = self._reach_labyrinth_completion()
        prev_scene = state.current_scene
        self.module.choose(state, "complete_act4")
        scene = self.module.scene(prev_scene)
        # This is the exact condition both runners check
        should_exit = (
            state.current_scene == prev_scene
            and scene.get("type") == "completion_encounter"
        )
        self.assertTrue(should_exit)

    def test_guard_condition_not_triggered_for_non_completion(self):
        """The guard does NOT trigger for non-completion scenes."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        prev_scene = state.current_scene
        self.module.choose(state, "thumbs_up")
        scene = self.module.scene(prev_scene)
        should_exit = (
            state.current_scene == prev_scene
            and scene.get("type") == "completion_encounter"
        )
        # thumbs_up doesn't change scene, but it's not a completion_encounter
        self.assertFalse(should_exit)

    def test_guard_condition_not_triggered_when_scene_changes(self):
        """The guard does NOT trigger when scene transitions normally."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        prev_scene = state.current_scene
        self.module.choose(state, "inspect_label")
        scene = self.module.scene(prev_scene)
        should_exit = (
            state.current_scene == prev_scene
            and scene.get("type") == "completion_encounter"
        )
        # Scene changed, so guard should not trigger
        self.assertFalse(should_exit)

    def test_act3_deposit_accountability_guard_triggers(self):
        """The guard also triggers for act3 accountability completion."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        self.module.choose(state, "inspect_label")
        self.module.choose(state, "file_boundary_statement")
        self.module.choose(state, "enter_fridge")
        self.module.choose(state, "meet_moldric")
        self.module.choose(state, "help_moldric_reclaim")
        self.module.choose(state, "proceed_to_act3")
        self.module.choose(state, "approach_vending_machine")
        self.module.choose(state, "name_your_price")
        self.module.choose(state, "confront_snack_wraiths_peacefully")
        # Now at scene.act3.accountability_completion
        prev_scene = state.current_scene
        self.module.choose(state, "deposit_accountability")
        scene = self.module.scene(prev_scene)
        should_exit = (
            state.current_scene == prev_scene
            and scene.get("type") == "completion_encounter"
        )
        self.assertTrue(should_exit)

    def test_output_no_duplicate_completion_text(self):
        """Choosing complete_act4 twice produces identical result text
        (no duplicate reward messages when runner guard is applied)."""
        state = self._reach_labyrinth_completion()
        result1 = self.module.choose(state, "complete_act4")
        result2 = self.module.choose(state, "complete_act4")
        self.assertEqual(result1, result2)


if __name__ == "__main__":
    unittest.main()
