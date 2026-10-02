import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUCA = ROOT / "game_godot" / "scripts" / "luca"
MANIFEST_PATH = ROOT / "tools" / "luca" / "architecture_manifest.json"


class LucaWorldArchitectureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    def test_milestones_a_through_l_are_declared(self):
        self.assertEqual(
            list(self.manifest["milestones"]),
            list("ABCDEFGHIJKL"),
        )

    def test_deterministic_world_contract_is_versioned(self):
        world = self.manifest["world"]
        self.assertEqual(world["generator_version"], "luca-world-v1")
        self.assertEqual(world["chunk_size_m"], 128)
        self.assertEqual(world["subcell_size_m"], 32)
        self.assertEqual(
            world["generation_passes"],
            ["seed", "region", "biome", "terrain", "hydrology", "sites", "ecology", "objects"],
        )

    def test_streaming_rings_match_rebuilt_contract(self):
        streaming = self.manifest["streaming"]
        self.assertEqual(streaming["preload_grid"], 7)
        self.assertEqual(streaming["render_grid"], 5)
        self.assertEqual(streaming["physics_grid"], 3)
        self.assertEqual(streaming["hysteresis_cells"], 2)

    def test_persistence_is_delta_only(self):
        persistence = self.manifest["persistence"]
        self.assertTrue(persistence["immutable_chunk_descriptions"])
        self.assertTrue(persistence["delta_only"])
        self.assertEqual(
            persistence["delta_categories"],
            ["removed", "moved", "collected", "spawned"],
        )
        source = (LUCA / "LucaWorldPersistence.gd").read_text(encoding="utf-8")
        self.assertIn("record_removed", source)
        self.assertIn("record_moved", source)
        self.assertIn("record_collected", source)
        self.assertIn("record_spawned", source)

    def test_companion_has_six_state_brain_and_runtime_wiring(self):
        self.assertEqual(
            self.manifest["companion"]["states"],
            ["IDLE", "FOLLOW", "INVESTIGATE", "WAIT", "RECOVER", "REST"],
        )
        guide = (ROOT / "game_godot/scripts/actors/LucaGuide.gd").read_text(encoding="utf-8")
        self.assertIn("LucaCompanionBrain.gd", guide)
        self.assertIn("choose_state", guide)

    def test_mod_surface_is_explicitly_sandboxed(self):
        mods = self.manifest["mods"]
        self.assertEqual(
            mods["denied_permissions"],
            ["filesystem", "shell", "network", "native_code", "process"],
        )
        manager = (LUCA / "LucaModManager.gd").read_text(encoding="utf-8")
        self.assertIn('ends_with(".lucamod")', manager)
        self.assertIn("_unsafe_path", manager)
        vm = (LUCA / "LucaModVM.gd").read_text(encoding="utf-8")
        self.assertNotIn("OS.execute", vm)
        self.assertNotIn("HTTPRequest", vm)

    def test_bootstrap_contains_standalone_luca_root(self):
        scene = (ROOT / "game_godot/scenes/bootstrap/FirstPersonBootstrap.tscn").read_text(encoding="utf-8")
        self.assertIn("LucaWorldBootstrap.gd", scene)
        self.assertIn("LucaWorldRoot.gd", scene)
        self.assertIn('name="LucaWorldRoot"', scene)

    def test_lucabench_passes_exact_contract(self):
        proc = subprocess.run(
            [sys.executable, "tools/luca/run_lucabench.py"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("11/11 suites, 29 assertions", proc.stdout)

    def test_demolition_agent_passes_all_scenarios(self):
        proc = subprocess.run(
            [sys.executable, "tools/luca/demolition_agent.py"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("DEMOLITION PASS // 4/4 scenarios", proc.stdout)

    def test_release_identity_is_luca(self):
        project = (ROOT / "game_godot/project.godot").read_text(encoding="utf-8-sig")
        export = (ROOT / "game_godot/export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/name="Luca Dog World"', project)
        self.assertIn('config/version="0.11.0"', project)
        self.assertIn('package/unique_name="com.onekawaii.lucadogworld"', export)
        self.assertIn('version/name="0.11.0"', export)
        self.assertIn("luca_dog_world_mark.png", project)
        self.assertNotIn("wetberry", project.lower())

    def test_release_pipeline_uses_luca_artifact_names(self):
        build = (ROOT / "BUILD_NATIVE_PC.ps1").read_text(encoding="utf-8-sig")
        android = (ROOT / "tools/build_android_apk.py").read_text(encoding="utf-8")
        package = (ROOT / "tools/package_native_playtest.py").read_text(encoding="utf-8")
        receipt = (ROOT / "tools/write_release_receipt.py").read_text(encoding="utf-8")
        self.assertIn("Luca-Dog-World.exe", build)
        self.assertIn("Luca-Dog-World-v0.11.0-android.apk", android)
        self.assertIn("Luca-Dog-World-v0.11.0-windows.zip", package)
        self.assertIn("luca_dog_world_release_receipt_v1", receipt)


if __name__ == "__main__":
    unittest.main()
