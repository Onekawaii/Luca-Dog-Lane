"""Generate deterministic low-fi breakroom interaction SFX for the Godot FPS build."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game_godot" / "assets" / "audio"
RNG = random.Random(260912)


def write_wav(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = bytearray()
        for value in samples:
            value = max(-1.0, min(1.0, value))
            frames.extend(struct.pack("<h", int(value * 32767)))
        wav.writeframes(frames)


def coffee_switch() -> list[float]:
    total = int(RATE * 0.28)
    data: list[float] = []
    for i in range(total):
        t = i / RATE
        click = math.sin(2 * math.pi * 920 * t) * math.exp(-t * 45.0)
        thunk = math.sin(2 * math.pi * 105 * t) * math.exp(-t * 18.0)
        data.append(click * 0.28 + thunk * 0.42)
    return data


def coffee_brew() -> list[float]:
    total = int(RATE * 1.15)
    data: list[float] = []
    for i in range(total):
        t = i / RATE
        env = min(1.0, t * 8.0) * max(0.0, 1.0 - t / 1.15)
        motor = math.sin(2 * math.pi * 74 * t) * 0.17
        burble = math.sin(2 * math.pi * (31 + 8 * math.sin(t * 14)) * t) * 0.12
        noise = (RNG.random() * 2.0 - 1.0) * 0.025
        data.append((motor + burble + noise) * env)
    return data


def fridge_hinge() -> list[float]:
    total = int(RATE * 0.72)
    data: list[float] = []
    for i in range(total):
        t = i / RATE
        env = math.sin(min(1.0, t / 0.72) * math.pi)
        groan_freq = 82.0 - 24.0 * (t / 0.72)
        groan = math.sin(2 * math.pi * groan_freq * t) * 0.23
        rasp = (RNG.random() * 2.0 - 1.0) * 0.05 * math.sin(math.pi * t / 0.72)
        latch = math.sin(2 * math.pi * 180 * t) * math.exp(-max(0.0, t - 0.55) * 38.0) if t > 0.55 else 0.0
        data.append((groan + rasp) * env + latch * 0.10)
    return data


def main() -> None:
    write_wav("coffee_switch.wav", coffee_switch())
    write_wav("coffee_brew.wav", coffee_brew())
    write_wav("fridge_hinge.wav", fridge_hinge())
    print("Generated deterministic breakroom interaction SFX in", OUT)


if __name__ == "__main__":
    main()
