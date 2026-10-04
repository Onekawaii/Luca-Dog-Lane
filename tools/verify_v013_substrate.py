#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLCHAIN_ROOT = Path.home() / ".luca_toolchain"
BOOTSTRAP_RECEIPT = TOOLCHAIN_ROOT / "BOOTSTRAP_RECEIPT_v013.json"
GODOT = TOOLCHAIN_ROOT / "Godot-4.7.2" / "Godot_v4.7.2-stable_win64_console.exe"
VOXEL_ADDON = ROOT / "addons" / "zylann.voxel"


def fail(message: str) -> None:
    print(f"[FAIL] {message}")
    raise SystemExit(1)


def run(command: list[str], label: str, timeout: int = 240) -> str:
    result = subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    combined = result.stdout + "\n" + result.stderr
    if result.returncode != 0:
        print(combined)
        fail(f"{label}: rc={result.returncode}")
    print(f"[PASS] {label}")
    return combined


def verify_bootstrap_receipt() -> None:
    if not BOOTSTRAP_RECEIPT.exists():
        fail("bootstrap receipt missing; run tools/bootstrap_v013_toolchain.ps1")
    data = json.loads(BOOTSTRAP_RECEIPT.read_text(encoding="utf-8-sig"))
    if not str(data.get("engine_version", "")).startswith("4.7.2"):
        fail("bootstrap receipt engine mismatch")
    if data.get("engine_archive_sha256") != "731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953":
        fail("bootstrap engine hash mismatch")
    if data.get("voxel_archive_sha256") != "600737572a5e25541ba6f503e842a3717ba19afafa5474510a6ceff995a1d2d8":
        fail("bootstrap voxel hash mismatch")
    if not GODOT.exists():
        fail("locked Godot executable missing")
    print("[PASS] bootstrap receipt + exact dependency hashes")


def stage_voxel_dependency() -> None:
    run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "tools" / "stage_v013_voxel.ps1"),
        ],
        "stage pinned voxel dependency",
    )

    required = [
        VOXEL_ADDON / "voxel.gdextension",
        VOXEL_ADDON / "bin" / "libvoxel.windows.editor.x86_64.dll",
        VOXEL_ADDON / "bin" / "libvoxel.android.template_release.arm64.so",
        VOXEL_ADDON / "bin" / "libvoxel.android.template_release.x86_64.so",
    ]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        fail("staged voxel dependency incomplete: " + ", ".join(missing))

    ignored = subprocess.run(
        ["git", "-C", str(ROOT), "check-ignore", "addons/zylann.voxel/voxel.gdextension"],
        capture_output=True,
        text=True,
    )
    if ignored.returncode != 0:
        fail("generated voxel addon is not ignored by Git")
    print("[PASS] staged addon contains Windows + Android binaries and is untracked")


def run_behavior_gates() -> None:
    run([sys.executable, "tools/check_engineering_contract.py"], "engineering contract")
    run([sys.executable, "tools/verify_v013_migration_baseline.py"], "4.7.2 migration baseline", 360)

    extension = run(
        [str(GODOT), "--headless", "--path", str(ROOT), "--script", "tests/voxel_extension_smoke.gd"],
        "voxel extension class/instantiation smoke",
    )
    if "[ALL VOXEL EXTENSION GATES PASSED]" not in extension:
        fail("voxel extension smoke lacked completion marker")

    edit = run(
        [str(GODOT), "--headless", "--path", str(ROOT), "--script", "tests/voxel_edit_smoke.gd"],
        "streamed voxel place/remove proof",
    )
    if "[ALL VOXEL EDIT GATES PASSED]" not in edit:
        fail("voxel edit smoke lacked completion marker")


def main() -> int:
    verify_bootstrap_receipt()
    stage_voxel_dependency()
    run_behavior_gates()
    print("[ALL V0.13 SUBSTRATE GATES PASSED]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
