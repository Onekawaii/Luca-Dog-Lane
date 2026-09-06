"""Contract tests for the fictional NPC dynamics subsystem."""

import unittest

from engine.actor_dynamics import ActorDynamicsEngine, ActorState, classify_state


class TestActorDynamics(unittest.TestCase):
    def test_step_is_deterministic_for_same_seed_and_salt(self):
        signal = {"activation": 0.2, "social_openness": -0.1}
        a = ActorDynamicsEngine.step(None, signal, seed=6060, salt="keith:test")
        b = ActorDynamicsEngine.step(None, signal, seed=6060, salt="keith:test")
        self.assertEqual(a, b)

    def test_state_is_bounded(self):
        state = ActorDynamicsEngine.step(None, {"activation": 999, "depletion": -999}, seed=1, salt="bound")
        for value in state.to_vector():
            self.assertGreaterEqual(value, -2.5)
            self.assertLessEqual(value, 2.5)

    def test_positive_social_signal_changes_state(self):
        state = ActorDynamicsEngine.step(
            None,
            {"coherence": 0.25, "social_openness": 0.4, "recovery_potential": 0.25},
            seed=6060,
            salt="helped",
            noise_scale=0,
        )
        self.assertGreater(state.social_openness, ActorState().social_openness)

    def test_behavior_classifier_is_game_facing(self):
        self.assertEqual(classify_state(ActorState(activation=1.3, bodily_load=1.0, coherence=-0.4)), "agitated")


if __name__ == "__main__":
    unittest.main()
