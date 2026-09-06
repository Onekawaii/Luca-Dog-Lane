"""Dungeon Crawler Core Contract v0.1 - verification tests.

Proves Act IV satisfies the documented dungeon-crawler anatomy and provides
reusable helpers for future acts.

Sections verified (per docs/DUNGEON_CRAWLER_CORE_CONTRACT.md):
  1. Dungeon identity
  2. Room graph
  3. Scene graph
  4. Items
  5. NPCs
  6. Route model
  7. Assets
  8. Save/load (references existing tests)
  9. PWA requirements (references existing tests)
 10. Required tests checklist
"""

import json
import unittest
from pathlib import Path

from engine.module_runtime import CampaignModule


# ── helpers ──────────────────────────────────────────────────────────────

def _load_json(root: Path, relative: str):
    with (root / relative).open("r", encoding="utf-8") as f:
        return json.load(f)


def _all_node_ids(module: CampaignModule) -> set:
    """Return every location node id across all location groups."""
    ids = set()
    for loc in module.locations.values():
        ids.add(loc["id"])
        for node in loc.get("nodes", []):
            ids.add(node["id"])
    return ids


def _act_scenes(module: CampaignModule, act: int) -> dict:
    """Return {scene_id: encounter} for a given act number."""
    return {
        eid: enc
        for eid, enc in module.encounters.items()
        if enc.get("act") == act
    }


def _act_choice_targets(module: CampaignModule, act: int) -> set:
    """Return all next_scene targets originating from act scenes."""
    targets = set()
    for eid, enc in _act_scenes(module, act).items():
        for choice in enc.get("choices", []):
            ns = choice.get("next_scene")
            if ns:
                targets.add(ns)
    return targets


def _act_granted_items(module: CampaignModule, act: int) -> set:
    """Return all item ids granted by choices in act scenes."""
    items = set()
    for eid, enc in _act_scenes(module, act).items():
        for choice in enc.get("choices", []):
            items.update(choice.get("grants_items", []))
    return items


def _act_spawned_npcs(module: CampaignModule, act: int) -> set:
    """Return all NPC ids spawned by choices in act scenes."""
    npcs = set()
    for eid, enc in _act_scenes(module, act).items():
        for choice in enc.get("choices", []):
            npc = choice.get("spawns_npc")
            if npc:
                npcs.add(npc)
    return npcs


def _act_location_nodes(module: CampaignModule, act: int) -> set:
    """Return all location node ids referenced by act scenes."""
    nodes = set()
    for eid, enc in _act_scenes(module, act).items():
        loc = enc.get("location")
        if loc:
            nodes.add(loc)
    return nodes


# ── Act IV constants ─────────────────────────────────────────────────────

ACT = 4
EXPECTED_LOCATIONS = {
    "location.fridge_labyrinth.entry",
    "location.fridge_labyrinth.condiment_gate",
    "location.fridge_labyrinth.leftover_catacombs",
    "location.fridge_labyrinth.freezer_shrine",
    "location.fridge_labyrinth.casserole_throne",
}

EXPECTED_SCENES = {
    "scene.act4.labyrinth_entry",
    "scene.act4.condiment_gate",
    "scene.act4.leftover_catacombs",
    "scene.act4.freezer_shrine",
    "scene.act4.casserole_throne",
    "scene.act4.casserole_throne_recovery",
    "scene.act4.labyrinth_completion",
}

EXPECTED_CORE_ITEMS = {
    "item.condiment_sigil",
    "item.freezer_blessing",
    "item.casserole_lid_fragment",
}

EXPECTED_NPCS = {
    "npc.moldric_guide",
    "npc.condiment_guardian",
    "npc.sentient_casserole",
}

COMPLETION_FLAG = "act4_complete"
COMPLETION_QUEST = "quest.navigate_fridge_labyrinth"
COMPLETION_ARTIFACT = "item.casserole_lid_fragment"


# ── tests ────────────────────────────────────────────────────────────────

class TestDungeonContractActIV(unittest.TestCase):
    """Verify Act IV satisfies the Dungeon Crawler Core Contract v0.1."""

    @classmethod
    def setUpClass(cls):
        cls.root = Path("campaigns/strawberry_omen")
        cls.module = CampaignModule(cls.root)
        cls.node_ids = _all_node_ids(cls.module)

    # ── 1. Dungeon Identity ──────────────────────────────────────────

    def test_completion_flag_in_starting_flags(self):
        """Completion flag must be declared in campaign.json starting_flags."""
        starting = self.module.campaign.get("starting_flags", {})
        self.assertIn(COMPLETION_FLAG, starting,
                       f"Completion flag '{COMPLETION_FLAG}' missing from starting_flags")

    def test_entry_scene_exists(self):
        """Entry scene must exist in encounters."""
        entry = self.module.campaign.get("entry_scene", "")
        self.assertIn(entry, self.module.encounters,
                       f"Entry scene '{entry}' not in encounters")

    # ── 2. Room Graph ────────────────────────────────────────────────

    def test_act4_has_5_locations(self):
        """Act IV must have exactly 5 location nodes."""
        act4_locs = [
            node for loc in self.module.locations.values()
            for node in loc.get("nodes", [])
            if node["id"].startswith("location.fridge_labyrinth.")
        ]
        self.assertEqual(len(act4_locs), 5,
                          f"Expected 5 Act IV locations, got {len(act4_locs)}")

    def test_all_expected_act4_locations_exist(self):
        """Every expected Act IV location must exist."""
        for loc_id in EXPECTED_LOCATIONS:
            self.assertIn(loc_id, self.node_ids,
                           f"Expected Act IV location missing: {loc_id}")

    def test_act4_location_nodes_have_valid_locked_by_flags(self):
        """Every locked_by_flag must reference a valid starting flag."""
        starting = self.module.campaign.get("starting_flags", {})
        act4_nodes = [
            node for loc in self.module.locations.values()
            for node in loc.get("nodes", [])
            if node["id"].startswith("location.fridge_labyrinth.")
        ]
        for node in act4_nodes:
            flag = node.get("locked_by_flag")
            if flag:
                self.assertIn(flag, starting,
                               f"Node {node['id']} locked_by unknown flag: {flag}")

    # ── 3. Scene Graph ───────────────────────────────────────────────

    def test_act4_has_7_scenes(self):
        """Act IV must have exactly 7 scenes."""
        scenes = _act_scenes(self.module, ACT)
        self.assertEqual(len(scenes), 7,
                          f"Expected 7 Act IV scenes, got {len(scenes)}")

    def test_all_expected_act4_scenes_exist(self):
        """Every expected Act IV scene must exist in encounters."""
        for scene_id in EXPECTED_SCENES:
            self.assertIn(scene_id, self.module.encounters,
                           f"Expected Act IV scene missing: {scene_id}")

    def test_act4_scene_locations_resolve(self):
        """Every Act IV scene must reference a location node that exists."""
        for eid, enc in _act_scenes(self.module, ACT).items():
            loc = enc.get("location", "")
            self.assertIn(loc, self.node_ids,
                           f"Act IV scene {eid} references missing location: {loc}")

    def test_act4_choice_targets_resolve(self):
        """Every next_scene in Act IV choices must resolve to an existing encounter."""
        for eid, enc in _act_scenes(self.module, ACT).items():
            for choice in enc.get("choices", []):
                ns = choice.get("next_scene")
                if ns:
                    self.assertIn(ns, self.module.encounters,
                                   f"Choice {choice['id']} in {eid} points to missing scene: {ns}")

    def test_act4_completion_scene_sets_flag(self):
        """The completion scene must set act4_complete via on_enter_flags."""
        comp = self.module.encounters.get("scene.act4.labyrinth_completion")
        self.assertIsNotNone(comp, "Completion scene not found")
        flags = comp.get("on_enter_flags", {})
        self.assertTrue(flags.get(COMPLETION_FLAG),
                        f"Completion scene does not set {COMPLETION_FLAG}")

    # ── 4. Items ─────────────────────────────────────────────────────

    def test_act4_has_3_core_items(self):
        """Act IV must grant exactly 3 core items."""
        granted = _act_granted_items(self.module, ACT)
        self.assertEqual(len(granted), 3,
                          f"Expected 3 Act IV items, got {len(granted)}")

    def test_all_expected_act4_items_exist(self):
        """Every expected Act IV item must be granted by an Act IV choice."""
        granted = _act_granted_items(self.module, ACT)
        for item_id in EXPECTED_CORE_ITEMS:
            self.assertIn(item_id, granted,
                           f"Expected Act IV item not granted: {item_id}")

    def test_act4_granted_items_exist_in_items_json(self):
        """Every item granted by Act IV choices must exist in items.json."""
        for item_id in _act_granted_items(self.module, ACT):
            self.assertIn(item_id, self.module.items,
                           f"Granted item missing from items.json: {item_id}")

    def test_completion_artifact_granted(self):
        """The completion artifact must be granted by an Act IV choice."""
        granted = _act_granted_items(self.module, ACT)
        self.assertIn(COMPLETION_ARTIFACT, granted,
                       f"Completion artifact '{COMPLETION_ARTIFACT}' not granted")

    # ── 5. NPCs ──────────────────────────────────────────────────────

    def test_act4_has_3_npcs(self):
        """Act IV must reference exactly 3 NPCs."""
        scene_locs = _act_location_nodes(self.module, ACT)
        act4_npcs = [
            npc for npc in self.module.npcs.values()
            if npc.get("location", "") in scene_locs
        ]
        self.assertEqual(len(act4_npcs), 3,
                          f"Expected 3 Act IV NPCs, got {len(act4_npcs)}")

    def test_all_expected_act4_npcs_exist(self):
        """Every expected Act IV NPC must be referenced by a scene location."""
        scene_locs = _act_location_nodes(self.module, ACT)
        act4_npcs = {
            npc["id"] for npc in self.module.npcs.values()
            if npc.get("location", "") in scene_locs
        }
        for npc_id in EXPECTED_NPCS:
            self.assertIn(npc_id, act4_npcs,
                           f"Expected Act IV NPC missing: {npc_id}")

    # ── 6. Route Model ───────────────────────────────────────────────

    def test_completion_quest_exists(self):
        """The navigation quest must exist."""
        self.assertIn(COMPLETION_QUEST, self.module.quests,
                       f"Quest '{COMPLETION_QUEST}' not found")

    def test_completion_quest_references_valid_scene(self):
        """The quest's starts_at must resolve to an existing encounter."""
        quest = self.module.quests[COMPLETION_QUEST]
        starts = quest.get("starts_at", "")
        self.assertIn(starts, self.module.encounters,
                       f"Quest starts_at references missing scene: {starts}")

    def test_completion_quest_references_valid_items(self):
        """Any item referenced by quest objectives must exist in items.json."""
        quest = self.module.quests[COMPLETION_QUEST]
        for obj in quest.get("objectives", []):
            item_id = obj.get("item")
            if item_id:
                self.assertIn(item_id, self.module.items,
                               f"Quest objective {obj['id']} references missing item: {item_id}")

    def test_casserole_has_multiple_resolution_routes(self):
        """The Casserole Throne must offer at least 3 resolution choices."""
        throne = self.module.encounters.get("scene.act4.casserole_throne")
        self.assertIsNotNone(throne)
        choices = throne.get("choices", [])
        self.assertGreaterEqual(len(choices), 3,
                                "Casserole Throne must have >= 3 resolution routes")

    def test_all_routes_grant_same_artifact(self):
        """Every Casserole Throne route that grants an item grants the same artifact."""
        throne = self.module.encounters.get("scene.act4.casserole_throne")
        for choice in throne.get("choices", []):
            items = choice.get("grants_items", [])
            if items:
                self.assertEqual(items, [COMPLETION_ARTIFACT],
                                 f"Route '{choice['id']}' grants unexpected items: {items}")

    # ── 7. Assets ────────────────────────────────────────────────────

    def test_visual_manifest_exists(self):
        """visual_manifest.json must exist."""
        vm_path = self.root / "visual_manifest.json"
        self.assertTrue(vm_path.exists(), "visual_manifest.json not found")

    def test_generated_manifest_exists(self):
        """generated_manifest.json must exist."""
        gm_path = self.root / "assets" / "generated_manifest.json"
        self.assertTrue(gm_path.exists(), "generated_manifest.json not found")

    def test_act4_rooms_have_visual_manifest_entries(self):
        """Every Act IV location must have a room asset in visual_manifest.json."""
        vm = _load_json(self.root, "visual_manifest.json")
        room_ids = {
            a["asset_id"] for a in vm.get("assets", {}).get("rooms", [])
        }
        act4_room_assets = {
            f"room.{loc_id.split('location.', 1)[1]}"
            for loc_id in EXPECTED_LOCATIONS
        }
        for asset_id in act4_room_assets:
            self.assertIn(asset_id, room_ids,
                           f"Act IV room asset missing from visual_manifest: {asset_id}")

    def test_act4_items_have_visual_manifest_entries(self):
        """Every Act IV item must have an item asset in visual_manifest.json."""
        vm = _load_json(self.root, "visual_manifest.json")
        item_ids = {
            a["asset_id"] for a in vm.get("assets", {}).get("items", [])
        }
        for item_id in EXPECTED_CORE_ITEMS:
            vm_asset = f"item.{item_id.split('item.', 1)[1]}"
            self.assertIn(vm_asset, item_ids,
                           f"Act IV item asset missing from visual_manifest: {vm_asset}")

    def test_generated_manifest_paths_exist_on_disk(self):
        """Every path in generated_manifest.json must exist on disk."""
        gm = _load_json(self.root, "assets/generated_manifest.json")
        for asset in gm.get("generated_assets", []):
            full_path = self.root / asset["path"]
            self.assertTrue(full_path.exists(),
                            f"Generated asset missing on disk: {asset['path']}")

    # ── 8. Save/Load (non-duplicative) ───────────────────────────────

    def test_act4_flags_declared_in_starting_flags(self):
        """All Act IV flags used by the module must be in starting_flags."""
        starting = self.module.campaign.get("starting_flags", {})
        act4_flag_keys = [
            "act4_started", "moldric_guiding", "condiment_gate_opened",
            "leftover_catacombs_crossed", "freezer_shrine_visited",
            "freezer_blessing_obtained", "sentient_casserole_met",
            "sentient_casserole_resolved", "casserole_lid_fragment_obtained",
            "casserole_insulted", "act4_complete",
        ]
        for flag in act4_flag_keys:
            self.assertIn(flag, starting,
                           f"Act IV flag '{flag}' missing from starting_flags")

    # ── 9. PWA (non-duplicative structural checks) ───────────────────

    def test_html_has_help_button(self):
        """The HTML template must contain a help button."""
        html = Path("hive_lattice/web_app/templates/index.html").read_text()
        self.assertIn("showHelp()", html)

    def test_js_has_showHelp(self):
        """The JS must define showHelp()."""
        js = Path("hive_lattice/web_app/static/strawberry.js").read_text()
        self.assertIn("function showHelp()", js)

    # ── 10. Required tests checklist ─────────────────────────────────

    def test_content_lint_tool_exists(self):
        """content_lint.py must exist."""
        self.assertTrue(Path("tools/content_lint.py").exists())

    def test_validate_campaign_module_tool_exists(self):
        """validate_campaign_module.py must exist."""
        self.assertTrue(Path("tools/validate_campaign_module.py").exists())

    def test_validate_visual_assets_tool_exists(self):
        """validate_visual_assets.py must exist."""
        self.assertTrue(Path("tools/validate_visual_assets.py").exists())

    def test_act4_freeze_test_exists(self):
        """test_act4_freeze_verification.py must exist."""
        self.assertTrue(Path("tests/test_act4_freeze_verification.py").exists())

    def test_help_surfaces_test_exists(self):
        """test_help_surfaces.py must exist."""
        self.assertTrue(Path("tests/test_help_surfaces.py").exists())

    def test_smoke_test_exists(self):
        """test_act3_smoke.py must exist."""
        self.assertTrue(Path("tests/test_act3_smoke.py").exists())


class TestDungeonContractReusableHelpers(unittest.TestCase):
    """Reusable helpers that can be applied to any future act."""

    @classmethod
    def setUpClass(cls):
        cls.root = Path("campaigns/strawberry_omen")
        cls.module = CampaignModule(cls.root)

    def test_reusable_helper_act_scene_count(self):
        """Helper: _act_scenes returns correct count for Act I."""
        scenes = _act_scenes(self.module, 1)
        self.assertGreater(len(scenes), 0, "Act I should have scenes")

    def test_reusable_helper_act_choice_targets_resolve(self):
        """Helper: all choice targets in Act I resolve."""
        for target in _act_choice_targets(self.module, 1):
            self.assertIn(target, self.module.encounters,
                           f"Act I target not found: {target}")

    def test_reusable_helper_act_scene_locations_resolve(self):
        """Helper: all Act I scene locations resolve."""
        all_nodes = _all_node_ids(self.module)
        for loc in _act_location_nodes(self.module, 1):
            self.assertIn(loc, all_nodes,
                           f"Act I location not found: {loc}")

    def test_reusable_helper_act_granted_items_exist(self):
        """Helper: all items granted by Act I exist in items.json."""
        for item_id in _act_granted_items(self.module, 1):
            self.assertIn(item_id, self.module.items,
                           f"Act I granted item missing: {item_id}")


if __name__ == "__main__":
    unittest.main()
