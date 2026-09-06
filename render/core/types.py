from __future__ import annotations

from dataclasses import dataclass
from typing import List


@dataclass(frozen=True)
class RenderParams:
    cx: float
    cy: float
    width: float
    height: float
    rotation: float
    damage: float
    crowd_heat: float
    faction_control: str
    match_phase: str
    hazards: List[str]
    style: str
