#!/usr/bin/env python3
"""Tests for BUILD_PROVENANCE.json — v0.6.0-lattice-alive."""

import json
import sys
import unittest
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

PROVENANCE_PATH = _REPO_ROOT / "BUILD_PROVENANCE.json"


class TestBuildProvenance(unittest.TestCase):
    def setUp(self):
        self.assertTrue(PROVENANCE_PATH.exists(), "BUILD_PROVENANCE.json is missing")
        with open(PROVENANCE_PATH, encoding="utf-8") as f:
            self.provenance = json.load(f)

    def test_required_top_level_fields_present(self):
        required = [
            "version", "tag", "source_baseline", "build_timestamp_utc",
            "runtime_requirements", "mobile_build", "test_summary",
            "validators", "release_artifact",
        ]
        for field in required:
            self.assertIn(field, self.provenance, f"missing field: {field}")

    def test_tag_matches_expected_release(self):
        self.assertEqual(self.provenance["tag"], "v0.6.0-lattice-alive")
        self.assertEqual(self.provenance["version"], "0.6.0")

    def test_source_baseline_is_the_accepted_v052_archive(self):
        base = self.provenance["source_baseline"]
        self.assertEqual(base["source_baseline_commit"], "f0c1d1ea76cc0a122d54c5e4ea4b7fdd530178f6")
        self.assertEqual(base["artifact_sha256"], "e8a951d6ad649acb5b6e06dbe9aaeaad68b773a71d15a3346bf12477d89305cc")

    def test_no_canonical_commit_is_fabricated_from_archive_only_input(self):
        self.assertIsNone(self.provenance["canonical_git_commit"])
        self.assertIn("No descendant commit SHA is fabricated", self.provenance["canonical_git_note"])

    def test_core_renderer_is_optional(self):
        runtime = self.provenance["runtime_requirements"]
        self.assertFalse(runtime["renderer_required_for_core_game"])
        self.assertEqual(runtime["optional_renderer_dependencies_file"], "requirements-renderer.txt")

    def test_mobile_contract_is_recorded(self):
        mobile = self.provenance["mobile_build"]
        self.assertFalse(mobile["desktop_site_required"])
        self.assertGreaterEqual(mobile["minimum_touch_target_css_px"], 48)
        self.assertTrue(mobile["safe_area_footer"])
        self.assertTrue(mobile["browser_zoom_allowed"])

    def test_test_summary_is_honest_about_environment(self):
        summary = self.provenance["test_summary"]
        self.assertEqual(summary["full_suite_defined"], 370)
        self.assertEqual(summary["build_sandbox_executable_non_flask"], 305)
        self.assertEqual(summary["build_sandbox_non_flask_result"], "PASSED")
        self.assertEqual(summary["flask_dependent_cases"], 65)

    def test_all_executed_validators_report_pass(self):
        validators = self.provenance["validators"]
        for key in (
            "content_lint", "validate_campaign_module", "validate_visual_assets",
            "cli_validate_strawberry_omen", "act4_smoke", "act5_smoke",
            "lattice_alive_gate",
        ):
            self.assertEqual(validators[key], "PASSED")

    def test_artifact_sha256_is_external_not_self_referential(self):
        artifact = self.provenance["release_artifact"]
        self.assertIsNone(artifact["sha256"])
        self.assertIn("external sibling .sha256", artifact["sha256_note"])


if __name__ == "__main__":
    unittest.main()
