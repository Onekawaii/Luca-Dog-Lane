#!/usr/bin/env python3
"""Tests for Act V visual asset coverage — v0.5.1-act5-complete."""

import json
import sys
import unittest
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from engine.module_runtime import CampaignModule
from play_strawberry import get_visual_metadata

ROOT = _REPO_ROOT / "campaigns" / "strawberry_omen"

ACT5_ROOMS = [
    "room.department_of_adjudication.antechamber",
    "room.department_of_adjudication.records_hall",
    "room.department_of_adjudication.holding_pen",
    "room.department_of_adjudication.hearing_arena",
    "room.department_of_adjudication.verdict_vault",
]
ACT5_ITEMS = ["item.writ_of_summons", "item.evidence_ledger", "item.verdict_seal"]
ACT5_TOKENS = ["token.clerk_pell", "token.bailiff_gorrum", "token.magistrate_orla"]

ACT5_LOCATIONS = [
    "location.department_of_adjudication.antechamber",
    "location.department_of_adjudication.records_hall",
    "location.department_of_adjudication.holding_pen",
    "location.department_of_adjudication.hearing_arena",
    "location.department_of_adjudication.verdict_vault",
]


class TestAct5VisualCoverage(unittest.TestCase):
    def setUp(self):
        with open(ROOT / "assets" / "generated_manifest.json") as f:
            self.generated = json.load(f)
        with open(ROOT / "visual_manifest.json") as f:
            self.visual = json.load(f)
        self.generated_ids = {
            (a["category"], a["asset_id"]) for a in self.generated["generated_assets"]
        }

    def test_all_act5_rooms_have_generated_art(self):
        for room_id in ACT5_ROOMS:
            self.assertIn(("rooms", room_id), self.generated_ids, f"missing generated art for {room_id}")

    def test_all_act5_items_have_generated_art(self):
        for item_id in ACT5_ITEMS:
            self.assertIn(("items", item_id), self.generated_ids, f"missing generated art for {item_id}")

    def test_all_act5_tokens_have_generated_art(self):
        for token_id in ACT5_TOKENS:
            self.assertIn(("tokens", token_id), self.generated_ids, f"missing generated art for {token_id}")

    def test_generated_asset_files_exist_on_disk(self):
        for asset in self.generated["generated_assets"]:
            if asset["asset_id"] in ACT5_ROOMS + ACT5_ITEMS + ACT5_TOKENS:
                full_path = ROOT / asset["path"]
                self.assertTrue(full_path.exists(), f"generated asset missing on disk: {asset['path']}")

    def test_no_act5_asset_is_placeholder_only(self):
        """None of the Act V rooms/items/tokens should still be bare
        'placeholder' status in visual_manifest.json now that real
        generated art exists for them."""
        act5_ids = set(ACT5_ROOMS + ACT5_ITEMS + ACT5_TOKENS)
        for category in ("rooms", "items", "tokens"):
            for asset in self.visual["assets"][category]:
                if asset["asset_id"] in act5_ids:
                    self.assertNotEqual(
                        asset.get("status"), "placeholder",
                        f"{asset['asset_id']} is still placeholder-only",
                    )
                    self.assertTrue(
                        asset["path"].endswith(".png"),
                        f"{asset['asset_id']} status is not backed by a real image",
                    )

    def test_all_act5_room_visuals_resolve_at_runtime(self):
        """get_visual_metadata must resolve each Act V location to its own
        room art, not silently fall back to the Act I central_table image."""
        module = CampaignModule(str(ROOT))
        state = module.new_state()
        for location_id in ACT5_LOCATIONS:
            state.current_location = location_id
            meta = get_visual_metadata(module, state)
            self.assertIsNotNone(meta["room_asset"], f"no room asset resolved for {location_id}")
            self.assertNotIn(
                "central_table", meta["room_asset"],
                f"{location_id} fell back to the default room instead of resolving its own art",
            )

    def test_act5_tokens_resolve_in_generated_metadata(self):
        module = CampaignModule(str(ROOT))
        state = module.new_state()
        meta = get_visual_metadata(module, state)
        for token_id in ACT5_TOKENS:
            self.assertIn(token_id, meta["generated"]["tokens"], f"{token_id} not resolved")

    def test_act5_items_resolve_in_generated_metadata(self):
        module = CampaignModule(str(ROOT))
        state = module.new_state()
        meta = get_visual_metadata(module, state)
        for item_id in ACT5_ITEMS:
            self.assertIn(item_id, meta["generated"]["items"], f"{item_id} not resolved")


if __name__ == "__main__":
    unittest.main()
