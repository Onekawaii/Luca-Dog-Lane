from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PLAYER = ROOT / "game_godot" / "scripts" / "fps" / "FirstPersonPlayer.gd"
HUD = ROOT / "game_godot" / "scripts" / "fps" / "FirstPersonHUD.gd"
HUD_SCENE = ROOT / "game_godot" / "scenes" / "fps" / "FirstPersonHUD.tscn"
EVENT_BUS = ROOT / "game_godot" / "scripts" / "runtime" / "EventBus.gd"


class FreeFlyModeContractTests(unittest.TestCase):
    def test_player_has_true_noclip_path(self):
        text = PLAYER.read_text(encoding="utf-8")
        self.assertIn("free_fly_enabled", text)
        self.assertIn("collision_layer = 0", text)
        self.assertIn("collision_mask = 0", text)
        self.assertIn("global_position += (horizontal + Vector3.UP * vertical)", text)
        self.assertIn("PhysicsRayQueryParameters3D", text)
        self.assertIn("first_person_fly_state_changed.emit(true)", text)
        self.assertIn("first_person_fly_state_changed.emit(false)", text)

    def test_mobile_hud_exposes_fly_and_altitude_controls(self):
        hud = HUD.read_text(encoding="utf-8")
        scene = HUD_SCENE.read_text(encoding="utf-8")
        self.assertIn("first_person_fly_toggle_requested.emit()", hud)
        self.assertIn("first_person_fly_vertical_input.emit(1.0)", hud)
        self.assertIn("first_person_fly_vertical_input.emit(-1.0)", hud)
        self.assertIn('node name="FlyButton"', scene)
        self.assertIn('node name="FlyUpButton"', scene)
        self.assertIn('node name="FlyDownButton"', scene)

    def test_event_bus_keeps_flight_runtime_only(self):
        text = EVENT_BUS.read_text(encoding="utf-8")
        self.assertIn("signal first_person_fly_toggle_requested()", text)
        self.assertIn("signal first_person_fly_vertical_input(value: float)", text)
        self.assertIn("signal first_person_fly_state_changed(enabled: bool)", text)


if __name__ == "__main__":
    unittest.main()
