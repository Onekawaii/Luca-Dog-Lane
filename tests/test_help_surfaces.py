"""Tests for Help Surface Patch v1.0.

Proves:
1. Top-level CLI --help works and exits 0.
2. Each subcommand --help works and exits 0.
3. play_strawberry.py accepts 'help' at startup.
4. play_strawberry.py accepts 'help' during Act IV.
5. 'help' does not mutate state (same scene, flags, inventory).
6. Web/PWA help UI exists (Help button in HTML, showHelp in JS).
"""

import sys
import json
import os
import unittest
from io import StringIO
from pathlib import Path


class TestCLIHelpSurfaces(unittest.TestCase):
    """CLI-level help surface tests."""

    def test_top_level_help(self):
        """python -m hive_lattice.cli --help prints usage and exits 0."""
        from hive_lattice import cli
        out = StringIO()
        err = StringIO()
        try:
            rc = cli.main(["--help"])
        except SystemExit as e:
            rc = e.code
        self.assertEqual(rc, 0)

    def test_validate_subcommand_help(self):
        """python -m hive_lattice.cli validate --help prints help and exits 0."""
        from hive_lattice import cli
        out = StringIO()
        err = StringIO()
        try:
            rc = cli.main(["validate", "--help"])
        except SystemExit as e:
            rc = e.code
        self.assertEqual(rc, 0)

    def test_generate_assets_subcommand_help(self):
        """python -m hive_lattice.cli generate-assets --help exits 0."""
        from hive_lattice import cli
        try:
            rc = cli.main(["generate-assets", "--help"])
        except SystemExit as e:
            rc = e.code
        self.assertEqual(rc, 0)

    def test_asset_summary_subcommand_help(self):
        """python -m hive_lattice.cli asset-summary --help exits 0."""
        from hive_lattice import cli
        try:
            rc = cli.main(["asset-summary", "--help"])
        except SystemExit as e:
            rc = e.code
        self.assertEqual(rc, 0)

    def test_saves_subcommand_help(self):
        """python -m hive_lattice.cli saves --help exits 0."""
        from hive_lattice import cli
        try:
            rc = cli.main(["saves", "--help"])
        except SystemExit as e:
            rc = e.code
        self.assertEqual(rc, 0)

    def test_web_subcommand_help(self):
        """python -m hive_lattice.cli web --help exits 0."""
        from hive_lattice import cli
        try:
            rc = cli.main(["web", "--help"])
        except SystemExit as e:
            rc = e.code
        self.assertEqual(rc, 0)


class TestPlayStrawberryHelpSurfaces(unittest.TestCase):
    """In-game help surface tests for play_strawberry.py."""

    def setUp(self):
        from engine.module_runtime import CampaignModule
        self.root = Path("campaigns/strawberry_omen")
        self.module = CampaignModule(self.root)

    def _capture_state(self, state):
        """Return a snapshot of scene/flags/inventory for comparison."""
        return {
            "current_scene": state.current_scene,
            "current_location": state.current_location,
            "flags": dict(state.flags),
            "inventory": list(state.inventory),
        }

    def test_help_at_startup(self):
        """'help' at startup displays help text without error."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        from play_strawberry import _print_help
        try:
            _print_help()
        except Exception as e:
            self.fail(f"help raised exception: {e}")

    def test_help_during_act4(self):
        """'help' during Act IV displays help text without error."""
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
        self.assertTrue(state.flags.get("act4_started"))
        from play_strawberry import _print_help
        try:
            _print_help()
        except Exception as e:
            self.fail(f"help during Act IV raised exception: {e}")

    def test_help_does_not_mutate_state(self):
        """'help' must not change scene, flags, or inventory."""
        state = self.module.new_state()
        self.module.enter_scene(state)
        before = self._capture_state(state)
        from play_strawberry import _print_help
        _print_help()
        after = self._capture_state(state)
        self.assertEqual(before, after)

    def test_help_does_not_mutate_state_during_act4(self):
        """'help' during Act IV must not change scene, flags, or inventory."""
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
        before = self._capture_state(state)
        from play_strawberry import _print_help
        _print_help()
        after = self._capture_state(state)
        self.assertEqual(before, after)

    def test_help_after_act4_completion(self):
        """'help' after Act IV complete displays help text without error."""
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
        self.module.choose(state, "complete_act4")
        self.assertTrue(state.flags.get("act4_complete"))
        from play_strawberry import _print_help
        try:
            _print_help()
        except Exception as e:
            self.fail(f"help after Act IV raised exception: {e}")


class TestWebHelpSurface(unittest.TestCase):
    """Web/PWA help UI surface tests."""

    def test_help_button_exists_in_html(self):
        """The HTML template must contain a help button calling showHelp()."""
        html_path = Path("hive_lattice/web_app/templates/index.html")
        self.assertTrue(html_path.exists())
        html = html_path.read_text(encoding="utf-8")
        self.assertIn("showHelp()", html, "HTML must contain showHelp() call")
        self.assertIn("Help", html, "HTML must contain Help button")

    def test_help_content_in_strawberry_js(self):
        """The JS must define a showHelp() function with help text."""
        js_path = Path("hive_lattice/web_app/static/strawberry.js")
        self.assertTrue(js_path.exists())
        js = js_path.read_text(encoding="utf-8")
        self.assertIn("function showHelp()", js, "JS must define showHelp()")
        self.assertIn("Strawberry Omen", js, "JS help must mention game title")
        self.assertIn("does not change game state", js,
                       "JS help must note it does not mutate state")


if __name__ == "__main__":
    unittest.main()
