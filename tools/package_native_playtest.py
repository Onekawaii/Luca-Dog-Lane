#!/usr/bin/env python3
"""Package Luca Dog World native artifacts and generate SHA-256 sidecars.

Creates:
- dist/Luca-Dog-World-v0.11.0-source.zip
- dist/Luca-Dog-World-v0.11.0-windows.zip
- dist/Luca-Dog-World-v0.11.0-android.apk (if exported)
- .sha256 checksum sidecars for all deliverables
"""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
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


def _release_source_files(root_dir: Path) -> list[str]:
    """Resolve release inputs from Git, or from the packaged manifest offline."""
    git_result = subprocess.run(
        ["git", "ls-files"],
        cwd=root_dir,
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if git_result.returncode == 0 and git_result.stdout.strip():
        return git_result.stdout.splitlines()

    manifest = root_dir / "BUILD_MANIFEST.sha256"
    if not manifest.is_file():
        raise RuntimeError(
            "Cannot determine release source files: no Git worktree and no BUILD_MANIFEST.sha256"
        )

    files: list[str] = []
    for line in manifest.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split(maxsplit=1)
        if len(parts) != 2:
            continue
        rel = parts[1].lstrip("*").replace("\\", "/")
        if rel:
            files.append(rel)
    files.append("BUILD_MANIFEST.sha256")
    return files


def package_source_zip(dest_zip: Path, root_dir: Path | None = None) -> None:
    print(f"Creating source archive: {dest_zip.name}...")
    root_dir = Path.cwd() if root_dir is None else Path(root_dir)
    exclude_dirs = {
        ".git",
        ".vs",
        ".godot",
        "__pycache__",
        "node_modules",
        "dist",
        "build",
        "tmp",
        "build_artifacts",
        "outputs",
        "debug_artifacts",
        ".pytest_cache",
    }
    exclude_exts = {".pyc", ".tmp", ".log", ".zip", ".apk", ".aab", ".exe", ".pck"}

    tracked = _release_source_files(root_dir)

    with zipfile.ZipFile(dest_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in sorted(set(tracked)):
            file_path = root_dir / rel
            if not file_path.is_file():
                continue
            if any(part in exclude_dirs for part in file_path.parts):
                continue
            if file_path.suffix.lower() in exclude_exts:
                continue
            z.write(file_path, Path(rel).as_posix())

    write_sha256_sidecar(dest_zip)


def package_windows_zip(windows_dir: Path, dest_zip: Path) -> None:
    exe_path = windows_dir / "Luca-Dog-World.exe"
    if not exe_path.exists():
        raise RuntimeError(f"Windows executable not found at {exe_path}")

    print(f"Creating Windows playtest archive: {dest_zip.name}...")
    with zipfile.ZipFile(dest_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(windows_dir):
            for file in files:
                fp = Path(root) / file
                arcname = fp.relative_to(windows_dir.parent).as_posix()
                z.write(fp, arcname)

    write_sha256_sidecar(dest_zip)


def package_android(android_apk: Path) -> None:
    if not android_apk.exists():
        raise RuntimeError(f"Android APK not found at {android_apk}")
    print(f"Recording Android playtest APK: {android_apk.name}...")
    write_sha256_sidecar(android_apk)


def main() -> int:
    dist_dir = Path("dist")
    dist_dir.mkdir(parents=True, exist_ok=True)

    print("============================================================")
    print("PACKAGING LUCA DOG WORLD v0.11.0 NATIVE ARTIFACTS")
    print("============================================================\n")

    # 1. Source zip
    source_zip = dist_dir / "Luca-Dog-World-v0.11.0-source.zip"
    package_source_zip(source_zip)

    # 2. Windows playtest zip
    windows_zip = dist_dir / "Luca-Dog-World-v0.11.0-windows.zip"
    package_windows_zip(dist_dir / "windows", windows_zip)

    # 3. Android release
    android_apk = dist_dir / "Luca-Dog-World-v0.11.0-android.apk"
    if not android_apk.exists():
        android_apk = dist_dir / "android" / "Luca-Dog-World-v0.11.0-android.apk"
    package_android(android_apk)

    print("\n[OK] Packaging completed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
