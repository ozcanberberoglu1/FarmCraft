#!/usr/bin/env python3
"""Synthesises the side story's sounds into art/audio/sfx/misc/: knocks on a front door
(knock_0..2.ogg, three raps each, played when the player knocks on Zeynep's door).

A knuckle on a wooden door: a short bright tick where the knuckle lands, the panel's
body ringing under it (a few low damped modes of a thin wooden door, their pitch and
damping a little different for each rap), the frame's duller thud, and a touch of the
hallway behind it (short early reflections). Three raps in a natural rhythm, the last a
little softer.

Run from the project root:  python3 tools/build_story_audio.py [--force]
Needs numpy, scipy and soundfile. Deterministic (fixed seeds).
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio", "sfx", "misc")


def rap(rng, strength):
    n = int(SR * 0.32)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # The panel's modes: frequency (Hz), decay (s), gain.
    modes = [(118, 0.055, 1.0), (176, 0.04, 0.7), (262, 0.03, 0.55), (395, 0.022, 0.4), (610, 0.014, 0.28),
             (930, 0.009, 0.18), (1480, 0.005, 0.12)]
    for f, dec, g in modes:
        f *= 1.0 + rng.uniform(-0.035, 0.035)
        dec *= 1.0 + rng.uniform(-0.15, 0.15)
        out += g * np.sin(2 * np.pi * f * t + rng.uniform(0, np.pi)) * np.exp(-t / dec)
    # Attack: a millisecond ramp so it doesn't click.
    ramp = int(SR * 0.0012)
    out[:ramp] *= np.linspace(0.0, 1.0, ramp)
    # The knuckle's tick: band-limited noise, a few milliseconds.
    tick_n = int(SR * 0.012)
    tick = rng.standard_normal(tick_n) * np.exp(-np.arange(tick_n) / (SR * 0.0018))
    tick = signal.sosfilt(signal.butter(2, [1800, 7000], "bandpass", fs=SR, output="sos"), tick)
    out[:tick_n] += tick * 0.9
    # The frame's thud.
    thud = np.sin(2 * np.pi * 72 * t) * np.exp(-t / 0.03) * 0.5
    out += thud
    return out * strength


def hallway(x, rng):
    """A few early reflections of a small hall, low-passed."""
    y = x.copy()
    for delay, g in [(0.011, 0.28), (0.019, 0.2), (0.027, 0.14), (0.041, 0.09), (0.058, 0.05)]:
        d = int(SR * delay)
        y[d:] += x[:-d] * g
    sos = signal.butter(2, 5200, "lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, y)


def level(x, peak):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def main():
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for k in range(3):
        path = os.path.join(OUT, "knock_%d.ogg" % k)
        if os.path.exists(path) and not force:
            print("skip", path)
            continue
        rng = np.random.default_rng(40 + k)
        out = np.zeros(int(SR * 0.9))
        at = 0.01
        gaps = [0.2 + rng.uniform(-0.02, 0.03), 0.21 + rng.uniform(-0.02, 0.04)]
        for j in range(3):
            r = rap(rng, [1.0, 0.92, 0.8][j] * rng.uniform(0.93, 1.0))
            s = int(SR * at)
            e = min(s + len(r), len(out))
            out[s:e] += r[: e - s]
            if j < 2:
                at += gaps[j]
        out = hallway(out, rng)
        fade = int(SR * 0.08)
        out[-fade:] *= np.linspace(1.0, 0.0, fade)
        sf.write(path, level(out, 0.85).astype(np.float32), SR, format="OGG", subtype="VORBIS")
        print("wrote", path)


if __name__ == "__main__":
    main()
