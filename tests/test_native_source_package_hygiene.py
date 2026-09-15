"""Regression coverage for native source-package hygiene."""
from __future__ import annotations

import os
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.package_native_playtest import package_source_zip

ROOT = Path(__file__).resolve().parents[1]


class TestNativeSourcePackageHygiene(unittest.TestCase):
    def test_source_archive_excludes_generated_and_binary_artifacts(self):
        old_cwd = Path.cwd()
        try:
            os.chdir(ROOT)
            with tempfile.TemporaryDirectory() as tmp:
                archive = Path(tmp) / "source.zip"
                package_source_zip(archive)
                with zipfile.ZipFile(archive, "r") as zf:
                    names = zf.namelist()
        finally:
            os.chdir(old_cwd)

        banned_prefixes = (
            "build_artifacts/",
            "outputs/",
            "debug_artifacts/",
            ".pytest_cache/",
            "dist/",
            "build/",
            "tmp/",
        )
        banned_suffixes = (".zip", ".apk", ".aab", ".exe", ".pck")

        self.assertFalse(
            any(name.startswith(banned_prefixes) for name in names),
            "source archive contains generated/output directories",
        )
        self.assertFalse(
            any(name.lower().endswith(banned_suffixes) for name in names),
            "source archive contains nested distributable binaries",
        )


if __name__ == "__main__":
    unittest.main()
