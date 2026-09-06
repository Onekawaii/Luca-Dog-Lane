#!/usr/bin/env python3
"""One-command acceptance gate for v0.6.0-lattice-alive."""
from __future__ import annotations

import importlib
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def run(cmd: list[str]) -> None:
    print("$", " ".join(cmd))
    cp = subprocess.run(cmd, cwd=ROOT)
    if cp.returncode:
        raise SystemExit(cp.returncode)


def run_non_flask_suite() -> int:
    excluded = {"test_web_app.py", "test_act4_pwa_smoke.py"}
    loader = unittest.defaultTestLoader
    suite = unittest.TestSuite()
    for path in sorted((ROOT / "tests").glob("test_*.py")):
        if path.name in excluded:
            continue
        module = importlib.import_module("tests." + path.stem)
        suite.addTests(loader.loadTestsFromModule(module))
    count = suite.countTestCases()
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    print(f"Non-Flask suite: {result.testsRun}/{count} executed; skipped={len(result.skipped)}")
    if not result.wasSuccessful():
        raise SystemExit(1)
    return count


def main() -> int:
    run([sys.executable, "-m", "tools.content_lint"])
    run([sys.executable, "-m", "tools.validate_campaign_module"])
    run([sys.executable, "-m", "tools.validate_visual_assets"])
    run([sys.executable, "-m", "hive_lattice.cli", "validate", "strawberry_omen"])
    run([sys.executable, "tests/test_act3_smoke.py"])
    run([sys.executable, "tests/test_act5_smoke.py"])
    run([sys.executable, "-m", "unittest", "tests.test_lattice_alive_runtime", "tests.test_lattice_alive_contract"])
    run([sys.executable, "-m", "unittest", "tests.test_mobile_playtest_release", "tests.test_mobile_save_roundtrip"])

    try:
        import flask  # noqa: F401
    except ImportError:
        print("Flask unavailable: executing every non-Flask test and reporting the web gap explicitly.")
        count = run_non_flask_suite()
        print(f"LATTICE ALIVE GATE PASS — {count} non-Flask cases executed; Flask web cases pending installed requirements.")
        return 0

    run([sys.executable, "-m", "unittest", "discover", "-s", "tests"])
    print("LATTICE ALIVE FULL SUITE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
