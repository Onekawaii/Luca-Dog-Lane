"""Regression gate preserving the frozen v0.5.2 mobile-first UX in v0.6.0."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from hive_lattice.web_app.presentation import derive_act_progression

ROOT = Path(__file__).resolve().parents[1]
CSS = (ROOT / "hive_lattice/web_app/static/strawberry.css").read_text(encoding="utf-8")
JS = (ROOT / "hive_lattice/web_app/static/strawberry.js").read_text(encoding="utf-8")
HTML = (ROOT / "hive_lattice/web_app/templates/index.html").read_text(encoding="utf-8")
SERVER = (ROOT / "hive_lattice/web_app/server.py").read_text(encoding="utf-8")
GITIGNORE = (ROOT / ".gitignore").read_text(encoding="utf-8")
SW = (ROOT / "hive_lattice/web_app/static/sw.js").read_text(encoding="utf-8")
MANIFEST = (ROOT / "hive_lattice/web_app/static/manifest.webmanifest").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
STATUS = (ROOT / "STATUS.md").read_text(encoding="utf-8")
RUNBOOK = (ROOT / "RUNBOOK.md").read_text(encoding="utf-8")
PROVENANCE = (ROOT / "BUILD_PROVENANCE.json").read_text(encoding="utf-8")


class TestCanonicalActProgression(unittest.TestCase):
    def test_act1_is_initial(self):
        p = derive_act_progression({})
        self.assertEqual(p["current_label"], "Act I")
        self.assertTrue(p["acts"][0]["active"])

    def test_fridge_unlock_activates_act2(self):
        p = derive_act_progression({"fridge_unlocked": True})
        self.assertEqual(p["current_label"], "Act II")
        self.assertTrue(p["acts"][0]["done"])
        self.assertTrue(p["acts"][1]["active"])

    def test_legacy_entered_fridge_activates_act2(self):
        p = derive_act_progression({"entered_fridge": True})
        self.assertEqual(p["current_label"], "Act II")

    def test_act2_complete_activates_act3(self):
        p = derive_act_progression({"act2_complete": True})
        self.assertEqual(p["current_label"], "Act III")

    def test_act3_complete_activates_act4(self):
        p = derive_act_progression({"act3_complete": True})
        self.assertEqual(p["current_label"], "Act IV")

    def test_act4_complete_activates_act5(self):
        p = derive_act_progression({"act4_complete": True})
        self.assertEqual(p["current_label"], "Act V")

    def test_act5_complete_reports_complete(self):
        p = derive_act_progression({"act5_complete": True})
        self.assertEqual(p["current_label"], "Act V Complete")
        self.assertTrue(p["complete"])
        self.assertTrue(all(a["done"] for a in p["acts"]))

    def test_later_completion_cascades_earlier_completion(self):
        p = derive_act_progression({"act4_complete": True})
        self.assertTrue(all(a["done"] for a in p["acts"][:4]))
        self.assertTrue(p["acts"][4]["active"])


class TestMobileMarkup(unittest.TestCase):
    def test_zoom_is_not_disabled(self):
        self.assertNotIn("user-scalable=no", HTML)
        self.assertNotIn("maximum-scale=1.0", HTML)
        self.assertIn("viewport-fit=cover", HTML)

    def test_toast_is_live_region(self):
        self.assertIn('role="status"', HTML)
        self.assertIn('aria-live="polite"', HTML)

    def test_bottom_actions_have_mobile_class(self):
        self.assertGreaterEqual(HTML.count("bottom-action"), 3)

    def test_global_hidden_primitive_exists(self):
        self.assertRegex(CSS, r"(?s)\.hidden\s*\{\s*display:\s*none\s*!important")

    def test_touch_targets_have_48px_floor(self):
        self.assertIn("min-height: 48px", CSS)
        self.assertIn("#bottom-bar .bar-btn", CSS)
        self.assertIn(".tab-btn", CSS)

    def test_portrait_choices_are_single_column(self):
        mobile = CSS[CSS.index("/* Responsive Overrides") :]
        self.assertIn("flex-direction: column", mobile)
        self.assertRegex(mobile, r"(?s)\.choice-btn\s*\{[^}]*width:\s*100%")
        self.assertRegex(mobile, r"(?s)\.choice-btn\s*\{[^}]*min-height:\s*56px")

    def test_mobile_page_can_scroll(self):
        mobile = CSS[CSS.index("/* Responsive Overrides") :]
        self.assertIn("overflow-y: auto", mobile)
        self.assertIn("overflow-x: hidden", mobile)

    def test_bottom_bar_accounts_for_safe_area(self):
        self.assertIn("env(safe-area-inset-bottom)", CSS)
        self.assertRegex(CSS, r"(?s)#bottom-bar\s*\{[^}]*position:\s*fixed")

    def test_landscape_has_explicit_breakpoint(self):
        self.assertIn("orientation: landscape", CSS)
        self.assertIn("max-height: 520px", CSS)

    def test_room_art_preserves_aspect_ratio(self):
        stage_rule = CSS[CSS.index(".stage-bg-img") : CSS.index(".stage-fallback")]
        self.assertIn("object-fit: contain", stage_rule)

    def test_pwa_orientation_allows_rotation(self):
        self.assertIn('"orientation": "any"', MANIFEST)

    def test_service_worker_cache_is_release_bumped(self):
        self.assertIn('wetberry-shell-v060-alive', SW)

    def test_service_worker_shell_is_network_first(self):
        self.assertIn('network-first shell', SW)
        self.assertRegex(SW, r'(?s)event\.respondWith\(\s*fetch\(event\.request\)')


class TestFrontendStateConsistency(unittest.TestCase):
    def test_server_exposes_derived_progression(self):
        self.assertIn("derive_act_progression", SERVER)
        self.assertIn('"progression": derive_act_progression(_state.flags)', SERVER)

    def test_header_uses_server_progression(self):
        self.assertIn("progression.current_label", JS)
        header_region = JS[JS.index("function render(data)") : JS.index("function renderVisualStage")]
        self.assertNotIn("entered_fridge", header_region)

    def test_protocols_use_same_progression_payload(self):
        region = JS[JS.index("function renderSidebarQuests") : JS.index("function renderSidebarInventory")]
        self.assertIn("data.progression", region)
        self.assertNotIn("fridge_unlocked", region)

    def test_save_feedback_contains_state_summary(self):
        self.assertIn("Saved — ${stateSummary(currentState)}", JS)

    def test_load_feedback_contains_state_summary(self):
        self.assertIn("Loaded — ${stateSummary(data)}", JS)

    def test_stage_reset_hides_all_optional_layers(self):
        region = JS[JS.index("function renderVisualStage") : JS.index("/* ── Sidebars Renderers")]
        for element in ("roomImg", "roomFallback", "arenaImg", "arenaLoading"):
            self.assertIn(f'{element}.classList.add("hidden")', region)
        self.assertIn('npcSpriteImg.className = "npc-sprite hidden"', region)

    def test_renderer_failure_restores_room(self):
        region = JS[JS.index("function renderVisualStage") : JS.index("/* ── Sidebars Renderers")]
        self.assertRegex(region, r"(?s)\.catch\(\(\) => \{.*?showRoom\(\);")


class TestReleaseHygiene(unittest.TestCase):
    def test_global_image_wildcards_are_not_ignored(self):
        active = []
        for raw in GITIGNORE.splitlines():
            line = raw.strip()
            if line and not line.startswith("#"):
                active.append(line)
        for bad in ("*.png", "*.jpg", "*.jpeg", "*.gif"):
            self.assertNotIn(bad, active)

    def test_outputs_directory_is_still_ignored(self):
        self.assertRegex(GITIGNORE, r"(?m)^outputs/$")

    def test_current_release_docs_share_version_and_test_count(self):
        for text in (README, STATUS, RUNBOOK):
            self.assertIn("v0.6.0-lattice-alive", text)
            self.assertIn("370", text)
        self.assertIn('"version": "0.6.0"', PROVENANCE)
        self.assertIn('"full_suite_defined": 370', PROVENANCE)

    def test_current_release_docs_do_not_claim_old_test_counts(self):
        for text in (README, STATUS, RUNBOOK):
            self.assertNotIn("242 tests", text)
            self.assertNotIn("303 tests", text)
            self.assertNotIn("311 tests", text)

    def test_status_records_real_android_playtest(self):
        self.assertIn("Android/Termux", STATUS)
        self.assertIn("Desktop Site", STATUS)


if __name__ == "__main__":
    unittest.main()
