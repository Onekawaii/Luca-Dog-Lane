from __future__ import annotations

from game.state import WorldState
from render.core.types import RenderParams


FACTION_TO_STYLE = {
    "neutral": "flat",
    "solar": "broadcast",
    "void": "neon",
    "steel": "comic",
}

PHASE_TO_STYLE = {
    "idle": "flat",
    "training": "comic",
    "broadcast": "broadcast",
    "ritual": "neon",
    "collapse": "crt",
}


def arena_state_to_render_params(world: WorldState, arena_id: str) -> RenderParams:
    arena = world.arenas[arena_id]

    if arena.forced_style:
        style = arena.forced_style
    else:
        style = PHASE_TO_STYLE.get(
            arena.match_phase,
            FACTION_TO_STYLE.get(arena.faction_control, "flat"),
        )

    return RenderParams(
        cx=float(arena.screen_x),
        cy=float(arena.screen_y),
        width=float(arena.ring_width),
        height=float(arena.ring_height),
        rotation=float(arena.rotation_deg),
        damage=max(0.0, min(1.0, float(arena.damage))),
        crowd_heat=max(0.0, min(1.0, float(arena.crowd_heat))),
        faction_control=str(arena.faction_control),
        match_phase=str(arena.match_phase),
        hazards=list(arena.hazards),
        style=style,
    )
