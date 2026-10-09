"""Generate deterministic game-only barrel explosion PCM asset (no external assets)."""
from pathlib import Path
import math, random, struct, wave
dest=Path(__file__).resolve().parents[1]/"assets"/"audio"/"explosion.wav"
dest.parent.mkdir(parents=True,exist_ok=True)
rate=22050
duration=.67
rng=random.Random(20231009)
phase=0.0
samples=[]
for index in range(int(rate*duration)):
    t=index/rate
    envelope=max(0.0,1.0-t/duration)**2.3 * min(1.0,t/.008)
    pitch=75.0-38.0*(t/duration)
    phase+=2*math.pi*pitch/rate
    low=math.sin(phase)*.76
    crunch=(rng.random()*2-1)*.42
    value=max(-1,min(1,(low+crunch)*envelope))
    samples.append(struct.pack("<h",int(value*23000)))
with wave.open(str(dest),"wb") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(rate)
    wf.writeframes(b"".join(samples))
print("GENERATED",dest,dest.stat().st_size)
