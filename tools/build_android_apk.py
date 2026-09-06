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


def find_godot_binary() -> Path | None:
    env_bin = os.environ.get("GODOT_BIN")
    if env_bin and Path(env_bin).exists():
        return Path(env_bin)

    home_bin = Path.home() / ".godot_bin"
    for candidate in [
        home_bin / "Godot_v4.3-stable_win64_console.exe",
        home_bin / "Godot_v4.3-stable_win64.exe",
        home_bin / "godot.exe",
        home_bin / "godot",
        home_bin / "Godot_v4.3-stable_linux.x86_64",
        Path("/usr/local/bin/godot"),
        Path("/usr/bin/godot"),
    ]:
        if candidate.exists() and candidate.is_file():
            return candidate

    which = shutil.which("godot") or shutil.which("godot4") or shutil.which("godot-headless")
    if which:
        return Path(which)
    return None


def find_android_template() -> Path | None:
    # Check Windows AppData
    appdata = os.environ.get("APPDATA")
    candidates: list[Path] = []
    if appdata:
        candidates.append(Path(appdata) / "Godot" / "export_templates" / "4.3.stable" / "android_debug.apk")
        candidates.append(Path(appdata) / "Godot" / "export_templates" / "4.3.stable" / "android_release.apk")

    # Check Linux / macOS local share
    home = Path.home()
    candidates.extend([
        home / ".local" / "share" / "godot" / "export_templates" / "4.3.stable" / "android_debug.apk",
        home / ".local" / "share" / "godot" / "export_templates" / "4.3.stable" / "android_release.apk",
        home / ".godot" / "export_templates" / "4.3.stable" / "android_debug.apk",
        home / "AppData" / "Roaming" / "Godot" / "export_templates" / "4.3.stable" / "android_debug.apk",
    ])

    for c in candidates:
        if c.exists() and c.is_file():
            return c
    return None


def ensure_debug_keystore() -> Path:
    keystore_dir = Path.home() / ".android"
    keystore_dir.mkdir(parents=True, exist_ok=True)
    keystore_path = keystore_dir / "debug.keystore"
    if not keystore_path.exists():
        print(f"Generating debug keystore at {keystore_path}...")
        keytool = shutil.which("keytool")
        if not keytool:
            jdk_dir = Path.home() / ".jdk17"
            if (jdk_dir / "bin" / "keytool.exe").exists():
                keytool = str(jdk_dir / "bin" / "keytool.exe")
            elif (jdk_dir / "bin" / "keytool").exists():
                keytool = str(jdk_dir / "bin" / "keytool")

        if keytool:
            cmd = [
                keytool,
                "-genkeypair",
                "-v",
                "-keystore",
                str(keystore_path),
                "-alias",
                "androiddebugkey",
                "-keyalg",
                "RSA",
                "-keysize",
                "2048",
                "-validity",
                "10000",
                "-storepass",
                "android",
                "-keypass",
                "android",
                "-dname",
                "CN=Android Debug,O=Android,C=US",
            ]
            subprocess.run(cmd, check=True)
    return keystore_path


def main() -> int:
    # Ensure JAVA_HOME and PATH are set
    jdk_dir = Path.home() / ".jdk17"
    if jdk_dir.exists():
        os.environ["JAVA_HOME"] = str(jdk_dir)
        bin_dir = jdk_dir / "bin"
        os.environ["PATH"] = str(bin_dir) + os.pathsep + os.environ.get("PATH", "")

    dist_android = Path("dist/android")
    dist_android.mkdir(parents=True, exist_ok=True)
    target_apk = dist_android / "Hive-Lattice-native-android-playtest.apk"

    print("============================================================")
    print("BUILDING NATIVE ANDROID APK")
    print("============================================================\n")

    # 1. Export Godot PCK
    godot_exe = find_godot_binary()
    if not godot_exe:
        print("[ERROR] Godot binary not found!", file=sys.stderr)
        return 1

    pck_path = dist_android / "game.pck"
    print(f"Exporting PCK using {godot_exe} to {pck_path}...")
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
    template_apk = find_android_template()
    if not template_apk:
        print("[ERROR] Android template APK not found in export_templates!", file=sys.stderr)
        return 1

    # 3. Create modified APK containing assets/game.pck
    unsigned_apk = dist_android / "unsigned.apk"
    print(f"Injecting PCK into {unsigned_apk.name} using {template_apk.name}...")
    with zipfile.ZipFile(template_apk, "r") as src_zip:
        with zipfile.ZipFile(unsigned_apk, "w", zipfile.ZIP_DEFLATED) as dst_zip:
            for item in src_zip.infolist():
                # Skip old signatures in META-INF
                if item.filename.startswith("META-INF/"):
                    continue
                dst_zip.writestr(item, src_zip.read(item.filename))
            # Write PCK as assets/game.pck and assets/main.pck
            pck_data = pck_path.read_bytes()
            dst_zip.writestr("assets/game.pck", pck_data)
            dst_zip.writestr("assets/main.pck", pck_data)

    # 4. Locate apksigner and zipalign in Android SDK or PATH
    apksigner = shutil.which("apksigner") or shutil.which("apksigner.bat")
    zipalign = shutil.which("zipalign") or shutil.which("zipalign.exe")

    sdk_roots = [
        os.environ.get("ANDROID_SDK_ROOT"),
        os.environ.get("ANDROID_HOME"),
        str(Path.home() / "AppData" / "Local" / "Android" / "Sdk"),
        "/usr/local/lib/android/sdk",
        "/opt/android-sdk",
    ]

    for sr in sdk_roots:
        if not sr:
            continue
        sdk_path = Path(sr)
        if not apksigner:
            found_as = find_file(sdk_path / "build-tools", "apksigner") or find_file(sdk_path / "build-tools", "apksigner.bat")
            if found_as:
                apksigner = str(found_as)
        if not zipalign:
            found_za = find_file(sdk_path / "build-tools", "zipalign") or find_file(sdk_path / "build-tools", "zipalign.exe")
            if found_za:
                zipalign = str(found_za)

    debug_keystore = ensure_debug_keystore()

    aligned_apk = dist_android / "aligned.apk"
    if zipalign and Path(zipalign).exists():
        print(f"Aligning APK with {zipalign}...")
        subprocess.run([str(zipalign), "-p", "-f", "4", str(unsigned_apk), str(aligned_apk)], check=True)
    else:
        aligned_apk = unsigned_apk

    if apksigner and Path(apksigner).exists() and debug_keystore.exists():
        print(f"Signing APK with {apksigner}...")
        sign_cmd = [
            str(apksigner),
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
            shutil.copy(target_apk, Path("dist") / "Hive-Lattice-native-android-playtest.apk")
        else:
            print("[WARN] apksigner returned non-zero code. Falling back to unsigned bundle.")
            shutil.copy(aligned_apk, target_apk)
            shutil.copy(target_apk, Path("dist") / "Hive-Lattice-native-android-playtest.apk")
    else:
        shutil.copy(aligned_apk, target_apk)
        shutil.copy(target_apk, Path("dist") / "Hive-Lattice-native-android-playtest.apk")

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
