#!/usr/bin/env python3
"""Verify native Android APK boot and Godot engine initialization on an emulator or real device."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# Ensure repository root is on sys.path
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

PACKAGE_NAME = "org.godotengine.hivelattice"
ACTIVITY_NAME = "com.godot.game.GodotApp"
FULL_COMPONENT = f"{PACKAGE_NAME}/{ACTIVITY_NAME}"

FORBIDDEN_PATTERNS = [
    "Couldn't load project data",
    "Unable to setup the Godot engine",
    "FATAL EXCEPTION",
    "Godot Engine initialization failed",
    "project data missing",
    "Is the .pck file missing?",
    "Fatal signal 11",
]


def find_adb() -> Path:
    which = shutil.which("adb") or shutil.which("adb.exe")
    if which:
        return Path(which)

    candidates = [
        os.environ.get("ANDROID_HOME"),
        os.environ.get("ANDROID_SDK_ROOT"),
        str(Path.home() / "AppData" / "Local" / "Android" / "Sdk"),
        "/usr/local/lib/android/sdk",
        "/opt/android-sdk",
        str(Path.home() / "Android" / "Sdk"),
    ]
    for c in candidates:
        if c:
            adb_bin = Path(c) / "platform-tools" / ("adb.exe" if sys.platform == "win32" else "adb")
            if adb_bin.exists():
                return adb_bin
    raise RuntimeError("adb binary not found in PATH or Android SDK platform-tools.")


def run_adb(adb: Path, args: list[str], check: bool = True, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    cmd = [str(adb)] + args
    return subprocess.run(cmd, capture_output=True, text=True, check=check, timeout=timeout)


def wait_for_boot(adb: Path, max_wait: int = 90) -> None:
    print("[DEVICE] Waiting for Android device / emulator to be online...")
    run_adb(adb, ["wait-for-device"], timeout=max_wait)

    start = time.time()
    while time.time() - start < max_wait:
        res = run_adb(adb, ["shell", "getprop", "sys.boot_completed"], check=False)
        if res.stdout.strip() == "1":
            print("[DEVICE] Device boot completed.")
            return
        time.sleep(2)
    print("[DEVICE] Warning: sys.boot_completed did not return 1 within timeout, proceeding anyway.")


def main() -> int:
    print("============================================================")
    print("HIVE-LATTICE // ANDROID EMULATOR BOOT VERIFICATION GATE")
    print("============================================================\n")

    adb = find_adb()
    print(f"[ADB] Using adb binary: {adb}")

    # Check connected devices
    dev_res = run_adb(adb, ["devices"])
    print(f"[ADB] Connected devices:\n{dev_res.stdout}")
    lines = [l for l in dev_res.stdout.splitlines() if l.strip() and not l.startswith("List of devices")]
    if not lines or all("device" not in l for l in lines):
        print("[SKIP] No Android device or emulator detected. Boot gate requires an active device.", file=sys.stderr)
        return 2

    # Wait for device boot
    wait_for_boot(adb)

    # Locate APK
    apk_candidates = [
        Path("dist/Hive-Lattice-native-android-playtest.apk"),
        Path("dist/android/Hive-Lattice-native-android-playtest.apk"),
    ]
    target_apk = next((p for p in apk_candidates if p.exists() and p.is_file()), None)
    if not target_apk:
        print("[ERROR] Target Android APK not found in dist/!", file=sys.stderr)
        return 1

    print(f"[INSTALL] Installing APK: {target_apk} ({target_apk.stat().st_size} bytes)...")
    install_res = run_adb(adb, ["install", "-r", str(target_apk.resolve())], check=False, timeout=120)
    print(f"[INSTALL] Output: {install_res.stdout.strip()} {install_res.stderr.strip()}")
    if install_res.returncode != 0 or "Success" not in install_res.stdout:
        print("[FAIL] APK installation failed!", file=sys.stderr)
        return 1

    # Clear logcat
    run_adb(adb, ["logcat", "-c"], check=False)

    # Launch application
    print(f"[LAUNCH] Starting {FULL_COMPONENT}...")
    launch_res = run_adb(adb, ["shell", "am", "start", "-n", FULL_COMPONENT], check=False)
    print(f"[LAUNCH] Result: {launch_res.stdout.strip()}")

    # Wait for engine initialization and scene load
    print("[WAIT] Waiting 12 seconds for Godot engine boot & scene startup...")
    time.sleep(12)

    # Verify process is running
    pid_res = run_adb(adb, ["shell", "pidof", PACKAGE_NAME], check=False)
    pid = pid_res.stdout.strip()
    print(f"[PROCESS] PID for {PACKAGE_NAME}: '{pid}'")
    if not pid:
        print(f"[FAIL] Process {PACKAGE_NAME} is not running after launch!", file=sys.stderr)
        # Capture crash logcat
        logcat_res = run_adb(adb, ["logcat", "-d", "-v", "time"], check=False)
        Path("dist/android_crash_logcat.txt").write_text(logcat_res.stdout, encoding="utf-8")
        print("\n--- RECENT CRASH LOGS ---")
        for line in logcat_res.stdout.splitlines()[-40:]:
            print(line)
        return 1

    # Capture logcat
    logcat_res = run_adb(adb, ["logcat", "-d", "-v", "time"], check=False)
    dist_dir = Path("dist")
    dist_dir.mkdir(parents=True, exist_ok=True)
    log_file = dist_dir / "android_boot_logcat.txt"
    log_file.write_text(logcat_res.stdout, encoding="utf-8")
    print(f"[LOGCAT] Dumped {len(logcat_res.stdout.splitlines())} log lines to {log_file}")

    # Capture screenshot
    screenshot_file = dist_dir / "android_boot_screenshot.png"
    try:
        with open(screenshot_file, "wb") as f:
            subprocess.run([str(adb), "exec-out", "screencap", "-p"], stdout=f, timeout=15)
        print(f"[SCREENSHOT] Captured diagnostic screenshot: {screenshot_file} ({screenshot_file.stat().st_size} bytes)")
    except Exception as e:
        print(f"[WARN] Failed to capture emulator screenshot: {e}")

    # Inspect logcat for forbidden error strings
    errors_found: list[str] = []
    for line in logcat_res.stdout.splitlines():
        for pattern in FORBIDDEN_PATTERNS:
            if pattern in line:
                errors_found.append(f"[{pattern}] {line}")

    if errors_found:
        print("\n============================================================")
        print("[FAIL] FORBIDDEN BOOT ERRORS DETECTED IN LOGCAT:")
        for err in errors_found:
            print(f"  {err}")
        print("============================================================\n")
        return 1

    print("\n============================================================")
    print("[PASS] ANDROID BOOT VERIFICATION SUCCEEDED")
    print(f"       Package: {PACKAGE_NAME}")
    print(f"       PID: {pid} (ALIVE & HEALTHY)")
    print("       Project Data Loaded Successfully Without Errors")
    print("============================================================\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
