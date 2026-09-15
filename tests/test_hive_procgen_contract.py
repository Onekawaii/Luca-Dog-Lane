import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "game_godot/scripts/procgen/HiveProcGenEngine.gd"
RUNTIME = ROOT / "game_godot/scripts/procgen/HiveProcGenRuntime.gd"
RENDERER = ROOT / "game_godot/scripts/procgen/HiveProcGenChunkRenderer.gd"
CATALOG = ROOT / "game_godot/data/procgen/memory_catalog.json"
BOOTSTRAP = ROOT / "game_godot/scenes/bootstrap/FirstPersonBootstrap.tscn"
EVENT_BUS = ROOT / "game_godot/scripts/runtime/EventBus.gd"


class HiveProcGenContractTests(unittest.TestCase):
    def test_procgen_sources_and_runtime_wiring_exist(self):
        for path in (ENGINE, RUNTIME, RENDERER, CATALOG):
            self.assertTrue(path.exists(), path)
        bootstrap = BOOTSTRAP.read_text(encoding="utf-8")
        self.assertIn("HiveProcGenRuntime.gd", bootstrap)
        self.assertIn('name="HiveProcGenRuntime"', bootstrap)
        bus = EVENT_BUS.read_text(encoding="utf-8")
        self.assertIn("signal procgen_world_ready", bus)
        self.assertIn("signal procgen_streaming_changed", bus)

    def test_chunk_renderer_materializes_bounded_walkable_cells(self):
        source = RENDERER.read_text(encoding="utf-8")
        for token in (
            "class_name HiveProcGenChunkRenderer",
            "_build_region_one_slice",
            "_open_breakroom_portal",
            "_load_cell",
            "_unload_cell",
            "StaticBody3D",
            "NavigationRegion3D",
            'persistent["cell_state"]',
        ):
            self.assertIn(token, source)
        runtime = RUNTIME.read_text(encoding="utf-8")
        self.assertIn("HiveProcGenChunkRenderer.gd", runtime)
        self.assertIn("chunk_renderer.configure", runtime)

    def test_engine_contains_layered_generation_contract(self):
        source = ENGINE.read_text(encoding="utf-8")
        required = (
            "_generate_regions", "_connect_points", "_generate_sites",
            "_generate_room_graphs", "_generate_scatter",
            "_build_streaming_index", "_build_director_state",
            "_memory_for_site", "_build_receipt", "FastNoiseLite",
        )
        for token in required:
            self.assertIn(token, source)

    def test_memory_catalog_is_derived_metadata_only(self):
        data = json.loads(CATALOG.read_text(encoding="utf-8"))
        self.assertEqual(data["schema"], "hive_memory_catalog_v1")
        self.assertEqual(data["privacy"], "derived-metadata-only")
        for memory in data["memories"]:
            self.assertIn("id", memory)
            self.assertIn("tags", memory)
            serialized = json.dumps(memory).lower()
            self.assertNotIn("gps", serialized)
            self.assertNotIn("exif", serialized)
            self.assertNotIn("c:\\", serialized)
            self.assertNotIn("/users/", serialized)


if __name__ == "__main__":
    unittest.main()
