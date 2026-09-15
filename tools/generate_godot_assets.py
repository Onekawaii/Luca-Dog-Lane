#!/usr/bin/env python3
"""Generate dedicated native illustrated/pixel-art game assets for Godot 4 Hive-Lattice client.

Generates:
- High-res & retro illustrated room backgrounds and layers for Breakroom
- Character sprites with explicit foot anchors: Keith, Darla, Tammy, Player
- Prop sprites: Central Table, Wetberry (idle & pulsing), Mop Bucket, Coffee Machine, Microwave, Vending Machine
- UI frames: Dialogue bubble, portrait frames, choice button textures, inventory bar & item slot frames, cursors
- Item icons: Evidence bag, bagged wetberry, damp napkin, tokens, etc.
- Sound synthesizers/placeholders for native offline audio: hum, click, pulse, bag zip, footsteps.
"""

from __future__ import annotations

import io
import json
import math
import os
import sys
import wave
from pathlib import Path

# Ensure repository root is on sys.path
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from PIL import Image, ImageDraw, ImageFont, ImageFilter


def ensure_dirs(base: Path) -> None:
    for sub in [
        "rooms",
        "actors",
        "portraits",
        "items",
        "props",
        "ui",
        "audio",
    ]:
        (base / sub).mkdir(parents=True, exist_ok=True)


def draw_player_sprite(width: int = 128, height: int = 192) -> Image.Image:
    """Generate recognizable protagonist sprite. Foot anchor is at (width/2, height-8)."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = width // 2
    ground_y = height - 8

    # Shadow
    draw.ellipse([cx - 28, ground_y - 8, cx + 28, ground_y + 4], fill=(10, 12, 16, 120))

    # Shoes / Feet
    draw.rectangle([cx - 18, ground_y - 12, cx - 4, ground_y - 2], fill=(25, 28, 35, 255))
    draw.rectangle([cx + 4, ground_y - 12, cx + 18, ground_y - 2], fill=(25, 28, 35, 255))

    # Trousers (charcoal slate)
    leg_top = ground_y - 65
    draw.polygon([(cx - 20, leg_top), (cx - 4, leg_top), (cx - 4, ground_y - 10), (cx - 18, ground_y - 10)], fill=(45, 52, 64, 255), outline=(30, 35, 45, 255))
    draw.polygon([(cx + 4, leg_top), (cx + 20, leg_top), (cx + 18, ground_y - 10), (cx + 4, ground_y - 10)], fill=(45, 52, 64, 255), outline=(30, 35, 45, 255))

    # Trenchcoat / Jacket (deep cyan-navy #1f3b4d)
    torso_top = ground_y - 125
    draw.polygon([
        (cx - 26, torso_top),
        (cx + 26, torso_top),
        (cx + 28, leg_top + 15),
        (cx - 28, leg_top + 15)
    ], fill=(31, 59, 77, 255), outline=(18, 36, 48, 255), width=2)

    # Collar / Tie (cyan accent #38bdf8)
    draw.polygon([(cx - 12, torso_top), (cx + 12, torso_top), (cx, torso_top + 25)], fill=(220, 230, 240, 255))
    draw.polygon([(cx - 4, torso_top + 15), (cx + 4, torso_top + 15), (cx + 3, torso_top + 45), (cx - 3, torso_top + 45)], fill=(56, 189, 248, 255))

    # Head & Neck
    head_cy = torso_top - 24
    draw.rectangle([cx - 8, torso_top - 8, cx + 8, torso_top + 4], fill=(205, 155, 120, 255))
    draw.ellipse([cx - 20, head_cy - 24, cx + 20, head_cy + 16], fill=(225, 175, 135, 255), outline=(155, 110, 80, 255), width=2)

    # Hair (dark disheveled office hair)
    draw.polygon([
        (cx - 22, head_cy - 12),
        (cx - 24, head_cy - 28),
        (cx - 10, head_cy - 34),
        (cx + 14, head_cy - 34),
        (cx + 24, head_cy - 26),
        (cx + 22, head_cy - 10),
        (cx + 16, head_cy - 18),
        (cx - 2, head_cy - 16),
        (cx - 18, head_cy - 18),
    ], fill=(40, 32, 28, 255))

    # Eyes & subtle expression
    draw.line([cx - 12, head_cy - 4, cx - 4, head_cy - 4], fill=(30, 25, 25, 255), width=2)
    draw.line([cx + 4, head_cy - 4, cx + 12, head_cy - 4], fill=(30, 25, 25, 255), width=2)
    draw.line([cx - 4, head_cy + 8, cx + 4, head_cy + 8], fill=(120, 70, 50, 255), width=2)

    # Arms / Hands
    draw.polygon([(cx - 26, torso_top + 8), (cx - 34, torso_top + 45), (cx - 26, torso_top + 55), (cx - 20, torso_top + 20)], fill=(26, 48, 64, 255))
    draw.ellipse([cx - 35, torso_top + 52, cx - 25, torso_top + 64], fill=(225, 175, 135, 255))

    draw.polygon([(cx + 26, torso_top + 8), (cx + 34, torso_top + 45), (cx + 26, torso_top + 55), (cx + 20, torso_top + 20)], fill=(26, 48, 64, 255))
    draw.ellipse([cx + 25, torso_top + 52, cx + 35, torso_top + 64], fill=(225, 175, 135, 255))

    return img


def draw_keith_sprite(width: int = 140, height: int = 192) -> Image.Image:
    """Generate Keith the Janitor sprite. Foot anchor is at (width/2, height-8)."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = width // 2 - 8
    ground_y = height - 8

    # Shadow
    draw.ellipse([cx - 32, ground_y - 8, cx + 32, ground_y + 4], fill=(10, 12, 16, 120))

    # Mop Pole leaning beside him
    mop_x = cx + 34
    draw.line([mop_x, ground_y - 4, mop_x - 14, ground_y - 150], fill=(180, 140, 80, 255), width=4)
    draw.polygon([(mop_x - 6, ground_y - 4), (mop_x + 10, ground_y - 4), (mop_x + 4, ground_y - 24), (mop_x - 4, ground_y - 24)], fill=(190, 195, 205, 255))

    # Heavy Janitor Boots
    draw.rectangle([cx - 22, ground_y - 16, cx - 6, ground_y - 2], fill=(35, 25, 20, 255), outline=(15, 10, 5, 255), width=2)
    draw.rectangle([cx + 2, ground_y - 16, cx + 18, ground_y - 2], fill=(35, 25, 20, 255), outline=(15, 10, 5, 255), width=2)

    # Heavy Denim/Workwear Trousers (#173746)
    leg_top = ground_y - 62
    draw.polygon([(cx - 24, leg_top), (cx - 4, leg_top), (cx - 6, ground_y - 14), (cx - 22, ground_y - 14)], fill=(23, 55, 70, 255), outline=(14, 34, 45, 255), width=2)
    draw.polygon([(cx + 4, leg_top), (cx + 24, leg_top), (cx + 18, ground_y - 14), (cx + 2, ground_y - 14)], fill=(23, 55, 70, 255), outline=(14, 34, 45, 255), width=2)

    # Workshirt (#2f6678) with hunched sturdy posture
    torso_top = ground_y - 120
    draw.polygon([
        (cx - 28, torso_top),
        (cx + 26, torso_top),
        (cx + 24, leg_top + 10),
        (cx - 26, leg_top + 10)
    ], fill=(47, 102, 120, 255), outline=(20, 48, 58, 255), width=2)

    # Keith's Head (tired, stubble, maintenance cap)
    head_cy = torso_top - 20
    draw.rectangle([cx - 8, torso_top - 6, cx + 8, torso_top + 4], fill=(195, 145, 105, 255))
    draw.ellipse([cx - 22, head_cy - 20, cx + 22, head_cy + 18], fill=(216, 168, 124, 255), outline=(150, 105, 75, 255), width=2)

    # Stubble beard
    draw.arc([cx - 18, head_cy - 4, cx + 18, head_cy + 16], 0, 180, fill=(90, 70, 55, 255), width=5)

    # Cap (#173746 + badge #f1c44f)
    draw.polygon([(cx - 24, head_cy - 12), (cx + 24, head_cy - 12), (cx + 20, head_cy - 32), (cx - 20, head_cy - 32)], fill=(23, 55, 70, 255), outline=(12, 30, 40, 255), width=2)
    draw.polygon([(cx - 26, head_cy - 12), (cx + 28, head_cy - 12), (cx + 34, head_cy - 6), (cx - 22, head_cy - 6)], fill=(14, 34, 45, 255))
    draw.rectangle([cx - 6, head_cy - 26, cx + 6, head_cy - 18], fill=(241, 196, 79, 255))

    # Exhausted eyes
    draw.line([cx - 16, head_cy - 4, cx - 6, head_cy - 2], fill=(60, 40, 30, 255), width=2)
    draw.line([cx + 6, head_cy - 2, cx + 16, head_cy - 4], fill=(60, 40, 30, 255), width=2)

    # Arms: Left arm resting with Evidence Bag (#f1c44f / red label)
    draw.polygon([(cx - 28, torso_top + 6), (cx - 36, torso_top + 40), (cx - 24, torso_top + 52), (cx - 18, torso_top + 18)], fill=(38, 85, 100, 255))
    # Evidence bag held in left hand
    bag_x, bag_y = cx - 44, torso_top + 46
    draw.rectangle([bag_x, bag_y, bag_x + 22, bag_y + 28], fill=(220, 235, 245, 200), outline=(160, 200, 230, 255), width=1)
    draw.rectangle([bag_x, bag_y, bag_x + 22, bag_y + 5], fill=(180, 40, 40, 255))

    # Right arm holding mop
    draw.polygon([(cx + 24, torso_top + 6), (cx + 36, torso_top + 35), (cx + 30, torso_top + 45), (cx + 18, torso_top + 16)], fill=(38, 85, 100, 255))
    draw.ellipse([cx + 30, torso_top + 38, cx + 38, torso_top + 48], fill=(216, 168, 124, 255))

    return img


def draw_darla_sprite(width: int = 128, height: int = 192) -> Image.Image:
    """Generate Darla of the Microwave sprite. Foot anchor is at (width/2, height-8)."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = width // 2
    ground_y = height - 8

    # Shadow
    draw.ellipse([cx - 26, ground_y - 8, cx + 26, ground_y + 4], fill=(10, 12, 16, 120))

    # Shoes (sensible office flats)
    draw.rectangle([cx - 16, ground_y - 10, cx - 4, ground_y - 2], fill=(45, 20, 35, 255))
    draw.rectangle([cx + 4, ground_y - 10, cx + 16, ground_y - 2], fill=(45, 20, 35, 255))

    # Skirt / Trousers (#3c2644)
    skirt_top = ground_y - 68
    draw.polygon([(cx - 20, skirt_top), (cx + 20, skirt_top), (cx + 24, ground_y - 8), (cx - 24, ground_y - 8)], fill=(60, 38, 68, 255), outline=(35, 20, 40, 255), width=2)

    # Cardigan (#7f4b86)
    torso_top = ground_y - 122
    draw.polygon([
        (cx - 24, torso_top),
        (cx + 24, torso_top),
        (cx + 22, skirt_top + 8),
        (cx - 22, skirt_top + 8)
    ], fill=(127, 75, 134, 255), outline=(80, 45, 85, 255), width=2)

    # Blouse collar
    draw.polygon([(cx - 10, torso_top), (cx + 10, torso_top), (cx, torso_top + 20)], fill=(240, 220, 235, 255))

    # Head & Distinctive voluminous hair
    head_cy = torso_top - 20
    # Back hair
    draw.ellipse([cx - 26, head_cy - 28, cx + 26, head_cy + 16], fill=(45, 30, 25, 255))
    # Face
    draw.ellipse([cx - 18, head_cy - 18, cx + 18, head_cy + 16], fill=(201, 143, 103, 255), outline=(150, 95, 65, 255), width=2)
    # Front hair curls
    draw.arc([cx - 24, head_cy - 28, cx + 24, head_cy - 8], 180, 360, fill=(45, 30, 25, 255), width=8)

    # Side-eye expression
    eye_y = head_cy - 2
    draw.ellipse([cx - 14, eye_y - 3, cx - 6, eye_y + 3], fill=(245, 245, 245, 255))
    draw.ellipse([cx + 6, eye_y - 3, cx + 14, eye_y + 3], fill=(245, 245, 245, 255))
    # Pupils looking sideways towards player/microwave
    draw.ellipse([cx - 10, eye_y - 2, cx - 7, eye_y + 2], fill=(30, 20, 35, 255))
    draw.ellipse([cx + 10, eye_y - 2, cx + 13, eye_y + 2], fill=(30, 20, 35, 255))

    # Smirk
    draw.arc([cx - 8, head_cy + 6, cx + 8, head_cy + 12], 0, 180, fill=(140, 50, 60, 255), width=2)

    # Arms: Holding orange Coffee Mug (#ef8f4d)
    draw.polygon([(cx - 22, torso_top + 8), (cx - 28, torso_top + 38), (cx - 10, torso_top + 46), (cx - 12, torso_top + 20)], fill=(110, 60, 115, 255))
    draw.polygon([(cx + 22, torso_top + 8), (cx + 28, torso_top + 38), (cx + 10, torso_top + 46), (cx + 12, torso_top + 20)], fill=(110, 60, 115, 255))

    # Mug
    mug_x, mug_y = cx - 10, torso_top + 38
    draw.rectangle([mug_x, mug_y, mug_x + 20, mug_y + 22], fill=(239, 143, 77, 255), outline=(180, 90, 40, 255), width=2)
    draw.arc([mug_x + 16, mug_y + 4, mug_x + 24, mug_y + 16], 270, 90, fill=(239, 143, 77, 255), width=2)

    return img


def draw_tammy_sprite(width: int = 128, height: int = 192) -> Image.Image:
    """Generate Tammy from HR sprite. Foot anchor is at (width/2, height-8)."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = width // 2
    ground_y = height - 8

    # Shadow
    draw.ellipse([cx - 26, ground_y - 8, cx + 26, ground_y + 4], fill=(10, 12, 16, 120))

    # Heels / Shoes
    draw.rectangle([cx - 16, ground_y - 12, cx - 4, ground_y - 2], fill=(30, 15, 20, 255))
    draw.rectangle([cx + 4, ground_y - 12, cx + 16, ground_y - 2], fill=(30, 15, 20, 255))

    # Skirt (#402034)
    skirt_top = ground_y - 70
    draw.polygon([(cx - 18, skirt_top), (cx + 18, skirt_top), (cx + 20, ground_y - 10), (cx - 20, ground_y - 10)], fill=(64, 32, 52, 255), outline=(40, 20, 32, 255), width=2)

    # HR Blazer (#8e365d)
    torso_top = ground_y - 126
    draw.polygon([
        (cx - 24, torso_top),
        (cx + 24, torso_top),
        (cx + 22, skirt_top + 6),
        (cx - 22, skirt_top + 6)
    ], fill=(142, 54, 93, 255), outline=(90, 30, 58, 255), width=2)

    # Cream blouse (#e8e0ce)
    draw.polygon([(cx - 10, torso_top), (cx + 10, torso_top), (cx, torso_top + 24)], fill=(232, 224, 206, 255))

    # Head & Angular Hair
    head_cy = torso_top - 20
    draw.polygon([
        (cx - 24, head_cy - 28),
        (cx + 24, head_cy - 28),
        (cx + 26, head_cy + 8),
        (cx - 26, head_cy + 8)
    ], fill=(35, 20, 28, 255))
    draw.polygon([
        (cx - 16, head_cy - 16),
        (cx + 16, head_cy - 16),
        (cx + 12, head_cy + 16),
        (cx, head_cy + 22),
        (cx - 12, head_cy + 16)
    ], fill=(224, 173, 134, 255), outline=(160, 110, 80, 255), width=2)

    # Glasses & Procedural Stare
    glass_y = head_cy - 4
    draw.rectangle([cx - 14, glass_y - 4, cx - 3, glass_y + 4], outline=(180, 30, 60, 255), width=2)
    draw.rectangle([cx + 3, glass_y - 4, cx + 14, glass_y + 4], outline=(180, 30, 60, 255), width=2)
    draw.line([cx - 3, glass_y, cx + 3, glass_y], fill=(180, 30, 60, 255), width=2)
    draw.ellipse([cx - 10, glass_y - 2, cx - 6, glass_y + 2], fill=(20, 20, 20, 255))
    draw.ellipse([cx + 6, glass_y - 2, cx + 10, glass_y + 2], fill=(20, 20, 20, 255))

    # Compressed flat mouth
    draw.line([cx - 8, head_cy + 12, cx + 8, head_cy + 12], fill=(140, 60, 75, 255), width=2)

    # Arms: Left arm clutching wooden clipboard with incident forms
    cb_x, cb_y = cx - 38, torso_top + 28
    draw.rectangle([cb_x, cb_y, cb_x + 26, cb_y + 36], fill=(210, 180, 140, 255), outline=(120, 90, 60, 255), width=2)
    draw.rectangle([cb_x + 3, cb_y + 4, cb_x + 23, cb_y + 32], fill=(245, 245, 240, 255))
    draw.rectangle([cb_x + 8, cb_y - 3, cb_x + 18, cb_y + 3], fill=(180, 190, 200, 255))
    # Incident report lines
    for ly in range(cb_y + 8, cb_y + 30, 4):
        draw.line([cb_x + 6, ly, cb_x + 20, ly], fill=(100, 110, 120, 255), width=1)

    return img


def draw_kevin_sprite(width: int = 128, height: int = 192) -> Image.Image:
    """Generate Kevin from Marketing sprite. Foot anchor is at (width/2, height-8)."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = width // 2
    ground_y = height - 8

    # Shadow
    draw.ellipse([cx - 26, ground_y - 8, cx + 26, ground_y + 4], fill=(10, 12, 16, 120))
    # Shoes (brown business loafers)
    draw.rectangle([cx - 16, ground_y - 12, cx - 4, ground_y - 2], fill=(60, 40, 25, 255))
    draw.rectangle([cx + 4, ground_y - 12, cx + 16, ground_y - 2], fill=(60, 40, 25, 255))

    # Trousers (beige chinos #c4b59d)
    leg_top = ground_y - 65
    draw.polygon([(cx - 20, leg_top), (cx - 4, leg_top), (cx - 4, ground_y - 10), (cx - 18, ground_y - 10)], fill=(196, 181, 157, 255), outline=(140, 125, 105, 255), width=2)
    draw.polygon([(cx + 4, leg_top), (cx + 20, leg_top), (cx + 18, ground_y - 10), (cx + 4, ground_y - 10)], fill=(196, 181, 157, 255), outline=(140, 125, 105, 255), width=2)

    # Pastel polo shirt (bright marketing salmon #e76f51)
    torso_top = ground_y - 124
    draw.polygon([(cx - 24, torso_top), (cx + 24, torso_top), (cx + 22, leg_top + 8), (cx - 22, leg_top + 8)], fill=(231, 111, 81, 255), outline=(180, 70, 45, 255), width=2)
    draw.polygon([(cx - 8, torso_top), (cx + 8, torso_top), (cx, torso_top + 16)], fill=(255, 255, 255, 255))
    # Corporate lanyard & badge
    draw.line([cx - 10, torso_top, cx, torso_top + 32], fill=(56, 189, 248, 255), width=2)
    draw.line([cx + 10, torso_top, cx, torso_top + 32], fill=(56, 189, 248, 255), width=2)
    draw.rectangle([cx - 7, torso_top + 32, cx + 7, torso_top + 48], fill=(255, 255, 255, 255), outline=(100, 100, 100, 255), width=1)
    draw.rectangle([cx - 5, torso_top + 34, cx + 5, torso_top + 40], fill=(56, 189, 248, 255))

    # Head & anxious marketing haircut (styled side-part, gelled)
    head_cy = torso_top - 20
    draw.ellipse([cx - 18, head_cy - 20, cx + 18, head_cy + 16], fill=(235, 190, 150, 255), outline=(170, 125, 85, 255), width=2)
    draw.polygon([
        (cx - 22, head_cy - 12), (cx - 22, head_cy - 26), (cx + 18, head_cy - 30),
        (cx + 24, head_cy - 14), (cx + 16, head_cy - 20), (cx - 14, head_cy - 18)
    ], fill=(90, 55, 30, 255))

    # Anxious hyper-caffeinated eyes (wide open)
    draw.ellipse([cx - 14, head_cy - 6, cx - 4, head_cy + 4], fill=(255, 255, 255, 255), outline=(100, 70, 50, 255), width=1)
    draw.ellipse([cx + 4, head_cy - 6, cx + 14, head_cy + 4], fill=(255, 255, 255, 255), outline=(100, 70, 50, 255), width=1)
    draw.ellipse([cx - 10, head_cy - 3, cx - 7, head_cy], fill=(30, 20, 10, 255))
    draw.ellipse([cx + 7, head_cy - 3, cx + 10, head_cy], fill=(30, 20, 10, 255))
    # Sweat drop
    draw.ellipse([cx + 18, head_cy - 8, cx + 22, head_cy - 2], fill=(125, 211, 252, 255))

    # Anxious tense smile
    draw.line([cx - 8, head_cy + 10, cx + 8, head_cy + 10], fill=(150, 70, 50, 255), width=2)

    # Arms holding disposable paper coffee cup (double-cupped)
    cup_x, cup_y = cx - 10, torso_top + 32
    draw.polygon([(cup_x, cup_y), (cup_x + 20, cup_y), (cup_x + 16, cup_y + 26), (cup_x + 4, cup_y + 26)], fill=(245, 245, 240, 255), outline=(180, 180, 180, 255), width=1)
    draw.rectangle([cup_x + 2, cup_y + 8, cup_x + 18, cup_y + 18], fill=(180, 120, 60, 255)) # Cardboard sleeve
    return img


def create_hallway_background(width: int = 1280, height: int = 720) -> Image.Image:
    """Render 1990s-style illustrated Forgotten Hallway."""
    img = Image.new("RGBA", (width, height), (12, 15, 22, 255))
    draw = ImageDraw.Draw(img)
    wall_h = int(height * 0.48)

    draw.rectangle([0, 0, width, wall_h], fill=(20, 26, 34, 255))
    for x in range(0, width, 120):
        draw.line([x, 0, x, wall_h], fill=(30, 40, 52, 120), width=1)
    draw.rectangle([0, wall_h - 20, width, wall_h], fill=(35, 45, 58, 255))
    draw.line([0, wall_h - 20, width, wall_h - 20], fill=(55, 70, 90, 255), width=2)

    for fx in [200, 500, 800, 1100]:
        draw.rectangle([fx - 60, 20, fx + 60, 34], fill=(50, 60, 72, 255))
        draw.rectangle([fx - 50, 24, fx + 50, 30], fill=(220, 255, 245, 255))

    draw.polygon([(0, wall_h), (width, wall_h), (width, height), (0, height)], fill=(16, 20, 28, 255))
    grid_col = (28, 38, 50, 255)
    for i in range(25):
        x_top = int((i / 24) * width)
        x_bot = int(((i - 12) * 1.5 + 12) / 24 * width)
        draw.line([x_top, wall_h, x_bot, height], fill=grid_col, width=1)
    for j in range(16):
        t = (j / 15.0) ** 1.6
        y_pos = int(wall_h + t * (height - wall_h))
        draw.line([0, y_pos, width, y_pos], fill=grid_col, width=1)

    # Doors / Archways
    draw.rectangle([60, wall_h - 220, 180, wall_h], fill=(30, 38, 48, 255), outline=(50, 65, 80, 255), width=2)
    draw.rectangle([80, wall_h - 200, 160, wall_h - 20], fill=(20, 25, 32, 255))
    draw.text((85, wall_h - 235), "◄ BREAKROOM", fill=(56, 189, 248, 255))
    draw.ellipse([145, wall_h - 110, 155, wall_h - 100], fill=(241, 196, 79, 255))

    draw.rectangle([1100, wall_h - 230, 1220, wall_h], fill=(15, 20, 30, 255), outline=(60, 140, 180, 255), width=2)
    draw.text((1100, wall_h - 245), "FRIDGE LABYRINTH ►", fill=(125, 211, 252, 255))
    draw.ellipse([1080, wall_h - 80, 1240, wall_h + 40], fill=(40, 160, 220, 45))

    # Filing Cabinets
    cab_x, cab_y = 540, wall_h - 140
    draw.rectangle([cab_x, cab_y, cab_x + 200, wall_h], fill=(45, 52, 62, 255), outline=(25, 30, 38, 255), width=2)
    for row in range(4):
        ry = cab_y + 10 + row * 30
        draw.rectangle([cab_x + 10, ry, cab_x + 90, ry + 24], fill=(35, 40, 50, 255), outline=(60, 70, 85, 255), width=1)
        draw.rectangle([cab_x + 110, ry, cab_x + 190, ry + 24], fill=(35, 40, 50, 255), outline=(60, 70, 85, 255), width=1)
        draw.rectangle([cab_x + 40, ry + 8, cab_x + 60, ry + 14], fill=(200, 180, 140, 255))
        draw.rectangle([cab_x + 140, ry + 8, cab_x + 160, ry + 14], fill=(200, 180, 140, 255))

    # Water cooler
    wc_x, wc_y = 340, wall_h - 90
    draw.rectangle([wc_x, wc_y + 30, wc_x + 40, wall_h], fill=(220, 225, 235, 255), outline=(140, 150, 165, 255), width=2)
    draw.ellipse([wc_x + 5, wc_y, wc_x + 35, wc_y + 40], fill=(56, 189, 248, 160), outline=(125, 211, 252, 200), width=2)

    return img


def create_fridge_labyrinth_background(width: int = 1280, height: int = 720) -> Image.Image:
    """Render 1990s-style illustrated Fridge Labyrinth."""
    img = Image.new("RGBA", (width, height), (8, 14, 24, 255))
    draw = ImageDraw.Draw(img)
    wall_h = int(height * 0.44)

    draw.rectangle([0, 0, width, wall_h], fill=(16, 28, 44, 255))
    for ix in range(0, width, 40):
        ihl = 20 + (ix % 7) * 8
        draw.polygon([(ix, 0), (ix + 20, 0), (ix + 10, ihl)], fill=(200, 240, 255, 180))

    draw.polygon([(0, wall_h), (width, wall_h), (width, height), (0, height)], fill=(14, 24, 38, 255))
    grid_col = (40, 75, 110, 200)
    for i in range(25):
        x_top = int((i / 24) * width)
        x_bot = int(((i - 12) * 1.5 + 12) / 24 * width)
        draw.line([x_top, wall_h, x_bot, height], fill=grid_col, width=1)
    for j in range(16):
        t = (j / 15.0) ** 1.6
        y_pos = int(wall_h + t * (height - wall_h))
        draw.line([0, y_pos, width, y_pos], fill=grid_col, width=1)

    # Left Door / Tunnel (to Hallway)
    draw.rectangle([60, wall_h - 200, 180, wall_h], fill=(12, 18, 28, 255), outline=(56, 189, 248, 255), width=2)
    draw.text((65, wall_h - 220), "◄ THE HALLWAY", fill=(56, 189, 248, 255))

    # Condiment Gate
    gate_x, gate_y = 560, wall_h - 160
    draw.rectangle([gate_x, gate_y, gate_x + 180, wall_h], fill=(25, 45, 68, 255), outline=(80, 160, 220, 255), width=3)
    draw.rectangle([gate_x - 45, gate_y - 30, gate_x - 5, wall_h], fill=(160, 30, 30, 255), outline=(220, 80, 80, 255), width=2)
    draw.rectangle([gate_x + 185, gate_y - 30, gate_x + 225, wall_h], fill=(200, 160, 30, 255), outline=(240, 210, 80, 255), width=2)
    draw.text((gate_x + 20, gate_y + 40), "CONDIMENT GATE", fill=(255, 255, 255, 255))
    draw.ellipse([400, wall_h - 40, 900, wall_h + 120], fill=(100, 200, 255, 40))

    return img


def draw_props(base_dir: Path) -> None:
    props_dir = base_dir / "props"

    # 1. Central Table (256x160)
    tbl = Image.new("RGBA", (280, 180), (0, 0, 0, 0))
    td = ImageDraw.Draw(tbl)
    cx, cy = 140, 90
    # Shadow
    td.ellipse([cx - 120, cy + 20, cx + 120, cy + 70], fill=(10, 12, 16, 140))
    # Table legs
    td.rectangle([cx - 70, cy + 10, cx - 55, cy + 60], fill=(30, 36, 45, 255), outline=(15, 20, 25, 255), width=2)
    td.rectangle([cx + 55, cy + 10, cx + 70, cy + 60], fill=(30, 36, 45, 255), outline=(15, 20, 25, 255), width=2)
    td.rectangle([cx - 10, cy + 15, cx + 10, cy + 65], fill=(25, 30, 40, 255), outline=(15, 20, 25, 255), width=2)
    # Table top
    td.ellipse([cx - 120, cy - 45, cx + 120, cy + 25], fill=(42, 54, 68, 255), outline=(70, 88, 110, 255), width=3)
    td.ellipse([cx - 110, cy - 40, cx + 110, cy + 18], fill=(32, 42, 54, 255))
    # Moisture puddle
    td.ellipse([cx - 38, cy - 18, cx + 38, cy + 8], fill=(255, 62, 138, 90))
    td.ellipse([cx - 24, cy - 12, cx + 24, cy + 4], fill=(255, 90, 160, 120))
    tbl.save(props_dir / "central_table.png")

    # 2. Wetberry Standalone (64x64) - Idle
    wb_idle = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wb_idle)
    # Carton body
    wd.rectangle([20, 16, 44, 52], fill=(245, 245, 240, 255), outline=(180, 180, 180, 255), width=2)
    # Gable top
    wd.polygon([(20, 16), (32, 6), (44, 16)], fill=(230, 230, 225, 255), outline=(180, 180, 180, 255), width=2)
    # Strawberry glyph
    wd.ellipse([25, 26, 39, 44], fill=(255, 40, 100, 255))
    wd.polygon([(28, 24), (32, 28), (36, 24), (32, 22)], fill=(60, 180, 80, 255))
    # Eyes on carton
    wd.ellipse([27, 30, 31, 34], fill=(255, 255, 255, 255))
    wd.ellipse([33, 30, 37, 34], fill=(255, 255, 255, 255))
    wd.ellipse([28, 31, 30, 33], fill=(20, 20, 20, 255))
    wd.ellipse([34, 31, 36, 33], fill=(20, 20, 20, 255))
    wb_idle.save(props_dir / "wetberry_idle.png")

    # 3. Wetberry Standalone (64x64) - Pulsing Glow
    wb_pulse = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    wpd = ImageDraw.Draw(wb_pulse)
    # Aura
    wpd.ellipse([6, 6, 58, 58], fill=(255, 40, 120, 45))
    wpd.ellipse([12, 12, 52, 52], fill=(255, 80, 160, 70))
    # Carton body
    wpd.rectangle([20, 16, 44, 52], fill=(255, 240, 245, 255), outline=(255, 100, 160, 255), width=2)
    wpd.polygon([(20, 16), (32, 6), (44, 16)], fill=(255, 220, 235, 255), outline=(255, 100, 160, 255), width=2)
    wpd.ellipse([25, 26, 39, 44], fill=(255, 20, 90, 255))
    wpd.polygon([(28, 24), (32, 28), (36, 24), (32, 22)], fill=(80, 220, 100, 255))
    wpd.ellipse([27, 30, 31, 34], fill=(255, 255, 255, 255))
    wpd.ellipse([33, 30, 37, 34], fill=(255, 255, 255, 255))
    wpd.ellipse([29, 31, 31, 33], fill=(200, 20, 60, 255))
    wpd.ellipse([35, 31, 37, 33], fill=(200, 20, 60, 255))
    wb_pulse.save(props_dir / "wetberry_pulse.png")

    # 4. Mop Bucket & Wet Floor Sign (128x128)
    mop_img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    md = ImageDraw.Draw(mop_img)
    # Bucket shadow
    md.ellipse([20, 90, 90, 115], fill=(10, 12, 16, 120))
    # Yellow Mop Bucket
    md.polygon([(28, 65), (78, 65), (72, 105), (34, 105)], fill=(235, 195, 45, 255), outline=(160, 130, 20, 255), width=2)
    md.ellipse([28, 58, 78, 72], fill=(210, 175, 35, 255), outline=(160, 130, 20, 255), width=2)
    # Wringer
    md.rectangle([45, 40, 75, 68], fill=(60, 65, 75, 255), outline=(30, 35, 45, 255), width=2)
    md.line([72, 45, 88, 30], fill=(180, 180, 180, 255), width=4)
    # Wet floor sign
    md.polygon([(82, 60), (114, 60), (122, 110), (74, 110)], fill=(245, 210, 30, 255), outline=(170, 140, 15, 255), width=2)
    md.polygon([(92, 70), (104, 70), (98, 92)], fill=(30, 30, 30, 255))
    mop_img.save(props_dir / "mop_bucket.png")

    # 5. Microwave & Coffee Machine (160x120)
    appliance = Image.new("RGBA", (160, 120), (0, 0, 0, 0))
    ad = ImageDraw.Draw(appliance)
    # Coffee machine (Left)
    ad.rectangle([10, 20, 60, 105], fill=(35, 40, 48, 255), outline=(20, 25, 32, 255), width=2)
    ad.rectangle([18, 55, 52, 95], fill=(20, 25, 30, 255))
    ad.ellipse([22, 62, 48, 90], fill=(210, 225, 235, 180), outline=(150, 170, 185, 220), width=2)
    ad.rectangle([24, 78, 46, 88], fill=(60, 35, 20, 240))
    ad.ellipse([32, 30, 38, 36], fill=(56, 189, 248, 255)) # Glowing light

    # Microwave (Right)
    ad.rectangle([70, 35, 150, 105], fill=(185, 195, 205, 255), outline=(100, 115, 125, 255), width=2)
    ad.rectangle([78, 45, 128, 95], fill=(25, 30, 38, 255), outline=(60, 70, 80, 255), width=2)
    ad.rectangle([132, 45, 146, 65], fill=(40, 160, 90, 255)) # Green digital timer 00:00
    ad.line([132, 75, 146, 75], fill=(80, 90, 100, 255), width=2)
    ad.line([132, 85, 146, 85], fill=(80, 90, 100, 255), width=2)
    appliance.save(props_dir / "counter_appliances.png")


def draw_ui_elements(base_dir: Path) -> None:
    ui_dir = base_dir / "ui"

    # 1. Dialogue Bubble Frame (9-slice ready, 128x128)
    bubble = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bubble)
    bd.rounded_rectangle([4, 4, 123, 123], radius=12, fill=(18, 24, 34, 240), outline=(56, 189, 248, 255), width=2)
    bd.rounded_rectangle([8, 8, 119, 119], radius=8, outline=(30, 50, 75, 180), width=1)
    bubble.save(ui_dir / "dialogue_bubble_frame.png")

    # 2. Choice Button Texture - Normal (256x48)
    btn_norm = Image.new("RGBA", (256, 48), (0, 0, 0, 0))
    bnd = ImageDraw.Draw(btn_norm)
    bnd.rounded_rectangle([2, 2, 253, 45], radius=6, fill=(24, 32, 45, 230), outline=(60, 80, 110, 255), width=2)
    bnd.line([6, 4, 250, 4], fill=(90, 120, 160, 150), width=1)
    btn_norm.save(ui_dir / "btn_choice_normal.png")

    # 3. Choice Button Texture - Hover / Focused (256x48)
    btn_hov = Image.new("RGBA", (256, 48), (0, 0, 0, 0))
    bhd = ImageDraw.Draw(btn_hov)
    bhd.rounded_rectangle([2, 2, 253, 45], radius=6, fill=(35, 52, 75, 245), outline=(56, 189, 248, 255), width=2)
    bhd.line([6, 4, 250, 4], fill=(125, 211, 252, 200), width=1)
    btn_hov.save(ui_dir / "btn_choice_hover.png")

    # 4. Inventory Dock / Bar Panel (512x80)
    dock = Image.new("RGBA", (512, 80), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dock)
    dd.rounded_rectangle([2, 2, 509, 77], radius=10, fill=(15, 20, 28, 245), outline=(45, 60, 80, 255), width=2)
    dd.line([10, 5, 502, 5], fill=(70, 95, 130, 120), width=1)
    dock.save(ui_dir / "inventory_dock.png")

    # 5. Inventory Slot Frame (64x64)
    slot = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    sd = ImageDraw.Draw(slot)
    sd.rounded_rectangle([2, 2, 61, 61], radius=6, fill=(22, 28, 38, 240), outline=(55, 75, 100, 255), width=2)
    slot.save(ui_dir / "inventory_slot.png")

    # 6. Inventory Slot Frame Armed / Active (64x64)
    slot_armed = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    sad = ImageDraw.Draw(slot_armed)
    sad.rounded_rectangle([2, 2, 61, 61], radius=6, fill=(35, 50, 70, 255), outline=(255, 62, 138, 255), width=3)
    slot_armed.save(ui_dir / "inventory_slot_armed.png")

    # 7. Reticle / Focus indicator (48x48)
    reticle = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    rd = ImageDraw.Draw(reticle)
    rd.arc([4, 4, 43, 43], 0, 360, fill=(56, 189, 248, 220), width=2)
    rd.line([24, 0, 24, 8], fill=(56, 189, 248, 255), width=2)
    rd.line([24, 40, 24, 48], fill=(56, 189, 248, 255), width=2)
    rd.line([0, 24, 8, 24], fill=(56, 189, 248, 255), width=2)
    rd.line([40, 24, 48, 24], fill=(56, 189, 248, 255), width=2)
    reticle.save(ui_dir / "target_reticle.png")


def generate_offline_audio(base_dir: Path) -> None:
    """Generate subtle procedural WAV sound effects for offline game audio."""
    audio_dir = base_dir / "audio"

    def write_wav(filename: str, samples: list[float], sample_rate: int = 22050) -> None:
        path = audio_dir / filename
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sample_rate)
            raw = bytearray()
            for s in samples:
                val = max(-32767, min(32767, int(s * 32767)))
                raw.extend(val.to_bytes(2, byteorder="little", signed=True))
            w.writeframes(raw)

    sr = 22050

    # 1. Fluorescent Hum (1.5s looping drone)
    hum_samples = []
    for i in range(int(sr * 1.5)):
        t = i / sr
        s = 0.08 * math.sin(2 * math.pi * 60 * t) + 0.04 * math.sin(2 * math.pi * 120 * t) + 0.02 * math.sin(2 * math.pi * 180 * t)
        hum_samples.append(s)
    write_wav("fluorescent_hum.wav", hum_samples, sr)

    # 2. Interaction Click (0.05s)
    click_samples = []
    for i in range(int(sr * 0.05)):
        t = i / sr
        env = math.exp(-t * 80)
        s = 0.3 * math.sin(2 * math.pi * 1200 * t) * env
        click_samples.append(s)
    write_wav("ui_click.wav", click_samples, sr)

    # 3. Item Pickup (0.14s soft paper/plastic handling)
    pickup_samples = []
    for i in range(int(sr * 0.14)):
        t = i / sr
        env = math.exp(-t * 24.0) * math.sin(math.pi * min(1.0, t / 0.14))
        texture = math.sin(2 * math.pi * 310 * t) + 0.45 * math.sin(2 * math.pi * 470 * t)
        pickup_samples.append(0.055 * texture * env)
    write_wav("item_pickup.wav", pickup_samples, sr)

    # 4. Evidence-bag zipper (0.34s: quiet friction plus zipper teeth).
    bag_zip_samples = []
    for i in range(int(sr * 0.34)):
        t = i / sr
        phase = t / 0.34
        env = math.sin(math.pi * phase) ** 0.7
        teeth = max(0.0, math.sin(2 * math.pi * 62 * t)) ** 7
        carrier = math.sin(2 * math.pi * (1250 + 700 * phase) * t)
        friction = math.sin(2 * math.pi * 1850 * t) * math.sin(2 * math.pi * 137 * t)
        bag_zip_samples.append((0.065 * teeth * carrier + 0.018 * friction) * env)
    write_wav("bag_zip.wav", bag_zip_samples, sr)

    # 5. Wetberry Pulse (0.4s eerie low hum)
    pulse_samples = []
    for i in range(int(sr * 0.4)):
        t = i / sr
        env = math.sin(math.pi * (t / 0.4))
        s = 0.35 * math.sin(2 * math.pi * 95 * t) * env
        pulse_samples.append(s)
    write_wav("wetberry_pulse.wav", pulse_samples, sr)

    # 5. Footstep (0.08s soft tap)
    step_samples = []
    for i in range(int(sr * 0.08)):
        t = i / sr
        env = math.exp(-t * 60)
        s = 0.2 * math.sin(2 * math.pi * 180 * t) * env
        step_samples.append(s)
    write_wav("footstep.wav", step_samples, sr)


def copy_source_assets(source_campaign_dir: Path, target_assets_dir: Path) -> None:
    src_generated = source_campaign_dir / "assets" / "generated"
    if not src_generated.exists():
        return

    # Copy portraits
    src_portraits = src_generated / "portraits"
    if src_portraits.exists():
        for p in src_portraits.glob("*.png"):
            dest = target_assets_dir / "portraits" / p.name
            dest.write_bytes(p.read_bytes())

    # Copy items
    src_items = src_generated / "items"
    if src_items.exists():
        for item in src_items.glob("*.png"):
            dest = target_assets_dir / "items" / item.name
            dest.write_bytes(item.read_bytes())


def main() -> int:
    base_assets = Path("game_godot/assets")
    ensure_dirs(base_assets)

    # Import existing generated portraits and item icons
    copy_source_assets(Path("campaigns/strawberry_omen"), base_assets)

    # Draw native illustrated rooms
    from tools.build_rpg_visual_assets import create_breakroom_background
    bg = create_breakroom_background(1280, 720)
    bg.save(base_assets / "rooms" / "breakroom.png")

    h_bg = create_hallway_background(1280, 720)
    h_bg.save(base_assets / "rooms" / "hallway.png")

    f_bg = create_fridge_labyrinth_background(1280, 720)
    f_bg.save(base_assets / "rooms" / "fridge_labyrinth.png")

    # Draw character sprites
    draw_player_sprite(128, 192).save(base_assets / "actors" / "player.png")
    draw_keith_sprite(140, 192).save(base_assets / "actors" / "keith.png")
    draw_darla_sprite(128, 192).save(base_assets / "actors" / "darla.png")
    draw_tammy_sprite(128, 192).save(base_assets / "actors" / "tammy.png")
    draw_kevin_sprite(128, 192).save(base_assets / "actors" / "kevin.png")

    # Draw props and UI
    draw_props(base_assets)
    draw_ui_elements(base_assets)

    # Generate offline audio
    generate_offline_audio(base_assets)

    print(f"[OK] Generated native Godot assets in {base_assets}")
    return 0


if __name__ == "__main__":
    main()
