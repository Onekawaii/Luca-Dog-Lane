"""Bridge between the Strawberry Omen campaign runtime and the frozen
Hive-Lattice ring renderer contract (game/state.py, render/*).

This is Milestone C of the renderer integration plan: the ArenaState the
renderer consumes is derived from real ModuleState (campaign stats/flags),
not from a synthetic demo world. The adapter and RenderParams contracts
are untouched -- only this bridge exists to produce a legitimate ArenaState
for the Department of Adjudication's hearing-arena scene.

Dependency note: game/state.py and render/adapters/arena_adapter.py are
torch-free (plain dataclasses), so build_arena_state_from_module() and
this module's import are always safe, even without PyTorch installed.
Only render/core/compositor.py (imported lazily inside render_arena_png)
requires torch, since it does tensor compositing. Core gameplay, saves,
and validators never depend on torch -- only the arena *image* does.

Mapping is intentionally deterministic and cheap to reason about:
  - damage         <- inverse of current health (a rough hearing takes a toll)
  - crowd_heat     <- bureaucracy + moisture_pressure pressure in the room
  - faction_control<- "solar" (procedural/orderly) if bureaucracy >= ape_chaos,
                       else "void" (chaotic/evasive)
  - match_phase    <- fixed "broadcast" (the hearing is witnessed/on record)
  - hazards        <- escalate with ape_chaos: sparks at >=3, fracture at >=6
"""
from __future__ import annotations

import io
from typing import TYPE_CHECKING

from game.state import ArenaState, WorldState
from render.adapters.arena_adapter import arena_state_to_render_params

if TYPE_CHECKING:  # pragma: no cover
    from engine.module_runtime import ModuleState

HEARING_ARENA_ID = "arena.hearing_chamber"
HEARING_ARENA_LOCATION = "location.department_of_adjudication.hearing_arena"


class RendererUnavailableError(RuntimeError):
    """Raised when the optional image-rendering stack (torch/Pillow) isn't
    installed. Callers should catch this and degrade gracefully (e.g. the
    web app returns HTTP 503 with a clear message) rather than crash."""


def is_renderer_available() -> bool:
    """Best-effort check for whether the optional renderer stack is usable,
    without raising. Cheap enough to call before offering the feature."""
    try:
        import torch  # noqa: F401
        from PIL import Image  # noqa: F401
        from render.core.compositor import render_ring  # noqa: F401
    except ImportError:
        return False
    return True


def build_arena_state_from_module(state: "ModuleState") -> ArenaState:
    """Derive a real ArenaState from live campaign stats. No synthetic values.

    This function has no torch dependency and always works, so gameplay
    logic that only needs the *state* (e.g. tests, save data, HUD text)
    never needs the renderer stack installed.
    """
    health = float(state.stats.get("health", 100))
    bureaucracy = float(state.stats.get("bureaucracy", 0))
    ape_chaos = float(state.stats.get("ape_chaos", 0))
    moisture_pressure = float(state.stats.get("moisture_pressure", 1))

    damage = max(0.0, min(1.0, 1.0 - (health / 100.0)))
    crowd_heat = max(0.0, min(1.0, (bureaucracy + moisture_pressure) / 20.0))
    faction_control = "solar" if bureaucracy >= ape_chaos else "void"

    hazards: list[str] = []
    if ape_chaos >= 3:
        hazards.append("sparks")
    if ape_chaos >= 6:
        hazards.append("fracture")

    return ArenaState(
        arena_id=HEARING_ARENA_ID,
        screen_x=128.0,
        screen_y=128.0,
        ring_width=140.0,
        ring_height=96.0,
        rotation_deg=6.0,
        damage=damage,
        crowd_heat=crowd_heat,
        faction_control=faction_control,
        match_phase="broadcast",
        hazards=hazards,
        forced_style=None,
    )


def render_arena_png(
    state: "ModuleState",
    size: int = 256,
    engine: str = "real",
    device: str = "cpu",
) -> bytes:
    """Render the current campaign state's hearing arena as PNG bytes.

    Raises RendererUnavailableError (not ImportError) if torch/Pillow
    aren't installed, so callers get one clear exception type to catch.
    """
    try:
        from PIL import Image
        from render.core.compositor import render_ring
    except ImportError as exc:
        raise RendererUnavailableError(
            "Arena renderer requires torch and Pillow, which are not installed. "
            "Core gameplay is unaffected; only the arena image is unavailable."
        ) from exc

    arena = build_arena_state_from_module(state)
    world = WorldState(arenas={arena.arena_id: arena})
    params = arena_state_to_render_params(world, arena.arena_id)
    tensor = render_ring(params, size=size, device=device, engine=engine)

    chw = tensor.detach().clamp(0.0, 1.0).cpu()
    hwc = (chw.permute(1, 2, 0).numpy() * 255.0).astype("uint8")
    image = Image.fromarray(hwc)

    buf = io.BytesIO()
    image.save(buf, format="PNG")
    return buf.getvalue()
