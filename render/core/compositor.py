from __future__ import annotations

import importlib
import os
from typing import Literal

import torch

from render.core.types import RenderParams


EngineName = Literal["temp", "real"]


def render_ring(params: RenderParams, size: int = 256, device: str = "cpu", engine: EngineName = "temp") -> torch.Tensor:
    module_name = f"render.modules.ring_{engine}"
    module = importlib.import_module(module_name)
    return module.render_ring(params=params, size=size, device=device)


def save_image_tensor(image: torch.Tensor, out_path: str) -> None:
    from PIL import Image

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    chw = image.detach().clamp(0.0, 1.0).cpu()
    hwc = (chw.permute(1, 2, 0).numpy() * 255.0).astype("uint8")
    Image.fromarray(hwc).save(out_path)
