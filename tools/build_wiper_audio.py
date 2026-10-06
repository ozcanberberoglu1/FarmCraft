#!/usr/bin/env python3
"""One stroke of a windscreen wiper (VehicleWipers; Audio set "wiper"): synthesised, no source.

Rubber drawn over wet glass: a soft, breathy sweep (band-passed noise that swells as the
blade speeds up through the middle of its stroke and dies away as it slows), the motor
and linkage humming faintly under it, and the dull knock of the blade turning over at
the end of the stroke. Two takes (wiper_1, wiper_2) a little apart in tone.
Run: python3 tools/build_wiper_audio.py  (writes art/audio/sfx/vehicle/wiper_N.wav)
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "audio", "sfx", "vehicle")


def band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    sos = signal.butter(2, [lo, hi], btype="band", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def take(seed: int, tone: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    dur = 0.62
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    u = t / dur
    # The blade's speed over the stroke: nothing at either end, most in the middle.
    speed = np.sin(np.pi * u) ** 1.4
    noise = rng.normal(0, 1, n)
    sweep = band(noise, 500 * tone, 2400 * tone) * 0.8 + band(noise, 2600 * tone, 5200 * tone) * 0.25
    # Wet rubber judders very slightly.
    judder = 1.0 + 0.12 * np.sin(2 * np.pi * (38 + 6 * tone) * t + rng.uniform(0, 6.28))
    sweep *= speed * judder
    hum = (np.sin(2 * np.pi * 96 * tone * t) + 0.4 * np.sin(2 * np.pi * 192 * tone * t + 0.7)) * 0.05 * speed ** 0.5
    # The knock as it turns over.
    k0 = 0.9 * dur
    kt = np.clip(t - k0, 0, None)
    knock = np.where(t >= k0, np.sin(2 * np.pi * 115 * tone * kt) * np.exp(-kt * 42.0), 0.0) * 0.28
    knock += np.where(t >= k0, band(rng.normal(0, 1, n), 300, 1200) * np.exp(-kt * 90.0), 0.0) * 0.1
    x = sweep * 0.5 + hum + knock
    fade = np.minimum(1.0, t / 0.03) * np.minimum(1.0, (dur - t) / 0.04)
    x = np.concatenate([x * fade, np.zeros(int(0.05 * RATE))])
    return x / np.max(np.abs(x)) * 0.6


def write(path: str, x: np.ndarray) -> None:
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write(os.path.join(OUT, "wiper_1.wav"), take(11, 1.0))
    write(os.path.join(OUT, "wiper_2.wav"), take(23, 0.93))
    print("written", OUT)
