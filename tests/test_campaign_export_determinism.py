"""Regression coverage for deterministic Godot campaign export metadata."""
from __future__ import annotations

import tempfile
import time
import unittest
from pathlib import Path

from tools.export_godot_campaign import export_campaign

ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT / "campaigns" / "strawberry_omen"


class TestCampaignExportDeterminism(unittest.TestCase):
    def test_unchanged_campaign_export_does_not_churn_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "godot_campaign"
            first = export_campaign(CAMPAIGN, output)
            first_bytes = (output / "manifest.json").read_bytes()

            time.sleep(0.01)
            second = export_campaign(CAMPAIGN, output)
            second_bytes = (output / "manifest.json").read_bytes()

            self.assertEqual(first["combined_sha256"], second["combined_sha256"])
            self.assertEqual(first["exported_at"], second["exported_at"])
            self.assertEqual(first_bytes, second_bytes)


if __name__ == "__main__":
    unittest.main()
