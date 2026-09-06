"""Deterministic game-actor state dynamics.

This module ports the useful *mechanical* idea from the uploaded
``emotional_collapse_engine_package`` into a game-safe, dependency-free runtime.
It deliberately does not diagnose or model real people.  It tracks fictional
actor state used to drive NPC reactions, posture, dialogue and scheduling.

The eight-dimensional state and coupling matrix are source-derived from the
uploaded engine, while naming and integration are adapted for Hive-Lattice.
"""

from __future__ import annotations

import hashlib
import math
from dataclasses import dataclass, asdict
from typing import Dict, Iterable, Mapping

STATE_ORDER = (
    "activation",
    "depletion",
    "coherence",
    "fixation",
    "social_openness",
    "bodily_load",
    "memory_pressure",
    "recovery_potential",
)

# Source-derived coupling matrix from the uploaded Emotional Collapse Engine.
COUPLING_MATRIX = (
    (0.62, 0.12, -0.18, 0.22, -0.05, 0.20, 0.12, -0.10),
    (0.08, 0.76, -0.10, 0.10, -0.12, 0.26, 0.06, -0.22),
    (-0.18, -0.10, 0.80, -0.18, 0.10, -0.06, -0.10, 0.22),
    (0.18, 0.10, -0.16, 0.78, -0.08, 0.04, 0.22, -0.10),
    (-0.02, -0.10, 0.14, -0.06, 0.82, -0.08, -0.05, 0.18),
    (0.15, 0.22, -0.06, 0.04, -0.08, 0.74, 0.14, -0.12),
    (0.10, 0.06, -0.10, 0.18, -0.04, 0.12, 0.82, -0.10),
    (-0.08, -0.18, 0.20, -0.08, 0.16, -0.08, -0.06, 0.84),
)

NONLINEAR_WEIGHTS = (0.04, 0.02, -0.03, 0.03, -0.02, 0.02, 0.03, -0.03)


@dataclass(frozen=True)
class ActorState:
    activation: float = 0.10
    depletion: float = 0.10
    coherence: float = 0.40
    fixation: float = 0.10
    social_openness: float = 0.20
    bodily_load: float = 0.10
    memory_pressure: float = 0.10
    recovery_potential: float = 0.30

    def to_dict(self) -> Dict[str, float]:
        return asdict(self)

    def to_vector(self) -> tuple[float, ...]:
        return tuple(float(getattr(self, name)) for name in STATE_ORDER)

    @classmethod
    def from_mapping(cls, data: Mapping[str, float] | None) -> "ActorState":
        data = data or {}
        return cls(**{name: float(data.get(name, getattr(cls(), name))) for name in STATE_ORDER})

    @classmethod
    def from_vector(cls, values: Iterable[float]) -> "ActorState":
        return cls(**dict(zip(STATE_ORDER, values)))


DEFAULT_ACTOR_STATE = ActorState()


def collapse_pressure(state: ActorState) -> float:
    """Return a game-facing strain scalar preserved from the source model."""
    a, d, c, f, s, b, m, r = state.to_vector()
    return (
        0.60 * a
        + 0.85 * d
        + 0.70 * m
        + 0.55 * b
        + 0.45 * f
        - 0.95 * c
        - 0.75 * r
        - 0.20 * s
    )


def classify_state(state: ActorState) -> str:
    """Classify the fictional actor into a compact behavior state."""
    a, d, c, f, s, b, m, r = state.to_vector()
    pressure = collapse_pressure(state)
    if pressure < -0.4 and c > 0.5 and r > 0.4:
        return "reintegrating"
    if d > 0.9 and a < 0.0 and s < -0.2:
        return "withdrawn"
    if f > 0.8 and m > 0.8 and c < 0.1:
        return "fixated"
    if a > 0.9 and b > 0.5 and c < 0.2:
        return "agitated"
    if d > 0.5 and a < 0.1 and c < 0.2:
        return "numb"
    if pressure > 0.9:
        return "strained"
    return "steady"


def _deterministic_noise(seed: int, salt: str, index: int, scale: float) -> float:
    if scale <= 0:
        return 0.0
    digest = hashlib.sha256(f"{seed}:{salt}:{index}".encode("utf-8")).digest()
    raw = int.from_bytes(digest[:8], "big") / float(2**64 - 1)
    return (raw * 2.0 - 1.0) * scale


class ActorDynamicsEngine:
    """Pure-Python deterministic state stepper for fictional NPCs."""

    @staticmethod
    def step(
        current: Mapping[str, float] | ActorState | None,
        signal: Mapping[str, float] | None,
        *,
        seed: int,
        salt: str,
        noise_scale: float = 0.02,
    ) -> ActorState:
        state = current if isinstance(current, ActorState) else ActorState.from_mapping(current)
        x = state.to_vector()
        signal = signal or {}
        u = tuple(float(signal.get(name, 0.0)) for name in STATE_ORDER)
        out = []
        for row_index, row in enumerate(COUPLING_MATRIX):
            coupled = sum(row[col] * x[col] for col in range(len(STATE_ORDER)))
            nonlinear = math.tanh(x[row_index]) * NONLINEAR_WEIGHTS[row_index]
            noise = _deterministic_noise(seed, salt, row_index, noise_scale)
            value = coupled + u[row_index] + nonlinear + noise
            out.append(max(-2.5, min(2.5, value)))
        return ActorState.from_vector(out)

    @staticmethod
    def view(data: Mapping[str, float] | None) -> Dict[str, object]:
        state = ActorState.from_mapping(data)
        return {
            "state": state.to_dict(),
            "behavior": classify_state(state),
            "pressure": round(collapse_pressure(state), 4),
        }
