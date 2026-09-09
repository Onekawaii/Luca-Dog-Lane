#!/usr/bin/env python3
"""Generate clean, modular decals and tile textures for Hive-Lattice 3D breakroom.

Strict Rule: NO full-object wrapped images.
Generates:
1. Wetberry front label decal (transparent quad)
2. Keith name badge decal (transparent quad)
3. Fridge property & maintenance decals (transparent quads)
4. Hidden anomaly seal (underside quad)
5. Seamless low-contrast institutional floor tile
6. PDA watermark and quantum diagnostic icon
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
STAGING_DIR = REPO_ROOT / "game_godot" / "assets" / "staging" / "borrowed_visuals"
FPS_DIR = REPO_ROOT / "game_godot" / "assets" / "fps"


def ensure_dirs() -> None:
    (FPS_DIR / "actors").mkdir(parents=True, exist_ok=True)
    (FPS_DIR / "materials").mkdir(parents=True, exist_ok=True)
    (FPS_DIR / "props").mkdir(parents=True, exist_ok=True)


def load_staged(name: str) -> Image.Image:
    p_derived = STAGING_DIR / "derived" / name
    if p_derived.exists():
        return Image.open(p_derived).convert("RGBA")
    p_orig = STAGING_DIR / "originals" / name
    if p_orig.exists():
        return Image.open(p_orig).convert("RGBA")
    raise FileNotFoundError(f"Staged asset not found: {name}")


def create_wetberry_front_decal() -> Image.Image:
    """256x256 transparent QuadMesh front decal for Wetberry carton."""
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Frame
    draw.rectangle([10, 10, 245, 245], outline=(190, 25, 45, 255), width=3)
    draw.rectangle([14, 14, 241, 241], outline=(220, 180, 180, 200), width=1)

    # Brand banner
    draw.rectangle([20, 20, 235, 55], fill=(190, 25, 45, 255))
    draw.text((128, 37), "W E T B E R R Y", fill=(255, 255, 255, 255), anchor="mm")

    # Central Strawberry Glyph with eerie eye
    cx, cy = 128, 125
    draw.polygon([
        (cx, cy + 45),
        (cx - 38, cy + 20),
        (cx - 45, cy - 15),
        (cx - 24, cy - 38),
        (cx, cy - 30),
        (cx + 24, cy - 38),
        (cx + 45, cy - 15),
        (cx + 38, cy + 20),
    ], fill=(225, 30, 60, 255), outline=(140, 15, 30, 255))

    # Strawberry leaves
    draw.polygon([
        (cx, cy - 32),
        (cx - 18, cy - 48),
        (cx - 5, cy - 35),
        (cx, cy - 52),
        (cx + 5, cy - 35),
        (cx + 18, cy - 48),
    ], fill=(45, 160, 65, 255))

    # Eye inside strawberry
    draw.ellipse([cx - 20, cy - 12, cx + 20, cy + 10], fill=(255, 255, 255, 255), outline=(100, 10, 20, 255), width=2)
    draw.ellipse([cx - 9, cy - 8, cx + 9, cy + 6], fill=(20, 20, 20, 255))
    draw.ellipse([cx - 4, cy - 6, cx + 1, cy - 2], fill=(255, 255, 255, 255))

    # Warning text at bottom
    draw.rectangle([20, 185, 235, 210], fill=(255, 240, 200, 255), outline=(180, 120, 20, 255), width=1)
    draw.text((128, 197), "DO NOT OBSERVE", fill=(140, 30, 10, 255), anchor="mm")

    draw.text((128, 228), "HOMOGENIZED QUANTUM", fill=(80, 20, 30, 255), anchor="mm")

    return img


def create_keith_name_badge() -> Image.Image:
    """128x64 transparent name badge decal for Keith."""
    img = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle([4, 4, 123, 59], radius=6, fill=(245, 245, 235, 255), outline=(241, 196, 79, 255), width=3)
    draw.rectangle([10, 10, 117, 24], fill=(23, 48, 62, 255))
    draw.text((64, 17), "FACILITIES", fill=(241, 196, 79, 255), anchor="mm")
    draw.text((64, 42), "KEITH", fill=(20, 35, 45, 255), anchor="mm")

    return img


def create_fridge_property_decal() -> Image.Image:
    """256x128 property label decal for Fridge."""
    img = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rectangle([4, 4, 251, 123], fill=(240, 242, 238, 255), outline=(60, 75, 70, 255), width=2)
    draw.rectangle([8, 8, 247, 36], fill=(35, 55, 48, 255))
    draw.text((128, 22), "HIVE-LATTICE CORP", fill=(240, 245, 240, 255), anchor="mm")

    draw.text((128, 55), "PROPERTY OF FACILITY 04", fill=(30, 35, 30, 255), anchor="mm")
    draw.text((128, 75), "BREAKROOM REFRIGERATOR #2", fill=(50, 55, 50, 255), anchor="mm")
    draw.text((128, 100), "CLEAN OUT FRIDAY 5:00 PM", fill=(160, 40, 30, 255), anchor="mm")

    return img


def create_fridge_maintenance_decal() -> Image.Image:
    """128x128 maintenance warning sticker using a small snippet of staged blood/hazard asset."""
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rectangle([4, 4, 123, 123], fill=(255, 245, 210, 255), outline=(180, 40, 30, 255), width=3)
    draw.rectangle([10, 10, 117, 34], fill=(180, 40, 30, 255))
    draw.text((64, 22), "WARNING", fill=(255, 255, 255, 255), anchor="mm")

    try:
        blood_src = load_staged("blood_top_left_512.png")
        crop_blood = blood_src.crop((80, 100, 200, 220)).resize((44, 44))
        img.paste(crop_blood, (14, 44), crop_blood if crop_blood.mode == "RGBA" else None)
    except Exception as e:
        print(f"Decal crop note: {e}")

    draw.text((85, 52), "COOLANT", fill=(140, 30, 20, 255), anchor="mm")
    draw.text((85, 70), "LEAK", fill=(140, 30, 20, 255), anchor="mm")
    draw.text((64, 105), "SEC-4 MAINT", fill=(60, 60, 60, 255), anchor="mm")

    return img


def create_floor_tile_texture() -> Image.Image:
    """128x128 seamless low-contrast institutional gray-green floor tile."""
    img = Image.new("RGBA", (128, 128), (56, 68, 64, 255))
    draw = ImageDraw.Draw(img)

    # Subtle inner bevel
    draw.rectangle([0, 0, 127, 127], outline=(40, 48, 46, 255), width=2)
    draw.rectangle([2, 2, 125, 125], outline=(72, 84, 80, 255), width=1)
    draw.rectangle([4, 4, 123, 123], fill=(54, 66, 62, 255))

    # Subtle mottled grain
    for y in range(4, 124, 8):
        for x in range(4, 124, 8):
            v = 54 + ((x * 7 + y * 13) % 9) - 4
            draw.rectangle([x, y, x + 7, y + 7], fill=(v, v + 12, v + 8, 255))

    return img


def create_hidden_anomaly_plate() -> Image.Image:
    """256x256 hidden anomaly seal under the central table using Frog Sigil."""
    try:
        sigil = load_staged("Frog_of_Endless_Eons_Sigil_512.png").resize((256, 256)).convert("RGBA")
        draw = ImageDraw.Draw(sigil)
        draw.ellipse([4, 4, 251, 251], outline=(241, 196, 79, 220), width=4)
        draw.ellipse([10, 10, 245, 245], outline=(160, 120, 30, 180), width=2)
        return sigil
    except Exception as e:
        plate = Image.new("RGBA", (256, 256), (20, 30, 40, 255))
        draw = ImageDraw.Draw(plate)
        draw.ellipse([10, 10, 245, 245], outline=(241, 196, 79, 255), width=4)
        return plate


def create_pda_watermark() -> Image.Image:
    """Arkheo watermark for PDA with conservative ~12% alpha for crisp text readability."""
    try:
        glyph = load_staged("berktoung__json__ARKHEOPANTHEOCHIVE_MASTER_json_berk_txt.berktoung_512.png")
        glyph = glyph.resize((512, 512)).convert("RGBA")
        r, g, b, a = glyph.split()
        a = a.point(lambda p: int(p * 0.12))
        mint_img = Image.new("RGBA", (512, 512), (79, 224, 128, 255))
        mint_img.putalpha(a)
        return mint_img
    except Exception as e:
        wm = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        return wm


def create_quantum_glyph_icon() -> Image.Image:
    """Crisp quantum diagnostic icon."""
    try:
        icon = load_staged("berktoung__json__ARKHEOPANTHEOCHIVE_MASTER_json_berk_txt.dockerglyph_512.png")
        return icon.resize((64, 64)).convert("RGBA")
    except Exception as e:
        ic = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        return ic


def create_fridge_ooze_decal() -> Image.Image:
    """256x256 contaminated slime/ooze decal for inside the fridge."""
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark gross slime pattern
    draw.ellipse([20, 30, 236, 210], fill=(25, 42, 28, 220), outline=(15, 28, 18, 255), width=3)
    draw.ellipse([50, 60, 200, 180], fill=(38, 62, 32, 235))
    draw.ellipse([80, 80, 170, 150], fill=(55, 88, 42, 240))
    # Eerie yellow-green bio nodules
    draw.ellipse([70, 90, 105, 125], fill=(95, 130, 40, 245), outline=(40, 60, 20, 255))
    draw.ellipse([140, 110, 185, 145], fill=(110, 145, 45, 245), outline=(40, 60, 20, 255))
    draw.ellipse([110, 140, 135, 165], fill=(80, 115, 35, 245))

    # Splatter drops
    drops = [(30, 190), (45, 220), (120, 230), (180, 220), (215, 195), (225, 130), (40, 50)]
    for dx, dy in drops:
        draw.ellipse([dx - 8, dy - 8, dx + 8, dy + 8], fill=(30, 50, 26, 230))

    return img


def main() -> int:
    ensure_dirs()
    print("Generating clean decals and tiled textures...")

    # Props decals
    create_wetberry_front_decal().save(FPS_DIR / "props" / "wetberry_front_decal.png")
    print("  [OK] props/wetberry_front_decal.png")

    create_fridge_property_decal().save(FPS_DIR / "props" / "fridge_property_decal.png")
    print("  [OK] props/fridge_property_decal.png")

    create_fridge_maintenance_decal().save(FPS_DIR / "props" / "fridge_maintenance_decal.png")
    print("  [OK] props/fridge_maintenance_decal.png")

    create_fridge_ooze_decal().save(FPS_DIR / "props" / "fridge_ooze_decal.png")
    print("  [OK] props/fridge_ooze_decal.png")

    create_hidden_anomaly_plate().save(FPS_DIR / "props" / "hidden_anomaly_plate_256.png")
    print("  [OK] props/hidden_anomaly_plate_256.png")

    # Actors decals
    create_keith_name_badge().save(FPS_DIR / "actors" / "keith_name_badge.png")
    print("  [OK] actors/keith_name_badge.png")

    # Materials
    create_floor_tile_texture().save(FPS_DIR / "materials" / "breakroom_floor_tile.png")
    print("  [OK] materials/breakroom_floor_tile.png")

    create_pda_watermark().save(FPS_DIR / "materials" / "pda_arkheo_watermark.png")
    print("  [OK] materials/pda_arkheo_watermark.png")

    create_quantum_glyph_icon().save(FPS_DIR / "materials" / "quantum_glyph_icon.png")
    print("  [OK] materials/quantum_glyph_icon.png")

    print("[SUCCESS] All decals and materials generated successfully!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
