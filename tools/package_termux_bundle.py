#!/usr/bin/env python3
"""Compute BUILD_MANIFEST.sha256 and package the v0.7.0 Termux playtest bundle with SHA-256 sidecar."""

from __future__ import annotations

import hashlib
import os
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def compute_manifest() -> list[str]:
    tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT).decode("utf-8").splitlines()
    untracked = subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT
    ).decode("utf-8").splitlines()
    all_files = sorted(set(tracked + untracked))

    lines = []
    for rel in all_files:
        p = ROOT / rel
        if p.is_file() and rel != "BUILD_MANIFEST.sha256" and not rel.startswith("outputs/"):
            h = hashlib.sha256(p.read_bytes()).hexdigest()
            posix_path = rel.replace("\\", "/")
            lines.append(f"{h}  {posix_path}\n")

    manifest_path = ROOT / "BUILD_MANIFEST.sha256"
    with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(lines)
    print(f"Wrote {len(lines)} file hashes to {manifest_path}")
    return all_files


def package_bundle(files: list[str]) -> Path:
    out_dir = ROOT / "outputs"
    out_dir.mkdir(exist_ok=True)
    bundle_name = "Hive-Lattice-v0.7.0-visual-slice"
    zip_path = out_dir / f"{bundle_name}.zip"
    sha_path = out_dir / f"{bundle_name}.zip.sha256"

    # Add BUILD_MANIFEST.sha256 to files to pack
    files_to_pack = sorted(set(files + ["BUILD_MANIFEST.sha256"]))

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for rel in files_to_pack:
            p = ROOT / rel
            if p.is_file() and not rel.startswith("outputs/"):
                arcname = f"{bundle_name}/{rel.replace(os.sep, '/')}"
                zf.write(p, arcname)

    zip_hash = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    with open(sha_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"{zip_hash}  {zip_path.name}\n")

    print(f"Packaged bundle: {zip_path} ({zip_path.stat().st_size} bytes)")
    print(f"SHA-256 sidecar: {sha_path} -> {zip_hash}")
    return zip_path


if __name__ == "__main__":
    files = compute_manifest()
    package_bundle(files)
