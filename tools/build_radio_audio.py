#!/usr/bin/env python3
"""The car radio's own noises (CarRadio): synthesised, no source.

radio_tune_N.wav: the dial between two stations, half a second or so of band-limited
hiss that flutters, the squeal of a carrier sweeping past (a heterodyne whistle falling
and rising) and a few crackles. Three takes, so two changes in a row differ.
radio_click.wav: the knob's switch, a dull click with a short thump of the speaker
coming alive.
Run: python3 tools/build_radio_audio.py  (writes art/audio/sfx/vehicle/radio_*.wav)
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "audio", "sfx", "vehicle")


def band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Band-pass by masking the spectrum, with soft edges an octave wide."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    gain = np.clip((f - lo * 0.5) / (lo * 0.5), 0, 1) * np.clip((hi * 2.0 - f) / hi, 0, 1)
    return np.fft.irfft(spec * gain, len(x))


def tune(dur: float, sweeps, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    # The hiss between stations: its level wanders as the dial moves.
    hiss = band(rng.normal(0, 1, n), 500.0, 4200.0)
    hiss /= np.max(np.abs(hiss))
    flutter = 0.45 + 0.55 * np.interp(t, np.linspace(0, dur, 14), rng.uniform(0, 1, 14))
    x = hiss * flutter * 0.55
    # Carriers swept past: each a whistle from f0 to f1 heard for a moment.
    for at, length, f0, f1 in sweeps:
        u = np.clip((t - at) / length, 0, 1)
        f = f0 * (f1 / f0) ** u
        phase = 2 * np.pi * np.cumsum(f) / RATE
        window = np.sin(np.pi * u) ** 1.5 * ((t >= at) & (t <= at + length))
        x += (np.sin(phase) + 0.2 * np.sin(2 * phase)) * window * 0.22
    # Crackles: a handful of short decaying bursts.
    for at in rng.uniform(0.03, dur - 0.08, 7):
        k = int(at * RATE)
        m = int(rng.uniform(0.004, 0.012) * RATE)
        x[k:k + m] += rng.normal(0, 1, m) * np.exp(-np.arange(m) / (m * 0.3)) * rng.uniform(0.25, 0.5)
    # A tinny set: nothing below the speaker's reach.
    x = band(x, 300.0, 4800.0)
    env = np.minimum(1.0, t / 0.012) * np.minimum(1.0, (dur - t) / 0.07)
    x = x * np.clip(env, 0, 1)
    return x / np.max(np.abs(x)) * 0.55


def click() -> np.ndarray:
    rng = np.random.default_rng(9)
    n = int(0.11 * RATE)
    t = np.arange(n) / RATE
    # The switch's snap, then the cone's thump.
    snap = rng.normal(0, 1, n) * np.exp(-t / 0.0025)
    thump = np.sin(2 * np.pi * 140.0 * t) * np.exp(-t / 0.018) * (t > 0.004)
    x = band(snap, 900.0, 5000.0) * 0.8 + thump * 0.5
    x *= np.minimum(1.0, t / 0.0006) * np.minimum(1.0, (0.11 - t) / 0.02)
    return x / np.max(np.abs(x)) * 0.5


def write(path: str, x: np.ndarray) -> None:
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write(os.path.join(OUT, "radio_tune_1.wav"), tune(0.55, [(0.05, 0.2, 2600, 700), (0.3, 0.18, 500, 1900)], 1))
    write(os.path.join(OUT, "radio_tune_2.wav"), tune(0.62, [(0.1, 0.25, 900, 3100), (0.38, 0.15, 2200, 1200)], 2))
    write(os.path.join(OUT, "radio_tune_3.wav"), tune(0.5, [(0.02, 0.16, 3300, 1500), (0.22, 0.2, 1400, 400)], 3))
    write(os.path.join(OUT, "radio_click.wav"), click())
    print("written", OUT)
