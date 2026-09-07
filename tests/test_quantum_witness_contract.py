"""Tests for the Quantum Witness System and Observation-Dependent State Architecture."""

import os
import subprocess
import unittest
from pathlib import Path

from tools.verify_native_contract import find_godot_binary


class TestQuantumWitnessContract(unittest.TestCase):
    """Test suite verifying generic quantum architecture and headless Godot acceptance tests."""

    @classmethod
    def setUpClass(cls):
        cls.godot_bin = find_godot_binary()

    def test_quantum_scripts_exist(self):
        """Verify all generic quantum subsystem files exist and are decoupled."""
        root = Path("game_godot/scripts/quantum")
        required_scripts = [
            "QuantumEntity.gd",
            "QuantumWitnessSystem.gd",
            "QuantumStateAnchor.gd",
            "QuantumEntanglement.gd",
        ]
        for script in required_scripts:
            path = root / script
            self.assertTrue(path.exists(), f"Missing quantum script: {path}")

    def test_kevin_quantum_presence_script(self):
        """Verify KevinActor.gd is integrated with QuantumEntity."""
        path = Path("game_godot/scripts/actors/KevinActor.gd")
        self.assertTrue(path.exists())
        content = path.read_text(encoding="utf-8")
        self.assertIn("QuantumEntityClass", content)
        self.assertIn("QuantumStateAnchorClass", content)
        self.assertIn("kevin_anchor_a", content)
        self.assertIn("kevin_anchor_b", content)
        self.assertIn("kevin_anchor_c", content)
        self.assertIn("kevin_anchor_d", content)

    def test_entanglement_in_breakroom(self):
        """Verify BreakroomScene integrates QuantumWitnessSystem and Coffee Machine Entanglement."""
        path = Path("game_godot/scripts/rooms/BreakroomScene.gd")
        self.assertTrue(path.exists())
        content = path.read_text(encoding="utf-8")
        self.assertIn("QuantumWitnessSystemClass", content)
        self.assertIn("QuantumEntanglementClass", content)
        self.assertIn("set_entangled_state", content)

    def test_godot_headless_quantum_suite(self):
        """Execute the headless Godot quantum system test suite."""
        if not self.godot_bin:
            self.skipTest("Godot binary not found on system")

        cmd = [
            str(self.godot_bin),
            "--headless",
            "--path",
            "game_godot",
            "--script",
            "res://tests/test_quantum_system.gd",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        print(res.stdout)
        self.assertEqual(
            res.returncode,
            0,
            f"test_quantum_system.gd failed with code {res.returncode}:\n{res.stderr}\n{res.stdout}",
        )
        self.assertIn("[ALL QUANTUM WITNESS TESTS PASSED]", res.stdout)

    def test_godot_headless_full_acceptance_suite(self):
        """Execute the full native Godot headless acceptance suite with quantum integration."""
        if not self.godot_bin:
            self.skipTest("Godot binary not found on system")

        cmd = [
            str(self.godot_bin),
            "--headless",
            "--path",
            "game_godot",
            "--script",
            "res://tests/run_acceptance.gd",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(
            res.returncode,
            0,
            f"run_acceptance.gd failed with code {res.returncode}:\n{res.stderr}\n{res.stdout}",
        )
        self.assertIn("[ALL NATIVE ACCEPTANCE TESTS PASSED]", res.stdout)


if __name__ == "__main__":
    unittest.main()
