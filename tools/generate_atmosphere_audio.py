#!/usr/bin/env python3
"""Generate deterministic Hive-Lattice atmosphere audio using only stdlib."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game_godot" / "assets" / "audio"
RATE = 44100


def _write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wav.writeframes(frames)
    print(f"[OK] {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


def make_roomtone() -> None:
    rng = random.Random(6060)
    duration = 12.0
    total = int(RATE * duration)
    samples: list[float] = []
    for i in range(total):
        t = i / RATE
        hum = math.sin(2 * math.pi * 58.7 * t) * 0.022
        sub = math.sin(2 * math.pi * 29.35 * t + 0.7) * 0.012
        flutter = math.sin(2 * math.pi * 0.17 * t) * 0.006
        noise = (rng.random() * 2.0 - 1.0) * 0.007
        samples.append((hum + sub + flutter + noise) * 0.72)
    _write("hive_roomtone.wav", samples)


def make_waterdrop() -> None:
    duration = 1.8
    total = int(RATE * duration)
    samples: list[float] = []
    for i in range(total):
        t = i / RATE
        attack = min(1.0, t / 0.006)
        decay = math.exp(-5.2 * t)
        pitch = 1120.0 - 510.0 * min(1.0, t / 0.22)
        body = math.sin(2 * math.pi * pitch * t) * decay * attack * 0.30
        resonance = math.sin(2 * math.pi * 285.0 * t) * math.exp(-2.8 * t) * 0.11
        tail = math.sin(2 * math.pi * 92.0 * t) * math.exp(-1.55 * t) * 0.055
        samples.append(body + resonance + tail)
    _write("hive_waterdrop.wav", samples)


if __name__ == "__main__":
    make_roomtone()
    make_waterdrop()
