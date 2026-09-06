"""v0.7 World in Motion Visual RPG Slice — Comprehensive Acceptance Tests.

Verifies:
1. Engine remains authoritative for reality, movement, interaction, inventory, and saves.
2. Renderer receives authoritative snapshot without scene-name NPC inference.
3. Canonical character identity lookup and ActorDynamics-to-portrait visual state mapping.
4. Offline-first local assets (no runtime CDN dependencies).
5. Wetberry acceptance path (Walk -> Keith -> Evidence Bag -> Wetberry -> Contain -> Persist -> Save/Load).
6. Classic adventure verb palette and dialogue portrait contracts.
7. Mobile UX and debug mode constraints.
"""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem
from engine.world_contracts import GameAction
from engine.world_runtime import WorldRuntime
from hive_lattice.web_app.server import create_app

ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT / "campaigns" / "strawberry_omen"


class TestRPGVisualSliceEngineContract(unittest.TestCase):
    def setUp(self):
        self.module = CampaignModule(CAMPAIGN)
        self.state = self.module.new_state()
        self.module.enter_scene(self.state)
        self.world = WorldRuntime(self.module)
        self.world.ensure_state(self.state)

    def test_authoritative_snapshot_structure(self):
        snapshot = self.world.snapshot(self.state)
        self.assertEqual(snapshot["schema"], "hive_world_snapshot_v1")
        self.assertTrue(snapshot["world"]["enabled"])
        self.assertEqual(snapshot["world"]["id"], "world.breakroom.main")
        self.assertIn("player", snapshot)
        self.assertIn("entities", snapshot)
        self.assertIn("hotspots", snapshot)

    def test_keith_and_darla_canonical_identities(self):
        snapshot = self.world.snapshot(self.state)
        keith = next(e for e in snapshot["entities"] if e["id"] == "npc.keith_janitor")
        darla = next(e for e in snapshot["entities"] if e["id"] == "npc.darla_microwave")

        self.assertEqual(keith["name"], "Keith the Janitor")
        self.assertEqual(darla["name"], "Darla of the Microwave")

        # Keith signature traits from character_identities.json
        keith_shapes = [layer["shape"] for layer in keith["identity"]["layers"]]
        self.assertIn("maintenance_cap", keith_shapes)
        self.assertIn("evidence_bag", keith_shapes)
        self.assertIn("mop_handle", keith_shapes)

        # Darla signature traits
        darla_shapes = [layer["shape"] for layer in darla["identity"]["layers"]]
        self.assertIn("cardigan", darla_shapes)
        self.assertIn("coffee_mug", darla_shapes)

    def test_wetberry_full_acceptance_path(self):
        """Execute the complete 19-step Wetberry loop."""
        # 1. Player enters Breakroom at Central Table
        self.assertEqual(self.state.current_location, "location.breakroom.central_table")

        # 2. Player walks to Keith's coordinates
        self.state.world_state["player"] = {"x": 78.0, "y": 74.0}

        # 3. Keith is in proximity
        snapshot = self.world.snapshot(self.state)
        nearby_ids = [n["id"] for n in snapshot["nearby"]]
        self.assertIn("npc.keith_janitor", nearby_ids)

        # 4. Player interacts / talks to Keith
        res = self.world.apply_action(self.state, GameAction(kind="interact", target_id="npc.keith_janitor"))
        self.assertEqual(self.state.current_scene, "scene.act1.keith_corner")

        # 5. Player chooses ask_for_evidence_bag
        self.module.choose(self.state, "ask_for_evidence_bag")

        # 6. Inventory visibly has Evidence Bag
        self.assertIn("item.evidence_bag_not_my_business", self.state.inventory)
        self.assertEqual(self.state.flags.get("keith_trust"), 1)

        # 7. Player walks to Wetberry at Central Table
        self.state.current_location = "location.breakroom.central_table"
        self.state.current_scene = "scene.act1.first_sighting"
        self.state.world_state["player"] = {"x": 50.0, "y": 52.0}

        # 8. Wetberry is in proximity
        snapshot = self.world.snapshot(self.state)
        nearby_ids = [n["id"] for n in snapshot["nearby"]]
        self.assertIn("hotspot.wetberry", nearby_ids)

        # 9. Player uses Evidence Bag on Wetberry through authored interaction
        use_res = self.module.use_item(self.state, "use.evidence_bag.wetberry")
        self.assertIn("bag wetberry", use_res.lower())

        # 10. Wetberry is contained, transforms into Bagged Wetberry in inventory
        self.assertTrue(self.state.flags.get("wetberry_contained"))
        self.assertNotIn("item.evidence_bag_not_my_business", self.state.inventory)
        self.assertIn("item.bagged_wetberry_evidence", self.state.inventory)

        # 11. Wetberry hotspot disappears from world snapshot
        post_snapshot = self.world.snapshot(self.state)
        self.assertFalse(any(h["id"] == "hotspot.wetberry" for h in post_snapshot["hotspots"]))

        # 12 & 13. Change location and return
        self.state.current_location = "location.breakroom.coffee_counter"
        self.world.ensure_state(self.state)
        self.state.current_location = "location.breakroom.central_table"
        self.world.ensure_state(self.state)

        # 14 & 15. Wetberry remains contained and Keith retains relationship
        snapshot_after_return = self.world.snapshot(self.state)
        self.assertFalse(any(h["id"] == "hotspot.wetberry" for h in snapshot_after_return["hotspots"]))
        self.assertEqual(self.state.npc_memory.get("npc.keith_janitor"), 3)

        # 16, 17, 18, 19. Save, mutate, load, verify restoration
        tmp_dir = tempfile.mkdtemp()
        try:
            saves = ModuleSaveSystem(self.module, save_dir=tmp_dir)
            saves.save_game(self.state)

            # Mutate state in memory
            self.state.flags["wetberry_contained"] = False
            self.state.inventory = []
            self.state.world_state["player"] = {"x": 10.0, "y": 10.0}

            # Load saved state
            loaded = saves.load_game()
            self.assertIsNotNone(loaded)
            self.assertTrue(loaded.flags.get("wetberry_contained"))
            self.assertIn("item.bagged_wetberry_evidence", loaded.inventory)
            self.assertEqual(loaded.world_state["player"]["x"], 50.0)
            self.assertEqual(loaded.world_state["player"]["y"], 52.0)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)


class TestRPGVisualFrontendContract(unittest.TestCase):
    def setUp(self):
        self.html = (ROOT / "hive_lattice/web_app/templates/index.html").read_text(encoding="utf-8")
        self.js = (ROOT / "hive_lattice/web_app/static/strawberry.js").read_text(encoding="utf-8")
        self.world_js = (ROOT / "hive_lattice/web_app/static/world_client.js").read_text(encoding="utf-8")
        self.css = (ROOT / "hive_lattice/web_app/static/strawberry.css").read_text(encoding="utf-8")
        self.sw = (ROOT / "hive_lattice/web_app/static/sw.js").read_text(encoding="utf-8")

    def test_no_cdn_dependencies(self):
        """Zero external CDN links in html, js, css."""
        for text in (self.html, self.js, self.world_js, self.css, self.sw):
            self.assertNotIn("https://cdn.", text)
            self.assertNotIn("https://cdnjs.", text)
            self.assertNotIn("https://unpkg.com", text)
            self.assertNotIn("https://cdn.jsdelivr.net", text)

    def test_classic_adventure_verbs_present(self):
        for verb in ("LOOK", "TALK", "TAKE", "USE", "OPEN", "GO"):
            self.assertIn(f"executeVerb('{verb}')", self.html)
        self.assertIn("async function executeVerb", self.js)

    def test_dialogue_portrait_frame_present(self):
        self.assertIn('id="dialogue-portrait-box"', self.html)
        self.assertIn('id="dialogue-portrait-img"', self.html)
        self.assertIn("function renderDialoguePortrait", self.js)
        self.assertIn(".portrait-box", self.css)

    def test_tactile_inventory_icons_rendered(self):
        self.assertIn("inventory-item-icon", self.js)
        self.assertIn(".inventory-item-icon", self.css)

    def test_debug_mode_toggle_and_hidden_by_default(self):
        self.assertIn("toggleDebugMode", self.js)
        self.assertIn("toggleDebug", self.world_js)
        self.assertIn("this.debugMode =", self.world_js)
        # Normal mode must NOT draw debug grid by default
        self.assertIn("if (this.debugMode)", self.world_js)

    def test_offline_service_worker_caches_rpg_assets(self):
        self.assertIn("wetberry-shell-v070-rpg1", self.sw)
        self.assertIn("room.breakroom.illustrated.png", self.sw)
        self.assertIn("keith_neutral.png", self.sw)
        self.assertIn("darla_neutral.png", self.sw)
        self.assertIn("item.evidence_bag_not_my_business.png", self.sw)

    def test_local_asset_files_exist_on_disk(self):
        gen_dir = ROOT / "campaigns" / "strawberry_omen" / "assets" / "generated"
        self.assertTrue((gen_dir / "rooms" / "room.breakroom.central_table.png").exists())
        self.assertTrue((gen_dir / "portraits" / "keith_neutral.png").exists())
        self.assertTrue((gen_dir / "portraits" / "keith_annoyed.png").exists())
        self.assertTrue((gen_dir / "portraits" / "keith_engaged.png").exists())
        self.assertTrue((gen_dir / "portraits" / "darla_neutral.png").exists())
        self.assertTrue((gen_dir / "portraits" / "darla_annoyed.png").exists())
        self.assertTrue((gen_dir / "portraits" / "darla_engaged.png").exists())
        self.assertTrue((gen_dir / "portraits" / "tammy_procedural.png").exists())
        self.assertTrue((gen_dir / "items" / "item.evidence_bag_not_my_business.png").exists())
        self.assertTrue((gen_dir / "items" / "item.bagged_wetberry_evidence.png").exists())
        self.assertTrue((gen_dir / "items" / "item.wetberry.png").exists())


class TestWebAppRPGEndpoints(unittest.TestCase):
    def setUp(self):
        self.app = create_app(CAMPAIGN)
        self.client = self.app.test_client()

    def test_state_endpoint_returns_portraits_and_inventory_icons(self):
        res = self.client.get("/api/state")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn("portraits", data)
        self.assertIn("keith", data["portraits"])
        self.assertIn("darla", data["portraits"])
        self.assertIn("tammy", data["portraits"])
        self.assertIn("world", data)
        self.assertTrue(data["world"]["world"]["enabled"])

    def test_world_endpoint_returns_valid_snapshot(self):
        res = self.client.get("/api/world")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data["schema"], "hive_world_snapshot_v1")
        self.assertEqual(data["world"]["id"], "world.breakroom.main")

    def test_assets_endpoint_serves_portraits_and_items(self):
        p_res = self.client.get("/api/assets/portraits/keith_neutral.png")
        self.assertEqual(p_res.status_code, 200)
        self.assertEqual(p_res.mimetype, "image/png")
        p_res.close()

        i_res = self.client.get("/api/assets/items/item.evidence_bag_not_my_business.png")
        self.assertEqual(i_res.status_code, 200)
        self.assertEqual(i_res.mimetype, "image/png")
        i_res.close()


class TestMechanicsHardeningEngine(unittest.TestCase):
    def setUp(self):
        self.module = CampaignModule(CAMPAIGN)
        self.state = self.module.new_state()
        self.module.enter_scene(self.state)
        self.world = WorldRuntime(self.module)
        self.world.ensure_state(self.state)

    def test_blocked_regions_authored(self):
        snapshot = self.world.snapshot(self.state)
        world_data = snapshot["world"]
        self.assertIn("blocked_regions", world_data)
        regions = {b["name"]: b for b in world_data["blocked_regions"]}
        self.assertIn("Central Table", regions)
        self.assertIn("Coffee Counter & Microwave", regions)
        self.assertIn("Vending Machine", regions)
        self.assertIn("Utility Locker", regions)
        self.assertIn("Back Wall", regions)

        table = regions["Central Table"]
        self.assertEqual(table["min_x"], 35)
        self.assertEqual(table["max_x"], 65)
        self.assertEqual(table["min_y"], 50)
        self.assertEqual(table["max_y"], 68)

    def test_movement_collision_clamping(self):
        # Moving directly into the center of the central table (50.0, 60.0) must be blocked/clamped
        res = self.world.apply_action(self.state, GameAction(kind="move", x=50.0, y=60.0))
        player = self.state.world_state["player"]
        # Position must not be inside the table interior
        in_table = (35 <= player["x"] <= 65) and (50 <= player["y"] <= 68)
        self.assertFalse(in_table, f"Player moved inside blocked table region: {player}")

    def test_movement_boundary_clamping(self):
        # Moving out of bounds
        res = self.world.apply_action(self.state, GameAction(kind="move", x=120.0, y=-10.0))
        player = self.state.world_state["player"]
        self.assertLessEqual(player["x"], 94.0)
        self.assertGreaterEqual(player["y"], 20.0)

    def test_semantic_verb_execution(self):
        # Move close to Keith (position x: 82, y: 72)
        self.state.world_state["player"] = {"x": 80.0, "y": 72.0}

        # LOOK at Keith
        res = self.world.apply_action(self.state, GameAction(
            kind="verb",
            target_id="npc.keith_janitor",
            payload={"verb": "LOOK"}
        ))
        self.assertIn("Keith stands beside his mop bucket", res["result"])

        # TALK to Keith
        res = self.world.apply_action(self.state, GameAction(
            kind="verb",
            target_id="npc.keith_janitor",
            payload={"verb": "TALK"}
        ))
        self.assertTrue(len(res["result"]) > 0)

        # USE on Keith without item
        res = self.world.apply_action(self.state, GameAction(
            kind="verb",
            target_id="npc.keith_janitor",
            payload={"verb": "USE", "item_id": None}
        ))
        self.assertIn("Select an item", res["result"])

        # OPEN on Keith
        res = self.world.apply_action(self.state, GameAction(
            kind="verb",
            target_id="npc.keith_janitor",
            payload={"verb": "OPEN"}
        ))
        self.assertIn("personal boundaries remain sealed", res["result"])

    def test_scenery_hotspots_and_verbs(self):
        # Central Table approach
        self.state.world_state["player"] = {"x": 50.0, "y": 72.0}
        res = self.world.apply_action(self.state, GameAction(
            kind="verb",
            target_id="hotspot.central_table",
            payload={"verb": "LOOK"}
        ))
        self.assertIn("Formica table", res["result"])

        # Coffee machine approach
        self.state.world_state["player"] = {"x": 50.0, "y": 36.0}
        res = self.world.apply_action(self.state, GameAction(
            kind="verb",
            target_id="hotspot.coffee_machine",
            payload={"verb": "LOOK"}
        ))
        self.assertIn("microwave", res["result"].lower())

    def test_chronicle_log_idempotency(self):
        self.state.world_state["player"] = {"x": 50.0, "y": 72.0}
        initial_log_len = len(self.state.log)

        # Applying a look action
        res = self.world.apply_action(self.state, GameAction(
            kind="verb",
            target_id="hotspot.central_table",
            payload={"verb": "LOOK"}
        ))
        log = self.state.log
        # Log should increase by exactly 1 entry, never duplicated
        self.assertEqual(len(log), initial_log_len + 1)
        self.assertEqual(log[-1], res["result"])

        # Choosing an action from module runtime
        choices = self.module.choice_views(self.state)
        choice_id = choices[0]["id"]
        res_choice = self.module.choose(self.state, choice_id)
        # Check that the last 2 log entries are not identical duplicates
        self.assertNotEqual(self.state.log[-1], self.state.log[-2] if len(self.state.log) >= 2 else "")


class TestMechanicsHardeningWeb(unittest.TestCase):
    def setUp(self):
        self.app = create_app(CAMPAIGN)
        self.client = self.app.test_client()

    def test_minimap_hidden_in_css(self):
        res = self.client.get("/static/strawberry.css")
        self.assertEqual(res.status_code, 200)
        css = res.get_data(as_text=True)
        res.close()
        self.assertIn("#minimap-panel {", css)
        self.assertIn("display: none;", css)
        self.assertIn(".debug-active", css)

    def test_stage_viewport_aspect_ratio(self):
        res = self.client.get("/static/strawberry.css")
        self.assertEqual(res.status_code, 200)
        css = res.get_data(as_text=True)
        res.close()
        self.assertIn("aspect-ratio: 4 / 3;", css)
        self.assertNotIn("aspect-ratio: 1 / 1;", css)

    def test_verb_endpoint_via_api(self):
        # Walk player closer to Keith first so verb has proximity
        self.client.post("/api/action", json={"kind": "move", "x": 80.0, "y": 72.0})
        res = self.client.post("/api/action", json={
            "kind": "verb",
            "target_id": "npc.keith_janitor",
            "payload": {"verb": "LOOK"}
        })
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        res.close()
        self.assertIn("result", data)
        self.assertIn("Keith stands beside his mop bucket", data["result"])


if __name__ == "__main__":
    unittest.main()

