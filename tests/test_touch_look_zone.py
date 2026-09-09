"""Unit tests verifying the TouchLookZone implementation and mobile look contract."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class TestTouchLookZoneContract(unittest.TestCase):
    def setUp(self):
        self.look_gd = (ROOT / "game_godot/scripts/fps/TouchLookZone.gd").read_text(encoding="utf-8")
        self.hud_gd = (ROOT / "game_godot/scripts/fps/FirstPersonHUD.gd").read_text(encoding="utf-8")
        self.hud_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonHUD.tscn").read_text(encoding="utf-8")

    def test_global_input_handling_and_reset(self):
        """Verify TouchLookZone uses _input for global tracking and provides reset_touch."""
        self.assertIn("func _input(event: InputEvent) -> void:", self.look_gd)
        self.assertIn("func reset_touch() -> void:", self.look_gd)
        self.assertIn("active_touch_index = -1", self.look_gd)

    def test_lifecycle_notifications_clear_touch(self):
        """Verify visibility, disable, and focus notifications reset active touch index."""
        self.assertIn("NOTIFICATION_VISIBILITY_CHANGED", self.look_gd)
        self.assertIn("NOTIFICATION_DISABLED", self.look_gd)
        self.assertIn("NOTIFICATION_WM_WINDOW_FOCUS_OUT", self.look_gd)

    def test_excluded_button_checks(self):
        """Verify InteractButton, PDAButton, and modal panels are excluded from triggering look."""
        self.assertIn("_is_excluded_position", self.look_gd)
        self.assertIn("InteractButton", self.look_gd)
        self.assertIn("PDAButton", self.look_gd)
        self.assertIn("PDAPanel", self.look_gd)
        self.assertIn("DialoguePanel", self.look_gd)

    def test_hud_disabling_resets_touch_look(self):
        """Verify FirstPersonHUD._set_mobile_gameplay_controls_enabled resets TouchLookZone."""
        self.assertIn("look_zone.reset_touch()", self.hud_gd)

    def test_exclusive_touch_ownership_check(self):
        """Verify TouchLookZone checks active_touch_index == -1 on press before claiming a finger."""
        self.assertIn("if active_touch_index == -1:", self.look_gd)


class TestVisualPassModularArchitectureContract(unittest.TestCase):
    def test_staged_assets_and_provenance_exist(self):
        staging_dir = ROOT / "game_godot/assets/staging/borrowed_visuals"
        self.assertTrue(staging_dir.exists(), "Staging directory exists")
        self.assertTrue((staging_dir / "PROVENANCE.json").exists(), "PROVENANCE.json exists in staging")
        self.assertTrue((staging_dir / "README.md").exists(), "README.md exists in staging")
        self.assertTrue((staging_dir / "AG_VISUAL_PASS_TASK.md").exists(), "AG_VISUAL_PASS_TASK.md exists in staging")
        self.assertTrue((staging_dir / "originals").exists(), "Originals folder exists")
        self.assertTrue((staging_dir / "derived").exists(), "Derived folder exists")

    def test_decal_and_tiled_assets_exist(self):
        fps_mats = ROOT / "game_godot/assets/fps/materials"
        fps_props = ROOT / "game_godot/assets/fps/props"
        fps_actors = ROOT / "game_godot/assets/fps/actors"

        self.assertTrue((fps_props / "wetberry_front_decal.png").exists(), "Wetberry front decal exists")
        self.assertTrue((fps_actors / "keith_name_badge.png").exists(), "Keith name badge decal exists")
        self.assertTrue((fps_props / "fridge_property_decal.png").exists(), "Fridge property decal exists")
        self.assertTrue((fps_props / "fridge_maintenance_decal.png").exists(), "Fridge maintenance decal exists")
        self.assertTrue((fps_props / "hidden_anomaly_plate_256.png").exists(), "Hidden anomaly plate exists")
        self.assertTrue((fps_mats / "breakroom_floor_tile.png").exists(), "Breakroom floor tile exists")
        self.assertTrue((fps_mats / "pda_arkheo_watermark.png").exists(), "PDA watermark texture exists")
        self.assertTrue((fps_mats / "quantum_glyph_icon.png").exists(), "Quantum glyph icon exists")

    def test_breakroom_modular_geometry_hierarchy(self):
        breakroom_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonBreakroom.tscn").read_text(encoding="utf-8")
        
        # Wetberry assembly
        self.assertIn("CartonBody", breakroom_tscn)
        self.assertIn("CartonGable", breakroom_tscn)
        self.assertIn("TopSeam", breakroom_tscn)
        self.assertIn("FrontLabelDecal", breakroom_tscn)

        # Keith assembly
        self.assertIn("Torso", breakroom_tscn)
        self.assertIn("HeadHood", breakroom_tscn)
        self.assertIn("FaceVisor", breakroom_tscn)
        self.assertIn("BadgeDecal", breakroom_tscn)
        self.assertIn("LeftUpperArm", breakroom_tscn)
        self.assertIn("RightUpperArm", breakroom_tscn)
        self.assertIn("LeftLeg", breakroom_tscn)
        self.assertIn("RightLeg", breakroom_tscn)
        self.assertIn("LeftBoot", breakroom_tscn)
        self.assertIn("RightBoot", breakroom_tscn)
        self.assertIn("MopHandle", breakroom_tscn)

        # Fridge assembly
        self.assertIn("CabinetBody", breakroom_tscn)
        self.assertIn("FreezerDoor", breakroom_tscn)
        self.assertIn("FridgeDoor", breakroom_tscn)
        self.assertIn("FreezerHandle", breakroom_tscn)
        self.assertIn("FridgeHandle", breakroom_tscn)
        self.assertIn("PropertyDecal", breakroom_tscn)
        self.assertIn("MaintenanceDecal", breakroom_tscn)

        # Coffee maker assembly
        self.assertIn("BasePlate", breakroom_tscn)
        self.assertIn("WarmPlate", breakroom_tscn)
        self.assertIn("BackTower", breakroom_tscn)
        self.assertIn("BrewBasket", breakroom_tscn)
        self.assertIn("CarafeGlass", breakroom_tscn)
        self.assertIn("CarafeHandle", breakroom_tscn)
        self.assertIn("ControlPanel", breakroom_tscn)
        self.assertIn("StatusLED", breakroom_tscn)

        # Central table assembly
        self.assertIn("TableTop", breakroom_tscn)
        self.assertIn("TableEdge", breakroom_tscn)
        self.assertIn("Leg_FL", breakroom_tscn)
        self.assertIn("Leg_FR", breakroom_tscn)
        self.assertIn("Leg_BL", breakroom_tscn)
        self.assertIn("Leg_BR", breakroom_tscn)
        self.assertIn("HiddenAnomalyPlate", breakroom_tscn)

        # Ceiling fixtures and environmental details
        self.assertIn("CeilingFixtures", breakroom_tscn)
        self.assertIn("TrashCan", breakroom_tscn)
        self.assertIn("Counter", breakroom_tscn)

    def test_pda_hud_has_watermark(self):
        hud_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonHUD.tscn").read_text(encoding="utf-8")
        self.assertIn("pda_arkheo_watermark.png", hud_tscn)
        self.assertIn("Watermark", hud_tscn)


class TestBreakroomInteractionPassContract(unittest.TestCase):
    def setUp(self):
        self.breakroom_gd = (ROOT / "game_godot/scripts/fps/FirstPersonBreakroom.gd").read_text(encoding="utf-8")
        self.breakroom_tscn = (ROOT / "game_godot/scenes/fps/FirstPersonBreakroom.tscn").read_text(encoding="utf-8")
        self.inspect_gd = (ROOT / "game_godot/scripts/fps/FirstPersonInspectable.gd").read_text(encoding="utf-8")
        self.hold_gd = (ROOT / "game_godot/scripts/fps/FirstPersonHoldable.gd").read_text(encoding="utf-8")
        self.keith_gd = (ROOT / "game_godot/scripts/fps/KeithAmbientWorker.gd").read_text(encoding="utf-8")

    def test_inspect_system_contract(self):
        """Verify inspect zoom and framing logic is present."""
        self.assertIn("_start_inspect", self.breakroom_gd)
        self.assertIn("exit_inspect", self.breakroom_gd)
        self.assertIn("compute_inspect_transform", self.inspect_gd)
        self.assertIn("first_person_inspect_started", self.breakroom_gd)
        self.assertIn("first_person_inspect_ended", self.breakroom_gd)

    def test_hold_and_place_system_contract(self):
        """Verify Wetberry holdable and surface placement contracts."""
        self.assertIn("pick_up_wetberry", self.breakroom_gd)
        self.assertIn("place_held_object", self.breakroom_gd)
        self.assertIn("HeldSlot", self.breakroom_tscn)
        self.assertIn("HeldWetberryMesh", self.breakroom_gd)
        self.assertIn("can_pick_up", self.hold_gd)

    def test_coffee_maker_interaction_contract(self):
        """Verify coffee maker toggle, LED, and steam contracts."""
        self.assertIn("toggle_coffee_maker", self.breakroom_gd)
        self.assertIn("is_coffee_on", self.breakroom_gd)
        self.assertIn("BrewSteam", self.breakroom_tscn)
        self.assertIn("StatusLED", self.breakroom_tscn)

    def test_fridge_hinge_and_ooze_contract(self):
        """Verify fridge hinge door pivots, contaminated ooze decal, and fly swarm."""
        self.assertIn("toggle_fridge_door", self.breakroom_gd)
        self.assertIn("FridgeDoorPivot", self.breakroom_tscn)
        self.assertIn("FreezerDoorPivot", self.breakroom_tscn)
        self.assertIn("ContaminatedOoze", self.breakroom_tscn)
        self.assertIn("FlySwarm", self.breakroom_tscn)
        self.assertTrue((ROOT / "game_godot/assets/fps/props/fridge_ooze_decal.png").exists())

    def test_keith_ambient_worker_contract(self):
        """Verify Keith deterministic cleaning waypoints and pause/resume logic."""
        self.assertIn("KeithAmbientWorker", self.breakroom_gd)
        self.assertIn("waypoints", self.keith_gd)
        self.assertIn("pause_cleaning", self.keith_gd)
        self.assertIn("resume_cleaning", self.keith_gd)
        self.assertIn("_animate_mop", self.keith_gd)


if __name__ == "__main__":
    unittest.main()
