#!/usr/bin/env python3
"""Build, sign, and verify native Android APK for Hive-Lattice using official Godot 4.3 Android export."""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

# Ensure repository root is on sys.path
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


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


def verify_godot_version(godot_bin: Path) -> str:
    res = subprocess.run([str(godot_bin), "--version"], capture_output=True, text=True, check=True)
    version = res.stdout.strip()
    print(f"[ENGINE] Godot Engine Version: {version}")
    if "4.3" not in version:
        raise RuntimeError(f"Expected Godot 4.3, got: {version}")
    return version


def ensure_java_environment() -> Path | None:
    """Ensure JAVA_HOME is set and java binary is in PATH."""
    java_home = os.environ.get("JAVA_HOME")
    if java_home and Path(java_home).exists():
        java_path = Path(java_home)
    else:
        # Check standard paths
        candidates = [
            Path.home() / ".jdk17",
            Path("/usr/lib/jvm/java-17-openjdk-amd64"),
            Path("/opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.20-1/x64"),
        ]
        java_path = None
        for c in candidates:
            if c.exists() and (c / "bin").exists():
                java_path = c
                break

    if java_path:
        os.environ["JAVA_HOME"] = str(java_path)
        bin_dir = str(java_path / "bin")
        if bin_dir not in os.environ.get("PATH", ""):
            os.environ["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")
        print(f"[JAVA] Established JAVA_HOME: {java_path}")
        return java_path
    return None


def find_android_sdk() -> Path:
    candidates = [
        os.environ.get("ANDROID_HOME"),
        os.environ.get("ANDROID_SDK_ROOT"),
        str(Path.home() / "AppData" / "Local" / "Android" / "Sdk"),
        "/usr/local/lib/android/sdk",
        "/opt/android-sdk",
        str(Path.home() / "Android" / "Sdk"),
    ]
    for c in candidates:
        if c and Path(c).exists() and (Path(c) / "platform-tools").exists():
            return Path(c).resolve()
    raise RuntimeError("Android SDK not found. Please set ANDROID_HOME or ANDROID_SDK_ROOT.")


def ensure_debug_keystore() -> Path:
    keystore_dir = Path.home() / ".android"
    keystore_dir.mkdir(parents=True, exist_ok=True)
    keystore_path = keystore_dir / "debug.keystore"
    if not keystore_path.exists():
        print(f"[KEYSTORE] Generating debug keystore at {keystore_path}...")
        keytool = shutil.which("keytool")
        if not keytool:
            jdk_dir = Path.home() / ".jdk17"
            if (jdk_dir / "bin" / "keytool.exe").exists():
                keytool = str(jdk_dir / "bin" / "keytool.exe")
            elif (jdk_dir / "bin" / "keytool").exists():
                keytool = str(jdk_dir / "bin" / "keytool")

        if not keytool:
            raise RuntimeError("keytool not found in PATH or JDK directory.")

        cmd = [
            str(keytool),
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


def configure_godot_editor_settings(sdk_path: Path, keystore_path: Path) -> Path:
    """Ensure Godot editor_settings-4.tres contains valid Android SDK and keystore paths."""
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA") or str(Path.home() / "AppData" / "Roaming")
        settings_dir = Path(appdata) / "Godot"
    else:
        config_home = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
        settings_dir = Path(config_home) / "godot"

    settings_dir.mkdir(parents=True, exist_ok=True)
    settings_file = settings_dir / "editor_settings-4.tres"

    # Forward slash paths for Godot config
    sdk_str = str(sdk_path).replace("\\", "/")
    ks_str = str(keystore_path).replace("\\", "/")

    content = f"""[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "{sdk_str}"
export/android/debug_keystore = "{ks_str}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
"""
    settings_file.write_text(content, encoding="utf-8")
    print(f"[SETTINGS] Configured Godot Android editor settings in {settings_file}")
    return settings_file


def verify_export_templates() -> None:
    """Verify Godot 4.3 Android export templates exist."""
    candidates: list[Path] = []
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA") or str(Path.home() / "AppData" / "Roaming")
        candidates.append(Path(appdata) / "Godot" / "export_templates" / "4.3.stable" / "android_debug.apk")
    else:
        candidates.extend([
            Path.home() / ".local" / "share" / "godot" / "export_templates" / "4.3.stable" / "android_debug.apk",
            Path.home() / ".godot" / "export_templates" / "4.3.stable" / "android_debug.apk",
        ])

    found = False
    for c in candidates:
        if c.exists() and c.is_file():
            print(f"[TEMPLATES] Found Android export template: {c}")
            found = True
            break
    if not found:
        raise RuntimeError("Godot 4.3 Android export template (android_debug.apk) not found in export_templates/4.3.stable/")


def cleanup_godot_temp_apks() -> int:
    """Remove stale Godot Android temp APKs left by interrupted exports."""
    if sys.platform != "win32":
        return 0
    local_appdata = os.environ.get("LOCALAPPDATA")
    if not local_appdata:
        return 0
    temp_dir = Path(local_appdata) / "Godot"
    removed = 0
    for candidate in temp_dir.glob("tmpexport*.apk") if temp_dir.exists() else []:
        try:
            candidate.unlink()
            removed += 1
        except OSError as exc:
            print(f"[WARN] Could not remove stale Godot temp APK {candidate}: {exc}")
    if removed:
        print(f"[CLEANUP] Removed {removed} stale Godot temp APK(s).")
    return removed


def find_build_tool(sdk_path: Path, tool_name: str) -> Path | None:
    which = shutil.which(tool_name) or shutil.which(f"{tool_name}.exe") or shutil.which(f"{tool_name}.bat")
    if which:
        return Path(which)
    build_tools = sdk_path / "build-tools"
    if build_tools.exists():
        for ver_dir in sorted(build_tools.iterdir(), reverse=True):
            if ver_dir.is_dir():
                for ext in ["", ".exe", ".bat"]:
                    candidate = ver_dir / f"{tool_name}{ext}"
                    if candidate.exists():
                        return candidate
    return None


def inspect_and_sign_apk(apk_path: Path, sdk_path: Path, keystore_path: Path) -> None:
    """Verify APK signature and sign with debug keystore if needed."""
    apksigner = find_build_tool(sdk_path, "apksigner")
    zipalign = find_build_tool(sdk_path, "zipalign")

    is_signed = False
    if apksigner and apksigner.exists():
        verify_res = subprocess.run([str(apksigner), "verify", str(apk_path)], capture_output=True, text=True)
        if verify_res.returncode == 0 and "DOES NOT VERIFY" not in verify_res.stdout:
            is_signed = True
            print(f"[SIGN] APK signature already verified via {apksigner.name}")

    if not is_signed and apksigner and apksigner.exists() and keystore_path.exists():
        print(f"[SIGN] Signing APK with debug keystore using {apksigner.name}...")
        sign_cmd = [
            str(apksigner),
            "sign",
            "--ks",
            str(keystore_path),
            "--ks-key-alias",
            "androiddebugkey",
            "--ks-pass",
            "pass:android",
            "--key-pass",
            "pass:android",
            str(apk_path),
        ]
        sign_res = subprocess.run(sign_cmd, capture_output=True, text=True)
        if sign_res.returncode != 0:
            print(f"[WARN] apksigner sign stderr: {sign_res.stderr}")
        else:
            print(f"[SIGN] APK successfully signed.")

    # Final verification
    if apksigner and apksigner.exists():
        final_ver = subprocess.run([str(apksigner), "verify", "--verbose", str(apk_path)], capture_output=True, text=True)
        if final_ver.returncode == 0:
            print("[SIGN-VERIFY] APK signature verified (v1/v2/v3).")
        else:
            print(f"[WARN] APK signature verification output: {final_ver.stdout}\n{final_ver.stderr}")


def inspect_apk_contents(apk_path: Path, sdk_path: Path) -> dict[str, any]:
    """Inspect APK manifest and internal structure."""
    with zipfile.ZipFile(apk_path, "r") as z:
        names = z.namelist()
        total_files = len(names)
        has_manifest = "AndroidManifest.xml" in names
        has_dex = "classes.dex" in names
        has_arm64 = any(n.startswith("lib/arm64-v8a/") for n in names)
        has_x86_64 = any(n.startswith("lib/x86_64/") for n in names)
        asset_count = sum(1 for n in names if n.startswith("assets/"))

    print(f"[INSPECT] Total files in APK: {total_files}")
    print(f"[INSPECT] AndroidManifest.xml: {has_manifest}")
    print(f"[INSPECT] classes.dex: {has_dex}")
    print(f"[INSPECT] lib/arm64-v8a: {has_arm64}")
    print(f"[INSPECT] lib/x86_64: {has_x86_64}")
    print(f"[INSPECT] Packaged project assets: {asset_count}")

    if not has_manifest or not has_dex or asset_count == 0:
        raise RuntimeError("APK integrity check failed: Missing manifest, DEX, or project assets!")

    # Check badging with aapt if available
    aapt = find_build_tool(sdk_path, "aapt")
    if aapt and aapt.exists():
        badge_res = subprocess.run([str(aapt), "dump", "badging", str(apk_path)], capture_output=True, text=True)
        if badge_res.returncode == 0:
            for line in badge_res.stdout.splitlines():
                if line.startswith("package:") or line.startswith("launchable-activity:") or line.startswith("native-code:"):
                    print(f"[AAPT] {line}")

    return {
        "size": apk_path.stat().st_size,
        "files": total_files,
        "has_arm64": has_arm64,
        "has_x86_64": has_x86_64,
    }


def write_sha256(file_path: Path) -> str:
    sha = hashlib.sha256(file_path.read_bytes()).hexdigest()
    sidecar = file_path.with_name(f"{file_path.name}.sha256")
    sidecar.write_text(f"{sha}  {file_path.name}\n", encoding="utf-8")
    print(f"[SHA256] {sidecar.name}: {sha}")
    return sha


def main() -> int:
    print("============================================================")
    print("HIVE-LATTICE // OFFICIAL GODOT ANDROID EXPORT PIPELINE")
    print("============================================================\n")

    # 1. Locate and verify Godot
    godot_bin = find_godot_binary()
    if not godot_bin:
        print("[ERROR] Godot binary not found in PATH or ~/.godot_bin!", file=sys.stderr)
        return 1
    verify_godot_version(godot_bin)

    # 2. Locate Android SDK, Java, and export templates
    ensure_java_environment()
    sdk_path = find_android_sdk()
    print(f"[SDK] Android SDK Path: {sdk_path}")
    verify_export_templates()

    # 3. Setup debug keystore and EditorSettings
    keystore_path = ensure_debug_keystore()
    print(f"[KEYSTORE] Debug Keystore: {keystore_path}")
    configure_godot_editor_settings(sdk_path, keystore_path)

    # 4. Prepare output directories
    dist_android = Path("dist/android")
    dist_android.mkdir(parents=True, exist_ok=True)
    dist_root = Path("dist")
    dist_root.mkdir(parents=True, exist_ok=True)

    output_apk = dist_android / "Hive-Lattice-native-android-playtest.apk"
    if output_apk.exists():
        output_apk.unlink()
    cleanup_godot_temp_apks()

    # 5. Ensure textures are imported with etc2_astc
    print("[EXPORT] Re-importing Godot assets in headless mode...")
    subprocess.run([str(godot_bin), "--headless", "--path", "game_godot", "--import"], check=True)

    # 6. Execute official Godot Android export
    export_cmd = [
        str(godot_bin),
        "--headless",
        "--path",
        "game_godot",
        "--export-debug",
        "Android",
        str(output_apk.resolve()),
    ]
    print(f"[EXPORT] Executing Godot Android Export:\n  {' '.join(export_cmd)}")
    res = subprocess.run(export_cmd)
    if res.returncode != 0 or not output_apk.exists():
        print(f"[RETRY] Android export failed with exit code {res.returncode}; cleaning stale temp APKs and retrying once.")
        cleanup_godot_temp_apks()
        if output_apk.exists():
            output_apk.unlink()
        res = subprocess.run(export_cmd)
    if res.returncode != 0 or not output_apk.exists():
        print(f"[ERROR] Godot Android export failed after clean retry with exit code {res.returncode}", file=sys.stderr)
        return 1

    # 7. Verify / sign APK
    inspect_and_sign_apk(output_apk, sdk_path, keystore_path)

    # 8. Inspect contents and metadata
    metadata = inspect_apk_contents(output_apk, sdk_path)

    # 9. Copy to root dist/ and write SHA-256 sidecars
    root_apk = dist_root / "Hive-Lattice-native-android-playtest.apk"
    shutil.copy2(output_apk, root_apk)

    write_sha256(output_apk)
    write_sha256(root_apk)

    print("\n============================================================")
    print(f"[SUCCESS] Official Godot Android APK built: {root_apk}")
    print(f"          Size: {metadata['size']} bytes (~{metadata['size'] / (1024*1024):.2f} MB)")
    print("============================================================\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
