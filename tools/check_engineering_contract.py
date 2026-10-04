#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROTOCOL = ROOT / "AGENTS.md"
LEDGER = ROOT / "engineering" / "BUILD_LEDGER.md"
LOCK = ROOT / "engineering" / "TOOLCHAIN_LOCK.json"

REQUIRED_PROTOCOL_PHRASES = (
    "No receipt, no banana.",
    "Required task sequence",
    "Falsifier",
    "Demolition",
    "Definition of done",
    "physical-phone claim without physical-phone evidence",
)
REQUIRED_LEDGER_FIELDS = (
    "**ID**",
    "**Date**",
    "**Branch / HEAD**",
    "**Goal**",
    "**Invariant**",
    "**Falsifier**",
    "**Commands executed**",
    "**Results**",
    "**Demolition**",
    "**Status**",
)


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def validate_protocol() -> None:
    if not PROTOCOL.exists():
        fail("AGENTS.md missing")
    text = PROTOCOL.read_text(encoding="utf-8")
    for phrase in REQUIRED_PROTOCOL_PHRASES:
        if phrase not in text:
            fail(f"protocol missing required rule: {phrase}")
    print("[PASS] hardened engineering protocol present")


def validate_ledger() -> None:
    if not LEDGER.exists():
        fail("engineering/BUILD_LEDGER.md missing")
    text = LEDGER.read_text(encoding="utf-8")
    for field in REQUIRED_LEDGER_FIELDS:
        if field not in text:
            fail(f"ledger schema missing field: {field}")
    entries = re.findall(r"^## ENG-\d{3}\b", text, flags=re.MULTILINE)
    if len(entries) < 2:
        fail("ledger must contain establishment and active migration entries")
    if "**Status:** IN_PROGRESS" not in text:
        fail("ledger has no active IN_PROGRESS engineering entry")
    print(f"[PASS] build ledger schema present ({len(entries)} entries)")


def validate_lock() -> None:
    if not LOCK.exists():
        fail("engineering/TOOLCHAIN_LOCK.json missing")
    data = json.loads(LOCK.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        fail("unsupported toolchain lock schema")
    engine = data.get("engine", {})
    voxel = data.get("voxel_tools", {})
    rollback = data.get("rollback", {})
    if engine.get("version") != "4.7.2-stable":
        fail("Godot migration target is not pinned to 4.7.2-stable")
    if voxel.get("tag") != "v1.7x":
        fail("Voxel Tools tag is not pinned to v1.7x")
    for name, item in (("engine", engine), ("voxel_tools", voxel)):
        digest = item.get("sha256", "")
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            fail(f"{name} SHA-256 is malformed")
        if not str(item.get("url", "")).startswith("https://"):
            fail(f"{name} URL is not HTTPS")
    if rollback.get("commit") != "76f9659321824ea61460256a0bdbc8619b34035a":
        fail("v0.12.2 rollback commit changed")
    print("[PASS] toolchain and rollback pins are exact")


def validate_uid_policy() -> None:
    ignore_text = (ROOT / ".gitignore").read_text(encoding="utf-8")
    if "*.uid" in ignore_text or "*.gd.uid" in ignore_text:
        fail("Godot UID sidecars must not be ignored")

    missing: list[str] = []
    for folder in (ROOT / "scripts", ROOT / "tests"):
        for script in folder.rglob("*.gd"):
            sidecar = Path(str(script) + ".uid")
            if not sidecar.exists():
                missing.append(str(script.relative_to(ROOT)))
    if missing:
        fail("missing Godot UID sidecars: " + ", ".join(missing))
    print("[PASS] Godot script UID sidecars are present and versionable")


def validate_git_state() -> None:
    branch = git("branch", "--show-current")
    head = git("rev-parse", "HEAD")
    rollback = json.loads(LOCK.read_text(encoding="utf-8"))["rollback"]["commit"]
    if branch == "main":
        fail("migration work must not run directly on main")
    ancestry = subprocess.run(
        ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", rollback, head]
    )
    if ancestry.returncode != 0:
        fail("current migration state does not descend from locked rollback commit")
    print(f"[PASS] migration branch isolated at {head[:12]} ({branch})")


def main() -> int:
    validate_protocol()
    validate_ledger()
    validate_lock()
    validate_uid_policy()
    validate_git_state()
    print("[ALL ENGINEERING CONTRACT GATES PASSED]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
