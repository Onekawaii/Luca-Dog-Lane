#!/usr/bin/env python3
"""Comprehensive test script for Strawberry Omen Visual Layer v0.1"""

import subprocess
import sys
from pathlib import Path


def run_command(cmd: str, cwd: Path) -> tuple[int, str, str]:
    """Run a command and return exit code, stdout, and stderr."""
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=cwd, capture_output=True, text=True
        )
        return result.returncode, result.stdout, result.stderr
    except Exception as e:
        return -1, "", str(e)


def test_validation_commands() -> bool:
    """Test all validation commands."""
    print("=== Testing Validation Commands ===")
    project_root = Path("C:\\Users\\jmgar\\Desktop\\Hive-Lattice-Next\\Hive-Lattice-Next")
    campaign_root = project_root / "campaigns" / "strawberry_omen"
    
    all_passed = True
    
    
    tests = [
        ("validate_campaign_module.py", f"python {project_root}/tools/validate_campaign_module.py {campaign_root}"),
        ("validate_visual_assets.py", f"python {project_root}/tools/validate_visual_assets.py {campaign_root}"),
        ("visual_assets_summary.py", f"python {project_root}/tools/visual_assets_summary.py {campaign_root}"),
    ]
    
    for test_name, command in tests:
        print(f"\n--- Testing: {test_name} ---")
        exit_code, stdout, stderr = run_command(command, project_root)
        
        if exit_code == 0:
            print(f"PASS: {test_name}")
            print(f"Output:\n{stdout}")
        else:
            print(f"FAIL: {test_name} (exit code: {exit_code})")
            if stderr:
                print(f"Error:\n{stderr}")
            all_passed = False
    
    return all_passed


def test_files_exist() -> bool:
    """Test that all required files exist."""
    print("\n=== Testing Required Files Exist ===")
    project_root = Path("C:\\Users\\jmgar\\Desktop\\Hive-Lattice-Next\\Hive-Lattice-Next")
    campaign_root = project_root / "campaigns" / "strawberry_omen"
    
    required_files = [
        "visual_manifest.json",
        "assets/maps/breakroom_battlemap_v0.png",
        "assets/maps/breakroom_map.placeholder.md",
        "assets/characters/darla.placeholder.md",
        "assets/characters/keith.placeholder.md",
        "assets/characters/tammy.placeholder.md",
        "assets/items/wetberry.placeholder.md",
        "assets/items/ancient_mayonnaise.placeholder.md",
    ]
    
    all_passed = True
    
    for filename in required_files:
        file_path = campaign_root / filename
        if file_path.exists():
            print(f"PASS: {filename} exists")
        else:
            print(f"FAIL: {filename} missing")
            all_passed = False
    
    return all_passed


def main() -> int:
    """Run all tests."""
    print("Strawberry Omen Visual Layer v0.1 - Comprehensive Tests")
    print("=" * 60)
    
    project_root = Path("C:\\Users\\jmgar\\Desktop\\Hive-Lattice-Next\\Hive-Lattice-Next")
    campaign_root = project_root / "campaigns" / "strawberry_omen"
    
    # Change to project root
    os.chdir(project_root)
    
    tests = [
        ("Required Files", test_files_exist),
        ("Validation Commands", test_validation_commands),
    ]
    
    all_passed = True
    for test_name, test_func in tests:
        if not test_func():
            all_passed = False
    
    print("\n" + "=" * 60)
    if all_passed:
        print("All tests PASSED")
        return 0
    else:
        print("Some tests FAILED")
        return 1


if __name__ == "__main__":
    import os
    sys.exit(main())