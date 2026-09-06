"""Tests for the Hive-Lattice mobile web app (v1.0 PWA polish)."""

import json
import os
import shutil
import tempfile
import unittest

from hive_lattice.web_app.server import create_app, _asset_url
from engine.module_runtime import CampaignModule
from engine.module_save_system import ModuleSaveSystem


class TestWebAppCLI(unittest.TestCase):
    """CLI 'web' command dispatches correctly."""

    def test_web_command_exists(self):
        from hive_lattice.cli import COMMANDS
        self.assertIn("web", COMMANDS)

    def test_web_command_is_callable(self):
        from hive_lattice.cli import COMMANDS
        self.assertTrue(callable(COMMANDS["web"]))

    def test_web_usage_includes_web(self):
        from hive_lattice.cli import USAGE
        self.assertIn("web", USAGE.lower())


class TestWebAppAPI(unittest.TestCase):
    """Test Flask API endpoints via test client."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.module = CampaignModule("campaigns/strawberry_omen")
        self.app = create_app("campaigns/strawberry_omen")
        self.client = self.app.test_client()
        import hive_lattice.web_app.server as srv
        srv._saves = ModuleSaveSystem(self.module, save_dir=self.tmp_dir)

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_index_returns_html(self):
        resp = self.client.get("/")
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b"Strawberry Omen", resp.data)

    def test_api_state_returns_scene(self):
        resp = self.client.get("/api/state")
        self.assertEqual(resp.status_code, 200)
        data = json.loads(resp.data)
        self.assertIn("scene", data)
        self.assertIn("id", data["scene"])
        self.assertIn("title", data["scene"])
        self.assertIn("read_aloud", data["scene"])

    def test_api_state_returns_choices(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertIn("choices", data)
        self.assertIsInstance(data["choices"], list)
        self.assertGreater(len(data["choices"]), 0)
        for c in data["choices"]:
            self.assertIn("id", c)
            self.assertIn("label", c)

    def test_api_state_returns_location(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertIn("location", data)
        self.assertIn("id", data["location"])
        self.assertIn("name", data["location"])

    def test_api_state_returns_flags(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertIn("flags", data)
        self.assertIsInstance(data["flags"], dict)

    def test_api_state_returns_stats(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertIn("stats", data)
        self.assertIsInstance(data["stats"], dict)

    def test_api_state_returns_inventory(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertIn("inventory", data)
        self.assertIsInstance(data["inventory"], list)

    def test_api_state_returns_arena_inactive_by_default(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertIn("arena", data)
        self.assertFalse(data["arena"]["active"])
        self.assertIsNone(data["arena"]["render_url"])

    def test_api_arena_render_404_when_not_in_arena_scene(self):
        resp = self.client.get("/api/arena/render")
        self.assertEqual(resp.status_code, 404)

    def test_api_state_returns_arena_active_in_hearing_scene(self):
        import hive_lattice.web_app.server as srv
        srv._state.current_scene = "scene.act5.hearing_arena_entry"
        srv._state.current_location = "location.department_of_adjudication.hearing_arena"
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertTrue(data["arena"]["active"])
        self.assertEqual(data["arena"]["render_url"], "/api/arena/render")

    def test_api_arena_render_returns_png_in_hearing_scene(self):
        import hive_lattice.web_app.server as srv
        from engine.render_bridge import is_renderer_available
        srv._state.current_scene = "scene.act5.hearing_arena_entry"
        srv._state.current_location = "location.department_of_adjudication.hearing_arena"
        resp = self.client.get("/api/arena/render")
        if is_renderer_available():
            self.assertEqual(resp.status_code, 200)
            self.assertEqual(resp.mimetype, "image/png")
            self.assertEqual(resp.data[:8], b"\x89PNG\r\n\x1a\n")
        else:
            self.assertEqual(resp.status_code, 503)
            data = json.loads(resp.data)
            self.assertIn("error", data)

    def test_api_state_returns_visual_metadata(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        self.assertIn("images", data)
        self.assertIn("map", data["images"])
        self.assertIn("room", data["images"])

    def test_api_choice_advances_state(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        choice_id = data["choices"][0]["id"]

        resp = self.client.post(
            "/api/choice",
            data=json.dumps({"choice_id": choice_id}),
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 200)
        data = json.loads(resp.data)
        self.assertTrue(data["ok"])
        self.assertIn("scene", data)

    def test_api_choice_missing_id(self):
        resp = self.client.post(
            "/api/choice",
            data=json.dumps({}),
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)
        data = json.loads(resp.data)
        self.assertIn("error", data)

    def test_api_choice_invalid_id(self):
        resp = self.client.post(
            "/api/choice",
            data=json.dumps({"choice_id": "bogus_choice"}),
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)
        data = json.loads(resp.data)
        self.assertIn("error", data)

    def test_api_save(self):
        resp = self.client.post("/api/save")
        self.assertEqual(resp.status_code, 200)
        data = json.loads(resp.data)
        self.assertTrue(data["ok"])
        self.assertIn("saved", data["message"].lower())

    def test_api_load_no_save(self):
        resp = self.client.post("/api/load")
        self.assertEqual(resp.status_code, 404)
        data = json.loads(resp.data)
        self.assertFalse(data["ok"])
        self.assertIn("error", data)

    def test_api_load_after_save(self):
        self.client.post("/api/save")
        resp = self.client.post("/api/load")
        self.assertEqual(resp.status_code, 200)
        data = json.loads(resp.data)
        self.assertTrue(data["ok"])
        self.assertIn("scene", data)

    def test_api_saves(self):
        resp = self.client.get("/api/saves")
        self.assertEqual(resp.status_code, 200)
        data = json.loads(resp.data)
        self.assertIn("saves", data)
        self.assertIsInstance(data["saves"], list)

    def test_api_delete_save(self):
        resp = self.client.post("/api/delete-save")
        self.assertEqual(resp.status_code, 200)
        data = json.loads(resp.data)
        self.assertTrue(data["ok"])


class TestWebAppSecurity(unittest.TestCase):
    """Test API security and path traversal protection."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.module = CampaignModule("campaigns/strawberry_omen")
        self.app = create_app("campaigns/strawberry_omen")
        self.client = self.app.test_client()
        import hive_lattice.web_app.server as srv
        srv._saves = ModuleSaveSystem(self.module, save_dir=self.tmp_dir)

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_assets_rejects_path_traversal(self):
        resp = self.client.get("/api/assets/../../../etc/passwd")
        self.assertIn(resp.status_code, [403, 404])

    def test_assets_rejects_double_dot(self):
        resp = self.client.get("/api/assets/foo/../../bar")
        self.assertIn(resp.status_code, [403, 404])

    def test_assets_rejects_non_image(self):
        resp = self.client.get("/api/assets/something.py")
        self.assertIn(resp.status_code, [403, 404])

    def test_assets_rejects_nonexistent(self):
        resp = self.client.get("/api/assets/does_not_exist.png")
        self.assertEqual(resp.status_code, 404)


class TestAssetURLs(unittest.TestCase):
    """Test that /api/state returns browser-safe image URLs that resolve."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.module = CampaignModule("campaigns/strawberry_omen")
        self.app = create_app("campaigns/strawberry_omen")
        self.client = self.app.test_client()
        import hive_lattice.web_app.server as srv
        srv._saves = ModuleSaveSystem(self.module, save_dir=self.tmp_dir)

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_map_url_is_browser_safe(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        url = data["images"]["map"]
        self.assertIsNotNone(url)
        self.assertTrue(url.startswith("/api/assets/"))
        self.assertNotIn("campaigns", url)
        self.assertNotIn("assets/generated", url)

    def test_room_url_is_browser_safe(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        url = data["images"]["room"]
        self.assertIsNotNone(url)
        self.assertTrue(url.startswith("/api/assets/"))
        self.assertNotIn("campaigns", url)
        self.assertNotIn("assets/generated", url)

    def test_map_url_returns_200(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        url = data["images"]["map"]
        self.assertIsNotNone(url)
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)

    def test_room_url_returns_200(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        url = data["images"]["room"]
        self.assertIsNotNone(url)
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)

    def test_map_url_returns_image_content_type(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        url = data["images"]["map"]
        resp = self.client.get(url)
        self.assertTrue(resp.content_type.startswith("image/"))

    def test_room_url_returns_image_content_type(self):
        resp = self.client.get("/api/state")
        data = json.loads(resp.data)
        url = data["images"]["room"]
        resp = self.client.get(url)
        self.assertTrue(resp.content_type.startswith("image/"))

    def test_asset_url_helper_with_path(self):
        asset = {"filename": "test.png", "path": "assets/generated/maps/map.breakroom.png"}
        self.assertEqual(_asset_url(asset), "/api/assets/maps/map.breakroom.png")

    def test_asset_url_helper_with_tokens_path(self):
        asset = {"path": "assets/generated/tokens/token.darla.png"}
        self.assertEqual(_asset_url(asset), "/api/assets/tokens/token.darla.png")

    def test_asset_url_helper_returns_none_for_none(self):
        self.assertIsNone(_asset_url(None))

    def test_asset_url_helper_returns_none_for_empty(self):
        self.assertIsNone(_asset_url({}))


class TestPWAManifest(unittest.TestCase):
    """Test PWA manifest and related features."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.app = create_app("campaigns/strawberry_omen")
        self.client = self.app.test_client()
        import hive_lattice.web_app.server as srv
        srv._saves = ModuleSaveSystem(
            CampaignModule("campaigns/strawberry_omen"), save_dir=self.tmp_dir
        )

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_manifest_route_returns_json(self):
        resp = self.client.get("/static/manifest.webmanifest")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.content_type, "application/manifest+json")

    def test_manifest_contains_name(self):
        resp = self.client.get("/static/manifest.webmanifest")
        data = json.loads(resp.data)
        self.assertEqual(data["name"], "Strawberry Omen")

    def test_manifest_contains_short_name(self):
        resp = self.client.get("/static/manifest.webmanifest")
        data = json.loads(resp.data)
        self.assertEqual(data["short_name"], "Wetberry")

    def test_manifest_contains_display(self):
        resp = self.client.get("/static/manifest.webmanifest")
        data = json.loads(resp.data)
        self.assertEqual(data["display"], "standalone")

    def test_manifest_contains_start_url(self):
        resp = self.client.get("/static/manifest.webmanifest")
        data = json.loads(resp.data)
        self.assertEqual(data["start_url"], "/")

    def test_manifest_contains_theme_color(self):
        resp = self.client.get("/static/manifest.webmanifest")
        data = json.loads(resp.data)
        self.assertEqual(data["theme_color"], "#e63946")

    def test_manifest_contains_background_color(self):
        resp = self.client.get("/static/manifest.webmanifest")
        data = json.loads(resp.data)
        self.assertEqual(data["background_color"], "#0d0d0d")

    def test_manifest_contains_icons(self):
        resp = self.client.get("/static/manifest.webmanifest")
        data = json.loads(resp.data)
        self.assertIn("icons", data)
        self.assertGreater(len(data["icons"]), 0)

    def test_index_links_manifest(self):
        resp = self.client.get("/")
        html = resp.data.decode()
        self.assertIn('manifest.webmanifest', html)

    def test_index_has_theme_color_meta(self):
        resp = self.client.get("/")
        html = resp.data.decode()
        self.assertIn('theme-color', html)

    def test_index_has_apple_mobile_web_app_capable(self):
        resp = self.client.get("/")
        html = resp.data.decode()
        self.assertIn('apple-mobile-web-app-capable', html)

    def test_index_has_apple_mobile_web_app_title(self):
        resp = self.client.get("/")
        html = resp.data.decode()
        self.assertIn('apple-mobile-web-app-title', html)

    def test_index_has_viewport_meta(self):
        resp = self.client.get("/")
        html = resp.data.decode()
        self.assertIn('viewport', html)

    def test_service_worker_route_returns_js(self):
        resp = self.client.get("/static/sw.js")
        self.assertEqual(resp.status_code, 200)
        self.assertIn("javascript", resp.content_type)

    def test_service_worker_contains_install_listener(self):
        resp = self.client.get("/static/sw.js")
        js = resp.data.decode()
        self.assertIn("install", js)

    def test_service_worker_contains_fetch_listener(self):
        resp = self.client.get("/static/sw.js")
        js = resp.data.decode()
        self.assertIn("fetch", js)

    def test_icon_192_exists(self):
        resp = self.client.get("/static/icons/icon-192.png")
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.content_type.startswith("image/"))

    def test_icon_512_exists(self):
        resp = self.client.get("/static/icons/icon-512.png")
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.content_type.startswith("image/"))


class TestUXElements(unittest.TestCase):
    """Test that UX polish HTML elements exist in the index page."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.app = create_app("campaigns/strawberry_omen")
        self.client = self.app.test_client()
        import hive_lattice.web_app.server as srv
        srv._saves = ModuleSaveSystem(
            CampaignModule("campaigns/strawberry_omen"), save_dir=self.tmp_dir
        )

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def _html(self):
        return self.client.get("/").data.decode()

    def test_toast_element_exists(self):
        self.assertIn('id="toast"', self._html())

    def test_offline_banner_exists(self):
        self.assertIn('id="offline-banner"', self._html())

    def test_preview_modal_exists(self):
        self.assertIn('id="preview-modal"', self._html())

    def test_preview_img_exists(self):
        self.assertIn('id="preview-img"', self._html())

    def test_collapsible_panels_exist(self):
        self.assertIn('id="collapsible-panels"', self._html())

    def test_inventory_collapse_body_exists(self):
        self.assertIn('id="inventory-body"', self._html())

    def test_state_collapse_body_exists(self):
        self.assertIn('id="state-body"', self._html())

    def test_reload_button_exists(self):
        self.assertIn('id="reload-btn"', self._html())

    def test_assets_button_in_bottom_bar(self):
        html = self._html()
        self.assertIn("Assets", html)

    def test_act_bar_exists(self):
        self.assertIn('id="act-bar"', self._html())


if __name__ == "__main__":
    unittest.main()
