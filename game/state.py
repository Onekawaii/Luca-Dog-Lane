from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List


@dataclass(frozen=True)
class ArenaState:
    arena_id: str
    screen_x: float
    screen_y: float
    ring_width: float
    ring_height: float
    rotation_deg: float = 0.0
    damage: float = 0.0
    crowd_heat: float = 0.0
    faction_control: str = "neutral"
    match_phase: str = "idle"
    hazards: List[str] = field(default_factory=list)
    forced_style: str | None = None


@dataclass
class WorldState:
    arenas: Dict[str, ArenaState] = field(default_factory=dict)


def build_demo_world() -> WorldState:
    return WorldState(
        arenas={
            "arena_alpha": ArenaState(
                arena_id="arena_alpha",
                screen_x=128.0,
                screen_y=128.0,
                ring_width=120.0,
                ring_height=88.0,
                rotation_deg=12.0,
                damage=0.25,
                crowd_heat=0.70,
                faction_control="solar",
                match_phase="broadcast",
                hazards=["sparks", "fracture"],
                forced_style=None,
            )
        }
    )
