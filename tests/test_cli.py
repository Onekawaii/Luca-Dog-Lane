"""Tests for the Hive-Lattice CLI (v0.7)."""

import unittest
from unittest.mock import patch
from io import StringIO

from hive_lattice.cli import main


class TestCLIHelp(unittest.TestCase):
    """CLI help and unknown-command handling."""

    def test_help_flag(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main(["--help"])
        self.assertEqual(rc, 0)
        self.assertIn("usage:", out.getvalue().lower())

    def test_no_args_shows_help(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main([])
        self.assertEqual(rc, 0)
        self.assertIn("usage:", out.getvalue().lower())

    def test_unknown_command(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main(["bogus", "strawberry_omen"])
        self.assertEqual(rc, 1)
        self.assertIn("unknown command", out.getvalue().lower())

    def test_unsupported_campaign(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main(["validate", "nonexistent_campaign"])
        self.assertEqual(rc, 1)
        self.assertIn("unsupported campaign", out.getvalue().lower())

    def test_validate_strawberry_omen(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main(["validate", "strawberry_omen"])
        self.assertEqual(rc, 0)
        self.assertIn("passed", out.getvalue().lower())

    def test_asset_summary_strawberry_omen(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main(["asset-summary", "strawberry_omen"])
        self.assertEqual(rc, 0)
        self.assertIn("visual assets summary", out.getvalue().lower())

    def test_saves_no_files(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main(["saves", "strawberry_omen"])
        self.assertEqual(rc, 0)
        output = out.getvalue()
        self.assertTrue(
            "no save files" in output.lower() or "save files" in output.lower()
        )

    def test_play_is_callable(self):
        """Ensure play command dispatches (we cannot run interactive loop in tests)."""
        with patch.dict("hive_lattice.cli.COMMANDS", {"play": lambda c: 0}):
            rc = main(["play", "strawberry_omen"])
        self.assertEqual(rc, 0)

    def test_saves_unsupported_campaign(self):
        with patch("sys.stdout", new_callable=StringIO) as out:
            rc = main(["saves", "no_such_game"])
        self.assertEqual(rc, 1)
        self.assertIn("unsupported campaign", out.getvalue().lower())


if __name__ == "__main__":
    unittest.main()
