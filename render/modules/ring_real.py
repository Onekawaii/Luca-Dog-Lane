from __future__ import annotations

import math
import torch

from render.core.types import RenderParams
from render.styles.presets import apply_style


def _rotated_local_grids(params: RenderParams, size: int, device: str):
    ys = torch.linspace(0, size - 1, size, device=device)
    xs = torch.linspace(0, size - 1, size, device=device)
    y, x = torch.meshgrid(ys, xs, indexing="ij")

    angle = torch.tensor(params.rotation * math.pi / 180.0, device=device)
    cos_a, sin_a = torch.cos(angle), torch.sin(angle)

    dx0 = x - params.cx
    dy0 = y - params.cy
    lx = dx0 * cos_a + dy0 * sin_a
    ly = -dx0 * sin_a + dy0 * cos_a
    return x, y, lx, ly


def _rect_sdf(lx: torch.Tensor, ly: torch.Tensor, half_w: float, half_h: float) -> torch.Tensor:
    qx = torch.abs(lx) - half_w
    qy = torch.abs(ly) - half_h
    outside = torch.sqrt(torch.clamp(qx, min=0.0) ** 2 + torch.clamp(qy, min=0.0) ** 2 + 1e-8)
    inside = torch.clamp(torch.maximum(qx, qy), max=0.0)
    return outside + inside


def build_ring_buffers(params: RenderParams, size: int = 256, device: str = "cpu") -> dict:
    x, y, lx, ly = _rotated_local_grids(params, size=size, device=device)

    half_w = params.width * 0.5
    half_h = params.height * 0.5
    apron = max(4.0, min(params.width, params.height) * 0.06)
    rope_step = max(5.0, min(params.width, params.height) * 0.07)
    rope_thickness = max(1.5, min(params.width, params.height) * 0.012)
    post_r = max(3.0, min(params.width, params.height) * 0.05)

    sdf_outer = _rect_sdf(lx, ly, half_w, half_h)
    sdf_inner = _rect_sdf(lx, ly, half_w - apron, half_h - apron)

    mat_mask = (sdf_inner <= 0.0).float()
    apron_mask = ((sdf_outer <= 0.0) & (sdf_inner > 0.0)).float()

    rope_mask = torch.zeros_like(mat_mask)
    for k in range(1, 4):
        hw = half_w - apron - rope_step * k
        hh = half_h - apron - rope_step * k
        if hw > 1.0 and hh > 1.0:
            rope_sdf = _rect_sdf(lx, ly, hw, hh)
            rope_mask = torch.maximum(rope_mask, (torch.abs(rope_sdf) <= rope_thickness).float())

    corner_centers = [
        (-half_w, -half_h),
        ( half_w, -half_h),
        (-half_w,  half_h),
        ( half_w,  half_h),
    ]
    post_mask = torch.zeros_like(mat_mask)
    for px, py in corner_centers:
        pr = torch.sqrt((lx - px) ** 2 + (ly - py) ** 2 + 1e-8)
        post_mask = torch.maximum(post_mask, (pr <= post_r).float())

    gx = torch.zeros_like(sdf_outer)
    gy = torch.zeros_like(sdf_outer)
    gx[:, 1:] = torch.abs(sdf_outer[:, 1:] - sdf_outer[:, :-1])
    gy[1:, :] = torch.abs(sdf_outer[1:, :] - sdf_outer[:-1, :])
    edge_map = (gx + gy).clamp(0.0, 1.0)

    norm_depth = 1.0 - torch.clamp(torch.abs(sdf_inner) / max(1.0, min(half_w, half_h)), 0.0, 1.0)
    norm_depth = norm_depth * mat_mask

    outer_dist_map = torch.clamp(torch.abs(sdf_outer) / max(1.0, apron * 2.0), 0.0, 3.0)

    damage_mask = mat_mask * (
        (0.5 + 0.5 * torch.sin(x * 0.09 + y * 0.07)) *
        (0.5 + 0.5 * torch.cos(x * 0.04 - y * 0.05))
    ) * params.damage

    hazard_masks: dict[str, torch.Tensor] = {}
    hazard_masks["sparks"] = (((torch.sin(x * 0.31) * torch.cos(y * 0.17)) > 0.975).float() * apron_mask)
    hazard_masks["fracture"] = (((torch.abs(torch.sin(x * 0.08 + y * 0.12)) > 0.985).float()) * (mat_mask + apron_mask).clamp(0.0, 1.0))

    return {
        "mat_mask": mat_mask,
        "apron_mask": apron_mask,
        "rope_mask": rope_mask,
        "post_mask": post_mask,
        "edge_map": edge_map,
        "depth_map": norm_depth,
        "outer_dist_map": outer_dist_map,
        "damage_mask": damage_mask,
        "hazard_masks": hazard_masks,
    }


def render_ring(params: RenderParams, size: int = 256, device: str = "cpu") -> torch.Tensor:
    buffers = build_ring_buffers(params=params, size=size, device=device)
    return apply_style(
        buffers=buffers,
        style=params.style,
        faction_control=params.faction_control,
        crowd_heat=params.crowd_heat,
        hazards=params.hazards,
    )
