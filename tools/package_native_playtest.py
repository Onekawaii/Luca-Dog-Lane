#!/usr/bin/env python3
"""Package Hive-Lattice Native Playtest artifacts and generate SHA-256 sidecars.

Creates:
- dist/Hive-Lattice-native-playtest-source.zip
- dist/Hive-Lattice-native-windows-playtest.zip
- dist/Hive-Lattice-native-android-playtest.apk (if exported)
- .sha256 checksum sidecars for all deliverables
"""

from __future__ import annotations

import hashlib
import os
import shutil
import sys
import zipfile
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def write_sha256_sidecar(target_file: Path) -> Path:
    checksum = sha256_file(target_file)
    sidecar_path = target_file.with_name(target_file.name + ".sha256")
    sidecar_path.write_text(f"{checksum} *{target_file.name}\n", encoding="utf-8")
    print(f"  [SHA256] {sidecar_path.name}: {checksum}")
    return sidecar_path


def package_source_zip(dest_zip: Path) -> None:
    print(f"Creating source archive: {dest_zip.name}...")
    root_dir = Path(".")
    exclude_dirs = {
        ".git",
        ".vs",
        ".godot",
        "__pycache__",
        "node_modules",
        "dist",
        "build",
        "tmp",
    }
    exclude_exts = {".pyc", ".tmp", ".log"}

    with zipfile.ZipFile(dest_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk(root_dir):
            dirs[:] = [d for d in dirs if d not in exclude_dirs]
            rel_root = Path(root)
            for file in files:
                file_path = rel_root / file
                if file_path.suffix in exclude_exts:
                    continue
                if file_path.name.endswith(".sha256") and "dist" in file_path.parts:
                    continue
                z.write(file_path, file_path.as_posix())

    write_sha256_sidecar(dest_zip)


def package_windows_zip(windows_dir: Path, dest_zip: Path) -> None:
    exe_path = windows_dir / "Hive-Lattice.exe"
    if not exe_path.exists():
        print(f"[WARN] Windows executable not found at {exe_path}. Skipping windows zip.")
        return

    print(f"Creating Windows playtest archive: {dest_zip.name}...")
    with zipfile.ZipFile(dest_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(windows_dir):
            for file in files:
                fp = Path(root) / file
                arcname = fp.relative_to(windows_dir.parent).as_posix()
                z.write(fp, arcname)

    write_sha256_sidecar(dest_zip)


def package_android(android_apk: Path) -> None:
    if android_apk.exists():
        print(f"Recording Android playtest APK: {android_apk.name}...")
        write_sha256_sidecar(android_apk)


def main() -> int:
    dist_dir = Path("dist")
    dist_dir.mkdir(parents=True, exist_ok=True)

    print("============================================================")
    print("PACKAGING HIVE-LATTICE NATIVE PLAYTEST ARTIFACTS")
    print("============================================================\n")

    # 1. Source zip
    source_zip = dist_dir / "Hive-Lattice-native-playtest-source.zip"
    package_source_zip(source_zip)

    # 2. Windows playtest zip
    windows_zip = dist_dir / "Hive-Lattice-native-windows-playtest.zip"
    package_windows_zip(dist_dir / "windows", windows_zip)

    # 3. Android playtest
    android_apk = dist_dir / "Hive-Lattice-native-android-playtest.apk"
    if not android_apk.exists():
        android_apk = dist_dir / "android" / "Hive-Lattice-native-android-playtest.apk"
    if not android_apk.exists():
        android_apk = dist_dir / "android" / "Hive-Lattice-native-playtest.apk"
    if not android_apk.exists():
        android_apk = dist_dir / "Hive-Lattice-native-playtest.apk"
    package_android(android_apk)

    print("\n[OK] Packaging completed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
