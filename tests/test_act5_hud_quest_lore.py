#!/usr/bin/env python3
"""Tests for Act V HUD/quest/lore integration — v0.5.1-act5-complete."""

import json
import sys
import unittest
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

ROOT = _REPO_ROOT / "campaigns" / "strawberry_omen"
JS_PATH = _REPO_ROOT / "hive_lattice" / "web_app" / "static" / "strawberry.js"
IDENTITY_PATH = ROOT / "game" / "character_identities.json"
from hive_lattice.web_app.presentation import derive_act_progression


class TestAct5Quest(unittest.TestCase):
    def setUp(self):
        with open(ROOT / "game" / "quests.json") as f:
            self.quests = json.load(f)
        with open(ROOT / "game" / "encounters.json") as f:
            self.encounters = json.load(f)
        with open(ROOT / "game" / "items.json") as f:
            self.items = json.load(f)

    def test_act5_quest_exists(self):
        ids = [q["id"] for q in self.quests]
        self.assertIn("quest.act5.face_the_department", ids)

    def test_act5_quest_completion_flag_matches_campaign(self):
        quest = next(q for q in self.quests if q["id"] == "quest.act5.face_the_department")
        self.assertEqual(quest["completion_flag"], "act5_complete")

    def test_act5_quest_starts_at_real_scene(self):
        quest = next(q for q in self.quests if q["id"] == "quest.act5.face_the_department")
        scene_ids = {e["id"] for e in self.encounters}
        self.assertIn(quest["starts_at"], scene_ids)

    def test_act5_quest_objectives_reference_real_items(self):
        quest = next(q for q in self.quests if q["id"] == "quest.act5.face_the_department")
        item_ids = {i["id"] for i in self.items}
        for obj in quest["objectives"]:
            if "item" in obj:
                self.assertIn(obj["item"], item_ids, f"objective {obj['id']} references missing item")

    def test_act5_quest_has_five_objectives(self):
        quest = next(q for q in self.quests if q["id"] == "quest.act5.face_the_department")
        self.assertEqual(len(quest["objectives"]), 5)


class TestAct5HUD(unittest.TestCase):
    def setUp(self):
        self.js = JS_PATH.read_text(encoding="utf-8")
        self.identities = json.loads(IDENTITY_PATH.read_text(encoding="utf-8"))

    def test_act5_appears_in_progression_hud(self):
        p = derive_act_progression({"act4_complete": True})
        self.assertEqual(p["current_label"], "Act V")
        self.assertIn("Act V: Face the Department of Adjudication", [a["name"] for a in p["acts"]])

    def test_act5_hud_entry_gated_on_act4_complete(self):
        before = derive_act_progression({"act3_complete": True})
        after = derive_act_progression({"act4_complete": True})
        self.assertFalse(before["acts"][4]["active"])
        self.assertTrue(after["acts"][4]["active"])

    def test_act5_npc_sprite_mappings_are_server_authored(self):
        expected = {
            "npc.clerk_pell": "token.clerk_pell",
            "npc.bailiff_gorrum": "token.bailiff_gorrum",
            "npc.magistrate_orla": "token.magistrate_orla",
        }
        chars = self.identities["characters"]
        for npc_id, token in expected.items():
            self.assertEqual(chars[npc_id]["token"], token)
        self.assertIn("data.presentation.entities", self.js)
        self.assertNotIn('sceneId.includes("records_hall")', self.js)

    def test_arena_render_hook_present(self):
        self.assertIn("arena-img", self.js)
        self.assertIn("data.arena.active", self.js)
        self.assertIn("data.arena.render_url", self.js)


class TestAct5Lore(unittest.TestCase):
    def setUp(self):
        self.js = JS_PATH.read_text(encoding="utf-8")
        self.identities = json.loads(IDENTITY_PATH.read_text(encoding="utf-8"))

    def test_act5_lore_fragments_present_for_each_flag(self):
        for flag in [
            "summons_received",
            "evidence_gathered",
            "testimony_given",
            "hearing_entered",
            "verdict_rendered",
            "act5_complete",
        ]:
            self.assertIn(f"flags.{flag}", self.js)

    def test_department_of_adjudication_named_in_lore(self):
        self.assertIn("DEPARTMENT OF ADJUDICATION", self.js)

    def test_magistrate_orla_lore_present(self):
        self.assertIn("MAGISTRATE ORLA", self.js)


if __name__ == "__main__":
    unittest.main()
