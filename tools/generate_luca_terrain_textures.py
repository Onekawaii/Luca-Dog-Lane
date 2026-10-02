#!/usr/bin/env python3
"""Generate deterministic tileable terrain albedo tiles for Luca Dog World."""
from pathlib import Path
import math
import random

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game_godot" / "assets" / "terrain"
SIZE = 512
SEED = 6060

PALETTES = {
    "meadow_grass": ((72, 101, 45), (118, 131, 63), (42, 69, 34)),
    "forest_floor": ((67, 69, 39), (103, 86, 49), (38, 51, 31)),
    "dry_dirt": ((121, 83, 58), (157, 111, 71), (83, 57, 43)),
    "red_clay": ((129, 64, 43), (170, 89, 58), (88, 44, 35)),
    "river_mud": ((69, 70, 54), (101, 96, 67), (42, 48, 40)),
    "pale_sand": ((160, 142, 100), (196, 177, 126), (119, 104, 79)),
    "granite_rock": ((82, 85, 82), (128, 125, 113), (52, 57, 59)),
    "cold_stone": ((89, 97, 105), (139, 145, 144), (55, 64, 72)),
    "snow_grit": ((178, 186, 185), (223, 224, 214), (124, 137, 143)),
}
def tile_noise(seed: int) -> Image.Image:
    rng = random.Random(seed)
    small = 64
    img = Image.new("L", (small, small))
    pix = img.load()
    for y in range(small):
        for x in range(small):
            pix[x, y] = rng.randrange(48, 208)
    img = img.resize((SIZE, SIZE), Image.Resampling.BICUBIC)
    return img.filter(ImageFilter.GaussianBlur(radius=4.0))


def make_tile(name: str, palette, index: int) -> None:
    base, light, dark = palette
    noise = tile_noise(SEED + index * 97)
    npx = noise.load()
    out = Image.new("RGB", (SIZE, SIZE))
    opx = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            n = npx[x, y] / 255.0
            # Crossfading three earth tones keeps the tile natural instead of neon.
            if n < 0.5:
                t = n * 2.0
                a, b = dark, base
            else:
                t = (n - 0.5) * 2.0
                a, b = base, light
            rgb = tuple(int(a[c] + (b[c] - a[c]) * t) for c in range(3))
            opx[x, y] = rgb
    # Add low-contrast pebbles/fibres without destroying tiling.
    rng = random.Random(SEED + index * 991)
    for _ in range(1500):
        x = rng.randrange(SIZE)
        y = rng.randrange(SIZE)
        radius = rng.choice((1, 1, 1, 2, 3))
        strength = rng.choice((-18, -10, 8, 12))
        for oy in range(-radius, radius + 1):
            for ox in range(-radius, radius + 1):
                if ox * ox + oy * oy > radius * radius:
                    continue
                px = (x + ox) % SIZE
                py = (y + oy) % SIZE
                r, g, b = opx[px, py]
                opx[px, py] = (
                    max(0, min(255, r + strength)),
                    max(0, min(255, g + strength)),
                    max(0, min(255, b + strength)),
                )
    out.save(OUT / f"{name}.png", optimize=True)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (name, palette) in enumerate(PALETTES.items()):
        make_tile(name, palette, index)
        print(f"[TERRAIN] {name}.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
