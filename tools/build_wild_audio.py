#!/usr/bin/env python3
"""Builds the sounds of the wild berry bushes and rabbits into art/audio/sfx/wild/.

Run from the project root:  python3 tools/build_wild_audio.py [--force]
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile).

Cut from Mixkit recordings (Mixkit Sound Effects Free License: free for commercial use
in games, no attribution needed; see art/audio/CREDITS.md), plus one made here:
  - rustle_*.ogg    a hand pulling through a bush for its berries (2430 Dry leaves
                    rustling, 2428 Dry leaves sound), softened
  - squeak_*.ogg    a caught rabbit's squeal (1019 Mouse squeak, 1018 Little squeak),
                    pitched down to a rabbit's size
  - scuffle_*.ogg   the grab in the grass (532 Footsteps on tall grass)
  - thump_*.ogg     a rabbit's alarm thump with a hind foot: synthesised (a low, damped
                    knock on the ground with a little grit)
The downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
Existing outputs are skipped unless --force is given.
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_camp_audio import SR, fetch, filt, level, ramp  # noqa: E402
import build_camp_audio  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio", "sfx", "wild")
build_camp_audio.SOURCES.update({"leaves_rustling": 2430, "leaves_dry": 2428, "mouse_squeak": 1019,
                                 "little_squeak": 1018, "tall_grass": 532})


def load(key):
    x, sr = sf.read(fetch(key), always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        g = np.gcd(sr, SR)
        x = signal.resample_poly(x, SR // g, sr // g)
    return x.astype(np.float64)


def loud_spots(x, count, length, min_gap):
    """Starts of the `count` loudest `length`-s stretches of `x`, `min_gap` s apart."""
    win = int(length * SR)
    env = np.convolve(x ** 2, np.ones(win) / win, mode="valid")
    order = np.argsort(env)[::-1]
    picked = []
    for i in order:
        if len(picked) >= count:
            break
        if all(abs(i - j) > min_gap * SR for j in picked):
            picked.append(i)
    return sorted(picked)


def onset(x, threshold=0.2):
    """Index where `x` first reaches `threshold` of its peak (10 ms windows)."""
    win = int(0.01 * SR)
    env = np.sqrt(np.convolve(x ** 2, np.ones(win) / win, mode="same"))
    return int(np.argmax(env > env.max() * threshold))


def pitched(x, factor):
    """Played `factor` times slower (lower and longer), like a slowed tape."""
    n = int(len(x) * factor)
    return signal.resample(x, n)


def save(name, x, force):
    path = os.path.join(OUT, name + ".ogg")
    if os.path.exists(path) and not force:
        return
    sf.write(path, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote", path, f"{len(x) / SR:.2f} s")


def thump(seed):
    rng = np.random.default_rng(seed)
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(62, 78)
    # A knock that drops in pitch as it dies, and the grit of the ground under the foot.
    body = np.sin(2 * np.pi * (f0 * t - 18 * t * t)) * np.exp(-t / 0.045)
    knock = filt(rng.standard_normal(n), "lowpass", 900) * np.exp(-t / 0.012) * 0.6
    grit = filt(rng.standard_normal(n), "bandpass", [1200, 4200]) * np.exp(-t / 0.02) * 0.08
    x = body + knock + grit
    return ramp(x, 0.001, 0.05)


def main():
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    # Rustles: the loudest bits of the leaf recordings, the crisp top taken off (green leaves).
    k = 0
    for key in ("leaves_rustling", "leaves_dry"):
        x = load(key)
        for a in loud_spots(x, 2, 0.8, 1.2):
            y = filt(filt(x[a:a + int(0.8 * SR)], "lowpass", 6500), "highpass", 180)
            save(f"rustle_{k}", level(ramp(y, 0.02, 0.25), -20.0), force)
            k += 1
    # Squeals: the squeaks slowed to a rabbit's pitch.
    k = 0
    for key, factor in (("mouse_squeak", 1.45), ("little_squeak", 1.3)):
        x = load(key)
        a = max(onset(x) - int(0.01 * SR), 0)
        y = pitched(x[a:a + int(0.5 * SR)], factor)
        y = filt(filt(y, "highpass", 500), "lowpass", 7000)
        save(f"squeak_{k}", level(ramp(y, 0.003, 0.08), -18.0), force)
        k += 1
    # The scuffle of the grab.
    x = load("tall_grass")
    for k, a in enumerate(loud_spots(x, 2, 0.45, 0.8)):
        y = filt(x[a:a + int(0.45 * SR)], "highpass", 120)
        save(f"scuffle_{k}", level(ramp(y, 0.005, 0.12), -19.0), force)
    for k in range(2):
        save(f"thump_{k}", level(thump(k + 3), -16.0, crest_db=10.0), force)


if __name__ == "__main__":
    main()
