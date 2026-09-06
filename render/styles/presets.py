from __future__ import annotations

import torch

from render.effects.basic import (
    add_hazard_overlays,
    apply_glow,
    apply_outline,
    apply_posterize,
    apply_scanlines,
    apply_shadow,
    to_3ch,
)


PALETTES = {
    "neutral": ((0.75, 0.75, 0.80), (0.90, 0.15, 0.15), (0.20, 0.20, 0.22)),
    "solar": ((0.20, 0.45, 0.95), (0.95, 0.95, 0.98), (0.12, 0.12, 0.16)),
    "void": ((0.78, 0.10, 0.56), (0.98, 0.75, 1.00), (0.05, 0.03, 0.08)),
    "steel": ((0.70, 0.60, 0.12), (0.05, 0.05, 0.05), (0.92, 0.92, 0.90)),
}


def base_from_buffers(buffers: dict, faction_control: str) -> torch.Tensor:
    ring_color, rope_color, bg_color = PALETTES.get(faction_control, PALETTES["neutral"])
    device = buffers["mat_mask"].device
    size = buffers["mat_mask"].shape[0]
    img = torch.zeros(3, size, size, device=device, dtype=torch.float32)

    bg = torch.tensor(bg_color, device=device).view(3, 1, 1)
    mat = torch.tensor(ring_color, device=device).view(3, 1, 1)
    rope = torch.tensor(rope_color, device=device).view(3, 1, 1)
    post = torch.tensor((0.92, 0.92, 0.92), device=device).view(3, 1, 1)

    img[:] = bg
    img = img * (1.0 - to_3ch(buffers["mat_mask"])) + mat * to_3ch(buffers["mat_mask"])
    img = img * (1.0 - to_3ch(buffers["rope_mask"])) + rope * to_3ch(buffers["rope_mask"])
    img = img * (1.0 - to_3ch(buffers["post_mask"])) + post * to_3ch(buffers["post_mask"])

    if buffers.get("damage_mask") is not None:
        grime = buffers["damage_mask"] * 0.25
        img = (img - to_3ch(grime)).clamp(0.0, 1.0)

    return img.clamp(0.0, 1.0)


def apply_style(buffers: dict, style: str, faction_control: str, crowd_heat: float, hazards: list[str]) -> torch.Tensor:
    img = base_from_buffers(buffers, faction_control=faction_control)

    if style == "flat":
        pass
    elif style == "neon":
        img = apply_outline(img, buffers["edge_map"], color=(1.0, 0.85, 1.0), threshold=0.05)
        img = apply_glow(img, buffers["outer_dist_map"], intensity=0.20 + 0.35 * crowd_heat, color=(1.0, 0.2, 0.75))
    elif style == "crt":
        img = apply_shadow(img, buffers["depth_map"], strength=0.22)
        img = apply_scanlines(img, spacing=3, alpha=0.10)
        img = apply_posterize(img, levels=7)
    elif style == "comic":
        img = apply_outline(img, buffers["edge_map"], color=(0.0, 0.0, 0.0), threshold=0.04)
        img = apply_posterize(img, levels=5)
    elif style == "broadcast":
        img = apply_shadow(img, buffers["depth_map"], strength=0.12)
        img = apply_scanlines(img, spacing=2, alpha=0.05)
        img = apply_glow(img, buffers["outer_dist_map"], intensity=0.06 + 0.12 * crowd_heat, color=(0.45, 0.75, 1.0))
    else:
        pass

    selected = {k: v for k, v in buffers.get("hazard_masks", {}).items() if k in hazards}
    img = add_hazard_overlays(img, selected)
    return img.clamp(0.0, 1.0)
