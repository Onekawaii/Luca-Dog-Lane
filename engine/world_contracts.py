"""Versioned Action → Event → Presentation contracts for v0.7 development."""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Mapping, Optional


@dataclass(frozen=True)
class GameAction:
    kind: str
    target_id: Optional[str] = None
    x: Optional[float] = None
    y: Optional[float] = None
    payload: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_mapping(cls, data: Mapping[str, Any]) -> "GameAction":
        return cls(
            kind=str(data.get("kind", "")).strip(),
            target_id=(str(data["target_id"]).strip() if data.get("target_id") else None),
            x=(float(data["x"]) if data.get("x") is not None else None),
            y=(float(data["y"]) if data.get("y") is not None else None),
            payload=dict(data.get("payload", {})),
        )


@dataclass(frozen=True)
class GameEvent:
    kind: str
    turn: int
    actor_id: Optional[str] = None
    target_id: Optional[str] = None
    data: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class PresentationSnapshot:
    schema: str
    world: Dict[str, Any]
    player: Dict[str, Any]
    entities: List[Dict[str, Any]]
    hotspots: List[Dict[str, Any]]
    nearby: List[Dict[str, Any]]
    ambient_fx: List[Dict[str, Any]] = field(default_factory=list)
    audio_cues: List[Dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)
