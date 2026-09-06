from __future__ import annotations

import torch


def to_3ch(x: torch.Tensor) -> torch.Tensor:
    return x.unsqueeze(0).repeat(3, 1, 1)


def apply_shadow(img: torch.Tensor, depth_map: torch.Tensor, strength: float = 0.18) -> torch.Tensor:
    shadow = (1.0 - depth_map.clamp(0.0, 1.0)) * strength
    return (img - to_3ch(shadow)).clamp(0.0, 1.0)


def apply_outline(img: torch.Tensor, edge_map: torch.Tensor, color=(1.0, 1.0, 1.0), threshold: float = 0.08) -> torch.Tensor:
    mask = (edge_map > threshold).float()
    color_t = torch.tensor(color, device=img.device, dtype=img.dtype).view(3, 1, 1)
    return (img * (1.0 - to_3ch(mask)) + color_t * to_3ch(mask)).clamp(0.0, 1.0)


def apply_glow(img: torch.Tensor, dist_map: torch.Tensor, intensity: float = 0.2, color=(1.0, 0.4, 0.4)) -> torch.Tensor:
    glow = torch.exp(-((dist_map - 1.0) ** 2) * 9.0) * intensity
    color_t = torch.tensor(color, device=img.device, dtype=img.dtype).view(3, 1, 1)
    return (img + to_3ch(glow) * color_t).clamp(0.0, 1.0)


def apply_scanlines(img: torch.Tensor, spacing: int = 4, alpha: float = 0.08) -> torch.Tensor:
    h, w = img.shape[1], img.shape[2]
    lines = torch.ones(h, w, device=img.device, dtype=img.dtype)
    lines[::spacing, :] = 1.0 - alpha
    return (img * to_3ch(lines)).clamp(0.0, 1.0)


def apply_posterize(img: torch.Tensor, levels: int = 6) -> torch.Tensor:
    return (torch.round(img * levels) / levels).clamp(0.0, 1.0)


def add_hazard_overlays(img: torch.Tensor, hazard_masks: dict[str, torch.Tensor]) -> torch.Tensor:
    out = img.clone()
    if "sparks" in hazard_masks:
        sparks = hazard_masks["sparks"]
        out[0] = (out[0] + sparks * 0.8).clamp(0.0, 1.0)
        out[1] = (out[1] + sparks * 0.4).clamp(0.0, 1.0)
    if "fracture" in hazard_masks:
        fracture = hazard_masks["fracture"]
        out = apply_outline(out, fracture, color=(0.85, 0.95, 1.0), threshold=0.02)
    return out.clamp(0.0, 1.0)
