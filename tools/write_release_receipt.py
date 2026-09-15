#!/usr/bin/env python3
"""Write an exact-state release receipt for the native Hive-Lattice playtest."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
RECEIPT = DIST / "RELEASE_RECEIPT_v0.9.1.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def artifact_record(path: Path) -> dict[str, object]:
    if not path.is_file():
        raise FileNotFoundError(path)
    record: dict[str, object] = {
        "path": str(path.relative_to(ROOT)).replace("\\", "/"),
        "size_bytes": path.stat().st_size,
        "sha256": sha256(path),
    }
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path, "r") as archive:
            bad = archive.testzip()
            if bad is not None:
                raise RuntimeError(f"Corrupt ZIP member in {path.name}: {bad}")
            record["zip_entries"] = len(archive.namelist())
            record["zip_integrity"] = "PASS"
    return record


def find_apksigner() -> Path | None:
    base = Path.home() / "AppData" / "Local" / "Android" / "Sdk" / "build-tools"
    if not base.exists():
        return None
    candidates = sorted(base.glob("*/apksigner.bat"), reverse=True)
    return candidates[0] if candidates else None


def verify_apk(apk: Path) -> str:
    signer = find_apksigner()
    if signer is None:
        raise RuntimeError("apksigner not found; cannot qualify Android signature")
    env = os.environ.copy()
    java_home = Path.home() / ".jdk17"
    if java_home.exists():
        env["JAVA_HOME"] = str(java_home)
        env["PATH"] = str(java_home / "bin") + os.pathsep + env.get("PATH", "")
    result = subprocess.run(
        [str(signer), "verify", "--verbose", str(apk)],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError("APK signature verification failed")
    return "PASS"


def tracked_clean() -> bool:
    unstaged = subprocess.run(["git", "diff", "--quiet"], cwd=ROOT).returncode == 0
    staged = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode == 0
    return unstaged and staged


def main() -> int:
    artifacts = {
        "windows_exe": artifact_record(DIST / "windows" / "Hive-Lattice.exe"),
        "windows_zip": artifact_record(DIST / "Hive-Lattice-native-windows-playtest.zip"),
        "android_apk": artifact_record(DIST / "Hive-Lattice-native-android-playtest.apk"),
        "source_zip": artifact_record(DIST / "Hive-Lattice-native-playtest-source.zip"),
    }
    apk_path = DIST / "Hive-Lattice-native-android-playtest.apk"
    artifacts["android_apk"]["signature_verification"] = verify_apk(apk_path)

    receipt = {
        "schema": "hive_lattice_release_receipt_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "version": "0.9.1",
        "branch": git("branch", "--show-current"),
        "head": git("rev-parse", "HEAD"),
        "tracked_worktree_clean": tracked_clean(),
        "artifacts": artifacts,
    }
    if not receipt["tracked_worktree_clean"]:
        raise RuntimeError("Tracked worktree is dirty; release receipt would not identify an exact source state")

    RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    receipt_sha = sha256(RECEIPT)
    sidecar = RECEIPT.with_name(RECEIPT.name + ".sha256")
    sidecar.write_text(f"{receipt_sha} *{RECEIPT.name}\n", encoding="utf-8")
    print(f"[RECEIPT] {RECEIPT.relative_to(ROOT)}")
    print(f"[HEAD] {receipt['head']}")
    print(f"[SHA256] {receipt_sha}")
    for name, record in artifacts.items():
        print(f"[ARTIFACT] {name}: {record['sha256']} ({record['size_bytes']} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
