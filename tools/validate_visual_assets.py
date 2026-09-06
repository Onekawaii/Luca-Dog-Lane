import json
import sys
from pathlib import Path
from typing import Any


def load(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def validate_visual_assets(root: Path) -> list[str]:
    errors: list[str] = []
    
    manifest_path = root / "visual_manifest.json"
    if not manifest_path.exists():
        errors.append("missing visual_manifest.json")
        return errors
    
    manifest = load(manifest_path)
    assets = manifest.get("assets", {})
    
    
    for category in ("maps", "textures", "items", "tokens", "rooms"):
        category_assets = assets.get(category, [])
        for asset in category_assets:
            asset_path = root / asset["path"]
            if not asset_path.exists():
                errors.append(f"visual asset missing: {asset['path']} (asset: {asset['asset_id']})")
                continue
            
            if asset.get("status") == "placeholder" and not str(asset_path).endswith(".placeholder.md"):
                errors.append(f"placeholder asset does not end with .placeholder.md: {asset['asset_id']}")
            
            if asset.get("status") == "replaced_by_v0_image" and not str(asset_path).endswith(".png"):
                errors.append(f"replaced_by_v0_image asset must be PNG: {asset['asset_id']}")
            
            if asset.get("status") == "placeholder" and asset.get("prompt"):
                errors.append(f"placeholder asset should not have prompt: {asset['asset_id']}")
    
    return errors


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("campaigns/strawberry_omen")
    errors = validate_visual_assets(root)
    if errors:
        print("Visual assets validation FAILED")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"Visual assets validation PASSED: {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())