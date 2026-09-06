from __future__ import annotations

import math
import torch

from render.core.types import RenderParams


def render_ring(params: RenderParams, size: int = 256, device: str = "cpu") -> torch.Tensor:
    ys = torch.linspace(0, size - 1, size, device=device)
    xs = torch.linspace(0, size - 1, size, device=device)
    y, x = torch.meshgrid(ys, xs, indexing="ij")

    angle = torch.tensor(params.rotation * math.pi / 180.0, device=device)
    cos_a, sin_a = torch.cos(angle), torch.sin(angle)

    dx0 = x - params.cx
    dy0 = y - params.cy
    dx = dx0 * cos_a + dy0 * sin_a
    dy = -dx0 * sin_a + dy0 * cos_a

    dist = torch.sqrt((dx / (params.width * 0.5 + 1e-6)) ** 2 + (dy / (params.height * 0.5 + 1e-6)) ** 2 + 1e-6)
    ring = (dist <= 1.0).float()
    rope = ((dist > 0.78) & (dist < 0.90)).float()
    posts = (dist < 0.12).float()

    img = torch.zeros(3, size, size, device=device)
    img[0] += ring * 0.20
    img[1] += ring * 0.45
    img[2] += ring * 0.85
    img[0] += rope * 0.70
    img[1] += rope * 0.70
    img[2] += rope * 0.75
    img[:, posts > 0.0] = 1.0

    glow = torch.exp(-((dist - 1.0) ** 2) * 10.0) * (0.12 + 0.18 * params.crowd_heat)
    img[2] = (img[2] + glow).clamp(0.0, 1.0)

    if "fracture" in params.hazards:
        img[0] = (img[0] + (torch.abs(torch.sin(x * 0.11 + y * 0.09)) > 0.98).float() * 0.35).clamp(0.0, 1.0)

    if "sparks" in params.hazards:
        img[0] = (img[0] + ((torch.sin(x * 0.31) * torch.cos(y * 0.17)) > 0.96).float() * 0.90).clamp(0.0, 1.0)
        img[1] = (img[1] + ((torch.sin(x * 0.31) * torch.cos(y * 0.17)) > 0.96).float() * 0.40).clamp(0.0, 1.0)

    return img.clamp(0.0, 1.0)
