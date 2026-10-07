from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AndroidReleaseSecurityTests(unittest.TestCase):
    def test_release_pipeline_never_exports_android_debug(self):
        build = (ROOT / "BUILD_RELEASE.ps1").read_text(encoding="utf-8")
        helper = (ROOT / "tools" / "export_android_release.ps1").read_text(encoding="utf-8")
        self.assertNotIn('--export-debug "Android"', build)
        self.assertIn("export_android_release.ps1", build)
        self.assertIn('--export-release "Android"', helper)

    def test_release_helper_enforces_security_contract(self):
        helper = (ROOT / "tools" / "export_android_release.ps1").read_text(encoding="utf-8")
        self.assertIn("application-debuggable", helper)
        self.assertIn("ANDROID_RELEASE_DEBUGGABLE=false", helper)
        self.assertIn("ANDROID_RELEASE_PERMISSIONS=0", helper)
        self.assertIn("targetSdkVersion:'36'", helper)
        self.assertIn(".luca_signing", helper)

if __name__ == "__main__":
    unittest.main()
