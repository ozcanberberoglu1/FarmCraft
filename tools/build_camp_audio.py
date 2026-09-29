#!/usr/bin/env python3
"""Builds the campfire, cooking, eating and tiredness sounds into art/audio/sfx/camp/.

Run from the project root:  python3 tools/build_camp_audio.py [--force]
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile).

Every sound is cut from a Mixkit recording (Mixkit Sound Effects Free License: free
for commercial use in games, no attribution needed; see art/audio/CREDITS.md):
  - fire_loop.ogg     the campfire's crackle bed, made loop-seamless (1330 Campfire crackles)
  - fire_pop_*.ogg    single log pops and cracks (1329 Campfire burning crackles)
  - match.ogg         a match struck to light the fire (2590 Fire match lighting)
  - ignite.ogg        the kindling catching (1328 Fire swoosh burning)
  - sizzle_loop.ogg   fish sizzling over the flames, loop-seamless (123 Frying fish on a hot pan)
  - douse.ogg         water poured on the fire: splash, steam hiss (2447 Volcano lava hiss,
                      1458 Steam swoosh, 1311 Water splash)
  - bite_*.ogg        a bite of food (117 Human bites a juicy sausage, 2252 Hungry man eating)
  - chew_*.ogg        chewing (2244 Chewing something crunchy, 114 Human eating tasty food)
  - yawn.ogg          a tired yawn (2272 Male tired yawn)
The downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
Existing outputs are skipped unless --force is given.
"""
import os
import sys
import tempfile
import urllib.request

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio", "sfx", "camp")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
SR = 44100
CEILING = 0.89

SOURCES = {
    "crackles": 1330, "crackles_burning": 1329, "match": 2590, "swoosh_burning": 1328,
    "frying": 123, "lava_hiss": 2447, "steam": 1458, "splash": 1311,
    "bite_sausage": 117, "hungry_eating": 2252, "chew_crunchy": 2244, "eating_tasty": 114,
    "yawn": 2272,
}


def fetch(key):
    sid = SOURCES[key]
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f"mixkit_{sid}.mp3")
    if not os.path.exists(path):
        url = f"https://assets.mixkit.co/active_storage/sfx/{sid}/{sid}-preview.mp3"
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    return path


def load(key):
    x, sr = sf.read(fetch(key), always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        g = np.gcd(sr, SR)
        x = signal.resample_poly(x, SR // g, sr // g)
    return x.astype(np.float64)


def cut(x, t0, length):
    a = int(t0 * SR)
    return x[a:a + int(length * SR)].copy()


def filt(x, kind, hz, order=2):
    sos = signal.butter(order, hz, btype=kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def ramp(x, fin=0.005, fout=0.02):
    n_in = max(int(fin * SR), 1)
    n_out = max(int(fout * SR), 1)
    x[:n_in] *= np.linspace(0.0, 1.0, n_in) ** 2
    x[-n_out:] *= np.linspace(1.0, 0.0, n_out) ** 2
    return x


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def limit(x, threshold, release=0.06):
    """Peaks over `threshold` held down (instant attack, `release` s recovery), so a sparse
    recording can be brought up without its loudest cracks clipping."""
    env = np.abs(x)
    k = np.exp(-1.0 / (release * SR))
    out = np.empty_like(env)
    e = 0.0
    for i, v in enumerate(env):
        e = v if v > e else e * k + v * (1.0 - k)
        out[i] = e
    return x * np.minimum(1.0, threshold / (out + 1e-9))


def level(x, target_db, crest_db=14.0):
    """Loudness to `target_db` (RMS). Peaks more than `crest_db` over it are limited first,
    and the result is kept under the ceiling."""
    for _ in range(3):
        x = x * 10 ** ((target_db - rms_db(x)) / 20)
        x = limit(x, 10 ** ((target_db + crest_db) / 20))
    peak = np.max(np.abs(x))
    if peak > CEILING:
        x *= CEILING / peak
    return x


def seamless(x, xfade=1.5):
    """A loop whose end runs into its start: the last `xfade` s are cross-faded (equal
    power) over the first ones, which are then dropped."""
    n = int(xfade * SR)
    head = x[:n]
    tail = x[-n:]
    t = np.linspace(0.0, np.pi * 0.5, n)
    mixed = tail * np.cos(t) + head * np.sin(t)
    return np.concatenate([x[n:-n], mixed])


def pops(x, count, length=0.5, min_gap=0.6):
    """The `count` sharpest transients of `x` (log pops), each cut `length` s long."""
    env = np.abs(filt(x, "highpass", 1500))
    win = int(0.004 * SR)
    env = np.convolve(env, np.ones(win) / win, mode="same")
    slow = np.convolve(env, np.ones(int(0.12 * SR)) / int(0.12 * SR), mode="same")
    score = env / (slow + 1e-6)
    order = np.argsort(score)[::-1]
    picked = []
    for i in order:
        if len(picked) >= count:
            break
        if i < int(0.02 * SR) or i > len(x) - int(length * SR):
            continue
        if all(abs(i - j) > min_gap * SR for j in picked):
            picked.append(i)
    out = []
    for i in sorted(picked):
        a = i - int(0.01 * SR)
        snip = x[a:a + int(length * SR)].copy()
        # A fast decay after the pop, so the bed under it doesn't come along.
        snip *= np.exp(-np.arange(len(snip)) / (0.09 * SR))
        out.append(ramp(snip, 0.003, 0.08))
    return out


def onset(x, frac=0.2):
    env = np.abs(x)
    return int(np.argmax(env > frac * env.max()))


def trimmed(x, lead=0.01, length=None):
    a = max(onset(x) - int(lead * SR), 0)
    y = x[a:] if length is None else x[a:a + int(length * SR)]
    return y.copy()


def save(name, x):
    os.makedirs(ROOT, exist_ok=True)
    sf.write(os.path.join(ROOT, name), x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print(f"  {name}: {len(x) / SR:.2f} s")


def build(force=False):
    def want(name):
        return force or not os.path.exists(os.path.join(ROOT, name))

    if want("fire_loop.ogg"):
        x = load("crackles")
        # The bed: rumble under 60 Hz off, cross-faded into itself.
        x = filt(x, "highpass", 60)
        save("fire_loop.ogg", level(seamless(cut(x, 0.5, 22.0), 2.0), -24.0))
    if want("fire_pop_0.ogg"):
        x = load("crackles_burning")
        for i, p in enumerate(pops(filt(x, "highpass", 120), 5)):
            save(f"fire_pop_{i}.ogg", level(p, -24.0))
    if want("match.ogg"):
        x = load("match")
        save("match.ogg", level(ramp(trimmed(filt(x, "highpass", 90), 0.01, 2.6), 0.003, 0.6), -20.0))
    if want("ignite.ogg"):
        x = load("swoosh_burning")
        save("ignite.ogg", level(ramp(trimmed(filt(x, "highpass", 70), 0.05, 2.8), 0.08, 0.9), -19.0))
    if want("sizzle_loop.ogg"):
        x = load("frying")
        x = filt(x, "highpass", 180)
        save("sizzle_loop.ogg", level(seamless(cut(x, 1.0, 16.0), 1.5), -24.0))
    if want("douse.ogg"):
        splash = trimmed(filt(load("splash"), "highpass", 80), 0.005, 1.0)
        hiss = trimmed(filt(load("lava_hiss"), "highpass", 250), 0.01)
        steam = trimmed(filt(load("steam"), "highpass", 300), 0.01)
        n = int(2.6 * SR)
        out = np.zeros(n)

        def put(src, at, gain_db):
            a = int(at * SR)
            m = min(len(src), n - a)
            out[a:a + m] += src[:m] * 10 ** (gain_db / 20)

        put(level(splash, -20.0), 0.0, 0.0)
        # The hiss swells a moment after the water lands, the steam rushes up with it.
        hiss_long = np.concatenate([hiss, hiss[::-1] * 0.6, hiss * 0.35])
        put(level(ramp(hiss_long, 0.05, 0.6), -20.0), 0.08, -1.0)
        put(level(ramp(steam, 0.02, 0.3), -20.0), 0.12, -4.0)
        save("douse.ogg", level(ramp(out, 0.002, 0.8), -18.0))
    if want("bite_0.ogg"):
        save("bite_0.ogg", level(ramp(trimmed(load("bite_sausage"), 0.005, 0.7), 0.002, 0.2), -20.0))
        save("bite_1.ogg", level(ramp(trimmed(load("hungry_eating"), 0.005, 0.8), 0.002, 0.25), -20.0))
    if want("chew_0.ogg"):
        save("chew_0.ogg", level(ramp(trimmed(load("chew_crunchy"), 0.005, 0.9), 0.002, 0.25), -22.0))
        x = load("eating_tasty")
        save("chew_1.ogg", level(ramp(trimmed(x, 0.005, 1.3), 0.002, 0.3), -22.0))
    if want("yawn.ogg"):
        save("yawn.ogg", level(ramp(trimmed(filt(load("yawn"), "highpass", 80), 0.02), 0.02, 0.4), -21.0))


if __name__ == "__main__":
    build("--force" in sys.argv)
