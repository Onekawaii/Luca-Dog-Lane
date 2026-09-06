#!/usr/bin/env python3
"""Configure Godot Editor Settings for Android Export."""

from __future__ import annotations

import os
from pathlib import Path


def main() -> None:
    appdata = os.environ.get("APPDATA", os.path.expanduser("~\\AppData\\Roaming"))
    godot_cfg_dir = Path(appdata) / "Godot"
    godot_cfg_dir.mkdir(parents=True, exist_ok=True)

    sdk_path = "C:/Users/jmgar/AppData/Local/Android/Sdk"
    java_path = "C:/Users/jmgar/.jdk17"
    keystore_path = "C:/Users/jmgar/.android/debug.keystore"

    settings_files = ["editor_settings-4.3.tres", "editor_settings-4.tres"]

    for sf in settings_files:
        path = godot_cfg_dir / sf
        if path.exists():
            content = path.read_text(encoding="utf-8")
        else:
            content = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'

        lines = content.splitlines()
        new_lines = []
        has_sdk = False
        has_java = False
        has_keystore = False

        for line in lines:
            if line.startswith("export/android/android_sdk_path"):
                new_lines.append(f'export/android/android_sdk_path = "{sdk_path}"')
                has_sdk = True
            elif line.startswith("export/android/java_sdk_path"):
                new_lines.append(f'export/android/java_sdk_path = "{java_path}"')
                has_java = True
            elif line.startswith("export/android/debug_keystore "):
                new_lines.append(f'export/android/debug_keystore = "{keystore_path}"')
                has_keystore = True
            else:
                new_lines.append(line)

        if not has_sdk:
            new_lines.append(f'export/android/android_sdk_path = "{sdk_path}"')
        if not has_java:
            new_lines.append(f'export/android/java_sdk_path = "{java_path}"')
        if not has_keystore:
            new_lines.append(f'export/android/debug_keystore = "{keystore_path}"')
            new_lines.append('export/android/debug_keystore_user = "androiddebugkey"')
            new_lines.append('export/android/debug_keystore_pass = "android"')

        path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
        print(f"Updated Android export settings in {path}")


if __name__ == "__main__":
    main()
