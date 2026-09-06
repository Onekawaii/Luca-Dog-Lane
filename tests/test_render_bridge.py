#!/usr/bin/env python3
"""Unit tests for engine.render_bridge — the Act V renderer Milestone C bridge."""

import sys
import unittest
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from engine.module_runtime import ModuleState
from engine.render_bridge import (
    HEARING_ARENA_ID,
    RendererUnavailableError,
    build_arena_state_from_module,
    is_renderer_available,
    render_arena_png,
)


def _state(**stats):
    return ModuleState(
        campaign_id="strawberry_omen",
        current_scene="scene.act5.hearing_arena_entry",
        current_location="location.department_of_adjudication.hearing_arena",
        flags={},
        stats=stats,
    )


class TestArenaStateMapping(unittest.TestCase):
    def test_full_health_zero_damage(self):
        arena = build_arena_state_from_module(_state(health=100))
        self.assertEqual(arena.damage, 0.0)

    def test_zero_health_full_damage(self):
        arena = build_arena_state_from_module(_state(health=0))
        self.assertEqual(arena.damage, 1.0)

    def test_damage_clamped_above_100_health(self):
        arena = build_arena_state_from_module(_state(health=150))
        self.assertEqual(arena.damage, 0.0)

    def test_bureaucracy_dominant_is_solar(self):
        arena = build_arena_state_from_module(_state(bureaucracy=5, ape_chaos=1))
        self.assertEqual(arena.faction_control, "solar")

    def test_ape_chaos_dominant_is_void(self):
        arena = build_arena_state_from_module(_state(bureaucracy=1, ape_chaos=5))
        self.assertEqual(arena.faction_control, "void")

    def test_tie_defaults_to_solar(self):
        arena = build_arena_state_from_module(_state(bureaucracy=3, ape_chaos=3))
        self.assertEqual(arena.faction_control, "solar")

    def test_match_phase_is_always_broadcast(self):
        arena = build_arena_state_from_module(_state())
        self.assertEqual(arena.match_phase, "broadcast")

    def test_hazards_escalate_with_ape_chaos(self):
        self.assertEqual(build_arena_state_from_module(_state(ape_chaos=0)).hazards, [])
        self.assertEqual(build_arena_state_from_module(_state(ape_chaos=3)).hazards, ["sparks"])
        self.assertEqual(
            build_arena_state_from_module(_state(ape_chaos=6)).hazards,
            ["sparks", "fracture"],
        )

    def test_crowd_heat_is_clamped(self):
        arena = build_arena_state_from_module(_state(bureaucracy=50, moisture_pressure=50))
        self.assertLessEqual(arena.crowd_heat, 1.0)
        self.assertGreaterEqual(arena.crowd_heat, 0.0)

    def test_arena_id_is_stable(self):
        arena = build_arena_state_from_module(_state())
        self.assertEqual(arena.arena_id, HEARING_ARENA_ID)

    def test_mapping_is_deterministic(self):
        s = _state(health=63, bureaucracy=4, ape_chaos=2, moisture_pressure=3)
        a1 = build_arena_state_from_module(s)
        a2 = build_arena_state_from_module(s)
        self.assertEqual(a1, a2)


class TestArenaRender(unittest.TestCase):
    @unittest.skipUnless(is_renderer_available(), "torch/Pillow not installed - renderer is optional")
    def test_render_produces_valid_png_bytes(self):
        state = _state(health=80, bureaucracy=5, ape_chaos=4, moisture_pressure=3)
        png_bytes = render_arena_png(state, size=64, engine="real", device="cpu")
        self.assertGreater(len(png_bytes), 0)
        self.assertEqual(png_bytes[:8], b"\x89PNG\r\n\x1a\n")

    @unittest.skipUnless(is_renderer_available(), "torch/Pillow not installed - renderer is optional")
    def test_render_temp_engine_also_works(self):
        state = _state(health=100, bureaucracy=1, ape_chaos=1)
        png_bytes = render_arena_png(state, size=64, engine="temp", device="cpu")
        self.assertEqual(png_bytes[:8], b"\x89PNG\r\n\x1a\n")

    def test_build_arena_state_never_needs_renderer(self):
        # This must work with or without torch installed - it's pure dataclass mapping.
        state = _state(health=80, bureaucracy=5, ape_chaos=4, moisture_pressure=3)
        arena = build_arena_state_from_module(state)
        self.assertEqual(arena.arena_id, HEARING_ARENA_ID)

    @unittest.skipIf(is_renderer_available(), "this test specifically covers the missing-renderer path")
    def test_render_raises_renderer_unavailable_when_torch_missing(self):
        state = _state(health=80)
        with self.assertRaises(RendererUnavailableError):
            render_arena_png(state, size=64, engine="real", device="cpu")


if __name__ == "__main__":
    unittest.main()
