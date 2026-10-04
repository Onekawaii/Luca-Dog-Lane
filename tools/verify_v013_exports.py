#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist" / "v013-qualification"
WIN = DIST / "windows"
ANDROID = DIST / "android"
WIN_EXE = WIN / "Luca-Dog-World-v013-qual.exe"
WIN_CONSOLE = WIN / "Luca-Dog-World-v013-qual.console.exe"
WIN_VOXEL = WIN / "libvoxel.windows.editor.x86_64.dll"
APK = ANDROID / "Luca-Dog-World-v013-qual.apk"
WIN_LOG = DIST / "windows_export.log"
ANDROID_LOG = DIST / "android_export.log"

TOOLCHAIN_ROOT = Path.home() / ".luca_toolchain"
EXPORT_RECEIPT = TOOLCHAIN_ROOT / "EXPORT_TEMPLATE_RECEIPT_v013.json"
ANDROID_RECEIPT = TOOLCHAIN_ROOT / "ANDROID_TOOLCHAIN_RECEIPT_v013.json"

LEAK_MARKERS = (
    "res://engineering/",
    "res://tools/",
    "res://tests/",
    "res://AGENTS.md",
    "res://addons/zylann.voxel/editor/",
)

APK_REQUIRED = (
    "lib/arm64-v8a/libvoxel.android.editor.arm64.so",
    "lib/x86_64/libvoxel.android.editor.x86_64.so",
    "assets/addons/zylann.voxel/voxel.gdextension",
)


def fail(message: str) -> None:
    print(f"[FAIL] {message}")
    raise SystemExit(1)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


def run(command: list[str], label: str, env: dict[str, str] | None = None, timeout: int = 120) -> str:
    result = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        env=env,
        timeout=timeout,
    )
    combined = result.stdout + "\n" + result.stderr
    if result.returncode != 0:
        print(combined)
        fail(f"{label}: rc={result.returncode}")
    print(f"[PASS] {label}")
    return combined


def validate_exact_state(allow_dirty: bool) -> tuple[str, bool]:
    branch = git("branch", "--show-current")
    head = git("rev-parse", "HEAD")
    dirty = bool(git("status", "--porcelain"))
    if branch == "main":
        fail("qualification must not run directly on main")
    if dirty and not allow_dirty:
        fail("qualification requires a clean exact-state worktree")
    print(f"[PASS] exact state branch={branch} head={head} dirty={dirty}")
    return head, dirty


def validate_toolchain_receipts() -> None:
    if not EXPORT_RECEIPT.exists():
        fail("4.7.2 export-template receipt missing")
    if not ANDROID_RECEIPT.exists():
        fail("Android toolchain receipt missing")

    export_data = json.loads(EXPORT_RECEIPT.read_text(encoding="utf-8-sig"))
    android_data = json.loads(ANDROID_RECEIPT.read_text(encoding="utf-8-sig"))

    if export_data.get("archive_sha256") != "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011":
        fail("export-template receipt hash mismatch")
    if export_data.get("version_txt") != "4.7.2.stable":
        fail("export-template receipt version mismatch")
    if "17.0.12" not in str(android_data.get("java_version", "")):
        fail("Android JDK receipt does not identify JDK 17.0.12")
    print("[PASS] export-template + Android toolchain receipts")


def validate_export_hygiene() -> None:
    for log_path in (WIN_LOG, ANDROID_LOG):
        if not log_path.exists():
            fail(f"export log missing: {log_path}")
        text = log_path.read_text(encoding="utf-8", errors="ignore")
        leaks = [marker for marker in LEAK_MARKERS if marker in text]
        if leaks:
            fail(f"{log_path.name} packed forbidden repo/editor resources: {leaks}")
    print("[PASS] export logs contain no repo/test/editor leakage")


def validate_windows() -> dict[str, object]:
    for path in (WIN_EXE, WIN_CONSOLE, WIN_VOXEL):
        if not path.exists() or path.stat().st_size <= 0:
            fail(f"Windows artifact missing/empty: {path}")

    env = os.environ.copy()
    env["LUCA_V013_EXPORT_PROBE"] = "1"
    probe = run([str(WIN_CONSOLE), "--headless"], "exported Windows voxel runtime probe", env=env, timeout=60)
    if "[ALL EXPORTED VOXEL RUNTIME GATES PASSED]" not in probe:
        fail("exported Windows voxel runtime marker missing")

    normal = run([str(WIN_CONSOLE), "--headless", "--quit-after", "120"], "exported Windows normal runtime", timeout=60)
    if "LUCA_SANDBOX_READY" not in normal:
        fail("exported Windows game did not reach LUCA_SANDBOX_READY")

    print("[PASS] Windows package carries and loads Voxel Tools")
    return {
        "exe_bytes": WIN_EXE.stat().st_size,
        "exe_sha256": sha256(WIN_EXE),
        "console_bytes": WIN_CONSOLE.stat().st_size,
        "voxel_dll_bytes": WIN_VOXEL.stat().st_size,
        "voxel_dll_sha256": sha256(WIN_VOXEL),
    }


def _build_tools() -> tuple[Path, Path]:
    sdk = Path.home() / "AppData" / "Local" / "Android" / "Sdk"
    root = sdk / "build-tools"
    if not root.exists():
        fail("Android build-tools directory missing")

    def key(path: Path) -> tuple[int, ...]:
        parts = re.findall(r"\d+", path.name)
        return tuple(int(p) for p in parts)

    candidates = sorted((p for p in root.iterdir() if p.is_dir()), key=key, reverse=True)
    for folder in candidates:
        signer = folder / "apksigner.bat"
        aapt = folder / "aapt.exe"
        if signer.exists() and aapt.exists():
            return signer, aapt
    fail("working apksigner/aapt pair not found")
    raise AssertionError


def validate_android() -> dict[str, object]:
    if not APK.exists() or APK.stat().st_size <= 0:
        fail("Android qualification APK missing/empty")

    signer, aapt = _build_tools()
    env = os.environ.copy()
    env["JAVA_HOME"] = str(Path.home() / ".jdk17")
    env["PATH"] = str(Path(env["JAVA_HOME"]) / "bin") + os.pathsep + env.get("PATH", "")

    sig = run(
        ["cmd.exe", "/d", "/c", str(signer), "verify", "--verbose", "--print-certs", str(APK)],
        "APK signature verification",
        env=env,
    )
    if "Verified using v2 scheme (APK Signature Scheme v2): true" not in sig:
        fail("APK v2 signature missing")
    if "Verified using v3 scheme (APK Signature Scheme v3): true" not in sig:
        fail("APK v3 signature missing")

    badging = run([str(aapt), "dump", "badging", str(APK)], "APK badging")
    package_line = next((line for line in badging.splitlines() if line.startswith("package:")), "")
    for expected in (
        "name='com.onekawaii.lucadogworld'",
        "versionCode='14'",
        "versionName='0.12.2'",
    ):
        if expected not in package_line:
            fail(f"APK metadata missing {expected}: {package_line}")

    with zipfile.ZipFile(APK) as zf:
        names = set(zf.namelist())
        for required in APK_REQUIRED:
            if required not in names:
                fail(f"APK missing Voxel Tools payload: {required}")
        forbidden = [
            name for name in names
            if (
                name.startswith("assets/engineering/")
                or name.startswith("assets/tools/")
                or name.startswith("assets/tests/")
                or name.startswith("assets/addons/zylann.voxel/editor/")
                or name == "assets/AGENTS.md"
            )
        ]
        if forbidden:
            fail("APK contains forbidden repo/editor files: " + ", ".join(forbidden[:20]))

        arm64_info = zf.getinfo(APK_REQUIRED[0])
        x64_info = zf.getinfo(APK_REQUIRED[1])

    print("[PASS] Android APK contains arm64 + x86_64 Voxel Tools libraries")
    print("[PASS] Android APK contains no repo/test/editor leakage")
    return {
        "bytes": APK.stat().st_size,
        "sha256": sha256(APK),
        "package": "com.onekawaii.lucadogworld",
        "version_code": 14,
        "version_name": "0.12.2",
        "voxel_arm64_bytes": arm64_info.file_size,
        "voxel_x86_64_bytes": x64_info.file_size,
        "signature_v2": True,
        "signature_v3": True,
    }


def write_receipt(head: str, dirty: bool, windows: dict[str, object], android: dict[str, object]) -> Path:
    receipt = {
        "schema_version": 1,
        "qualification": "ENG-003 Godot 4.7.2 native export",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "git_head": head,
        "worktree_dirty": dirty,
        "state": "PRECOMMIT_ONLY" if dirty else "QUALIFIED_EXACT_COMMIT",
        "engine": "4.7.2.stable.official.ed1daf0bf",
        "voxel_tools": "1.7/v1.7x",
        "windows": windows,
        "android": android,
        "gates": {
            "toolchain_receipts": "PASS",
            "export_hygiene": "PASS",
            "windows_voxel_runtime": "PASS",
            "windows_normal_runtime": "PASS",
            "android_signature": "PASS",
            "android_dual_abi_voxel": "PASS",
            "physical_android": "PENDING",
        },
    }
    DIST.mkdir(parents=True, exist_ok=True)
    path = DIST / "QUALIFICATION_RECEIPT_v013.json"
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"[RECEIPT] {path}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-dirty", action="store_true")
    args = parser.parse_args()

    head, dirty = validate_exact_state(args.allow_dirty)
    validate_toolchain_receipts()
    validate_export_hygiene()
    windows = validate_windows()
    android = validate_android()
    write_receipt(head, dirty, windows, android)
    print("[ALL V0.13 NATIVE EXPORT QUALIFICATION GATES PASSED]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
