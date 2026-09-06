#!/usr/bin/env python3
"""Build and sign native Android APK for Hive-Lattice using Godot export templates and Android SDK tools."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


def find_file(start_dir: Path, name: str) -> Path | None:
    if not start_dir.exists():
        return None
    for root, _, files in os.walk(start_dir):
        if name in files:
            return Path(root) / name
    return None


def main() -> int:
    # Ensure JAVA_HOME and PATH are set for apksigner
    jdk_dir = Path.home() / ".jdk17"
    if jdk_dir.exists():
        os.environ["JAVA_HOME"] = str(jdk_dir)
        os.environ["PATH"] = str(jdk_dir / "bin") + os.pathsep + os.environ.get("PATH", "")

    dist_android = Path("dist/android")
    dist_android.mkdir(parents=True, exist_ok=True)
    target_apk = dist_android / "Hive-Lattice-native-playtest.apk"

    print("============================================================")
    print("BUILDING NATIVE ANDROID APK")
    print("============================================================\n")

    # 1. Export Godot PCK
    home_bin = Path.home() / ".godot_bin"
    godot_exe = home_bin / "Godot_v4.3-stable_win64_console.exe"
    if not godot_exe.exists():
        godot_exe = Path(shutil.which("godot") or "godot")

    pck_path = dist_android / "game.pck"
    print(f"Exporting PCK to {pck_path}...")
    cmd = [
        str(godot_exe),
        "--headless",
        "--path",
        "game_godot",
        "--export-pack",
        "Windows Desktop",
        str(pck_path.resolve()),
    ]
    res = subprocess.run(cmd)
    if res.returncode != 0 or not pck_path.exists():
        print("[ERROR] Failed to export Godot PCK pack!", file=sys.stderr)
        return 1

    # 2. Locate Android template APK
    appdata = os.environ.get("APPDATA", os.path.expanduser("~\\AppData\\Roaming"))
    template_apk = Path(appdata) / "Godot" / "export_templates" / "4.3.stable" / "android_debug.apk"
    if not template_apk.exists():
        print(f"[ERROR] Template APK not found at {template_apk}", file=sys.stderr)
        return 1

    # 3. Create modified APK containing assets/game.pck
    unsigned_apk = dist_android / "unsigned.apk"
    print(f"Injecting PCK into {unsigned_apk.name}...")
    with zipfile.ZipFile(template_apk, "r") as src_zip:
        with zipfile.ZipFile(unsigned_apk, "w", zipfile.ZIP_DEFLATED) as dst_zip:
            for item in src_zip.infolist():
                # Skip old signatures in META-INF
                if item.filename.startswith("META-INF/"):
                    continue
                dst_zip.writestr(item, src_zip.read(item.filename))
            # Write PCK as assets/game.pck and assets/project.pck
            pck_data = pck_path.read_bytes()
            dst_zip.writestr("assets/game.pck", pck_data)
            dst_zip.writestr("assets/main.pck", pck_data)

    # 4. Locate apksigner and zipalign in Android SDK
    sdk_dir = Path.home() / "AppData" / "Local" / "Android" / "Sdk"
    apksigner_bat = find_file(sdk_dir / "build-tools", "apksigner.bat")
    zipalign_exe = find_file(sdk_dir / "build-tools", "zipalign.exe")
    debug_keystore = Path.home() / ".android" / "debug.keystore"

    aligned_apk = dist_android / "aligned.apk"
    if zipalign_exe and zipalign_exe.exists():
        print("Aligning APK with zipalign...")
        subprocess.run([str(zipalign_exe), "-p", "-f", "4", str(unsigned_apk), str(aligned_apk)], check=True)
    else:
        aligned_apk = unsigned_apk

    if apksigner_bat and apksigner_bat.exists() and debug_keystore.exists():
        print("Signing APK with apksigner...")
        sign_cmd = [
            str(apksigner_bat),
            "sign",
            "--ks",
            str(debug_keystore),
            "--ks-key-alias",
            "androiddebugkey",
            "--ks-pass",
            "pass:android",
            "--key-pass",
            "pass:android",
            "--out",
            str(target_apk),
            str(aligned_apk),
        ]
        res = subprocess.run(sign_cmd)
        if res.returncode == 0:
            print(f"[OK] Android APK successfully built and signed: {target_apk}")
            # Also copy to dist root
            shutil.copy(target_apk, Path("dist") / "Hive-Lattice-native-playtest.apk")
        else:
            print("[WARN] apksigner returned non-zero code. Falling back to unsigned bundle.")
            shutil.copy(aligned_apk, target_apk)
    else:
        shutil.copy(aligned_apk, target_apk)

    # Clean temporary build files
    for tmp in [unsigned_apk, dist_android / "aligned.apk", pck_path]:
        if tmp.exists() and tmp != target_apk:
            try:
                tmp.unlink()
            except OSError:
                pass

    print(f"\n[SUCCESS] Deliverable created at {target_apk} ({target_apk.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
