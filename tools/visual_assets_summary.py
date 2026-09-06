#!/usr/bin/env python3
"""Commands for working with visual assets in the campaign module."""

from pathlib import Path
import sys


def print_visual_asset_summary(asset_path: Path) -> None:
    print(f"Visual Asset: {asset_path.name}")
    print(f"Path: {asset_path}")
    print(f"Size: {asset_path.stat().st_size} bytes")
    print()


def find_visual_assets(root: Path) -> None:
    print("=== Visual Assets Summary ===")
    
    image_files = list(root.glob("**/*.png"))
    md_files = list(root.glob("**/*.placeholder.md"))
    
    print(f"PNG Images: {len(image_files)}")
    for img in image_files:
        print_visual_asset_summary(img)
    
    print(f"\nPlaceholder Files: {len(md_files)}")
    
    # Group by category using manifest file
    manifest_path = root / "visual_manifest.json"
    if manifest_path.exists():
        import json
        manifest = json.load(open(manifest_path))
        
        categories = {
            "maps": [],
            "textures": [],
            "items": [],
            "tokens": [],
            "rooms": []
        }
        
        for category_name in categories:
            for asset in manifest["assets"].get(category_name, []):
                categories[category_name].append(asset["asset_id"])
        
        # Display by category
        for category_name, assets in categories.items():
            if assets:
                display_name = category_name.rstrip("s") if len(assets) == 1 else category_name
                print(f"\n{category_name.title()} ({len(assets)}):")
                for asset_id in assets:
                    print(f"  - {asset_id}")
    
    print()


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("campaigns/strawberry_omen")
    find_visual_assets(root)
    return 0


if __name__ == "__main__":
    sys.exit(main())