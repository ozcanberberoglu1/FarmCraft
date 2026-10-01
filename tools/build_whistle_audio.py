#!/usr/bin/env python3
"""The farmer's whistle for his dog (Pet; Audio set "whistle"): synthesised, no source.

A human two-note call whistle: a pure, slightly breathy tone (the lips' pitch), a short
rising "fwee" and a longer one that slides up and falls at the end, a little vibrato and
a soft attack. Two takes (whistle_1, whistle_2) with different notes.
Run: python3 tools/build_whistle_audio.py  (writes art/audio/sfx/player/whistle_N.wav)
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "audio", "sfx", "player")


def note(f0: float, f1: float, f2: float, dur: float, rng: np.random.Generator) -> np.ndarray:
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    u = t / dur
    # Up from f0 to f1 over the first third, held, sliding to f2 at the very end.
    f = np.where(u < 0.3, f0 + (f1 - f0) * np.sin(u / 0.3 * np.pi / 2), f1)
    f = np.where(u > 0.8, f1 + (f2 - f1) * ((u - 0.8) / 0.2) ** 2, f)
    f = f * (1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.08 * np.sin(2 * phase)
    breath = rng.normal(0, 1, n)
    # Breath noise, band-limited around the tone by a crude moving average.
    breath = np.convolve(breath, np.ones(6) / 6, mode="same") * 0.05
    env = np.minimum(1.0, t / 0.035) * np.minimum(1.0, (dur - t) / 0.05)
    env = np.clip(env, 0, 1) ** 1.3
    return (tone + breath) * env


def take(notes, gap: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    parts = []
    for i, (f0, f1, f2, d) in enumerate(notes):
        parts.append(note(f0, f1, f2, d, rng))
        if i < len(notes) - 1:
            parts.append(np.zeros(int(gap * RATE)))
    x = np.concatenate([np.zeros(int(0.01 * RATE))] + parts + [np.zeros(int(0.12 * RATE))])
    return x / np.max(np.abs(x)) * 0.7


def write(path: str, x: np.ndarray) -> None:
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write(os.path.join(OUT, "whistle_1.wav"), take([(1700, 2300, 2300, 0.2), (1800, 2500, 2050, 0.5)], 0.09, 1))
    write(os.path.join(OUT, "whistle_2.wav"), take([(1900, 2450, 2400, 0.18), (1750, 2600, 2150, 0.55)], 0.08, 2))
    print("written", OUT)
