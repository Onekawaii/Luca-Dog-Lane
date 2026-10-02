import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "BUILD_NATIVE_PC.ps1"


class NativeBuildScriptContractTests(unittest.TestCase):
    def test_godot_stderr_warnings_do_not_abort_successful_native_commands(self):
        source = BUILD.read_text(encoding="utf-8-sig")
        self.assertIn("function Invoke-GodotSafe", source)
        self.assertIn("Start-Process -FilePath $GodotBin", source)
        self.assertIn("-Wait -PassThru", source)
        godot_calls = [
            line for line in source.splitlines()
            if "Invoke-GodotSafe @(" in line
        ]
        self.assertGreaterEqual(len(godot_calls), 4)
        self.assertIn("return $proc.ExitCode", source)

    def test_missing_exports_remain_fatal(self):
        source = BUILD.read_text(encoding="utf-8-sig")
        self.assertIn("Windows Desktop export failed after clean retry", source)
        self.assertIn("Android APK build failed. Native suite is not complete.", source)
        self.assertIn("Release receipt generation failed.", source)


if __name__ == "__main__":
    unittest.main()
