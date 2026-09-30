#!/usr/bin/env python3
"""Builds the chick and hatching sounds into art/audio/sfx/animals/.

Run from the project root:  python3 tools/fetch_poultry_audio.py [--force]
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile).

  - chick_*.ogg      a chick's cheeps, cut from "মুরগির বাচ্চার ডাক" (a brood of chicks
                     calling) by Md. Tahmid Hossain, Wikimedia Commons, CC0:
                     https://commons.wikimedia.org/wiki/File:মুরগির_বাচ্চার_ডাক.oga
                     (Commons' Vorbis transcode; high-passed, faded and levelled)
  - egg_crack_*.ogg  a shell tapped and cracking from inside, synthesised here (filtered
                     noise clicks over a small hollow body): no source recording
  - egg_hatch.ogg    the shell giving way: a louder crack and the pieces falling apart,
                     synthesised here
None needs attribution (see art/audio/CREDITS.md). Existing outputs are skipped unless
--force is given; the download is cached in $FARMCRAFT_AUDIO_CACHE (default: the system
temp folder).
"""
import os
import sys
import tempfile
import urllib.parse
import urllib.request

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio", "sfx", "animals")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
SR = 44100
CEILING = 0.89
CHICKS_NAME = "মুরগির_বাচ্চার_ডাক.oga"
CHICKS_URL = "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a9/%s/%s.ogg" % (
    urllib.parse.quote(CHICKS_NAME), urllib.parse.quote(CHICKS_NAME))
## Cheep takes: [start, end] seconds in the recording.
CHICK_TAKES = [[2.35, 3.25], [5.9, 6.85], [8.05, 9.0], [11.75, 12.7]]


def fetch(url, name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def level(x, peak=CEILING):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fade(x, fin=0.02, fout=0.06):
    x = x.copy()
    a = int(SR * fin)
    b = int(SR * fout)
    x[:a] *= np.linspace(0.0, 1.0, a)
    x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def write(name, x, force):
    out = os.path.join(ROOT, name)
    if os.path.exists(out) and not force:
        print("skip", name)
        return
    sf.write(out, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote", name, "%.2f s" % (len(x) / SR))


def chicks(force):
    x, sr = sf.read(fetch(CHICKS_URL, "chicks_brood.ogg"))
    if x.ndim > 1:
        x = x.mean(axis=1)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr)
    # Cheeps sit around 3-5 kHz: the room and handling noise below goes.
    sos = signal.butter(4, 1400, "highpass", fs=SR, output="sos")
    x = signal.sosfiltfilt(sos, x)
    for i, (a, b) in enumerate(CHICK_TAKES):
        write("chick_%d.ogg" % i, level(fade(x[int(a * SR):int(b * SR)]), 0.8), force)


def click(rng, length, lo, hi, decay):
    """A short filtered noise burst with a sharp attack: a crack in a thin shell."""
    n = int(SR * length)
    t = np.arange(n) / SR
    env = np.exp(-t / decay)
    env[: int(SR * 0.0008)] *= np.linspace(0, 1, int(SR * 0.0008))
    sos = signal.butter(3, [lo, hi], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, rng.standard_normal(n)) * env


def body(length, freq, decay):
    """The egg's hollow knock under a crack."""
    t = np.arange(int(SR * length)) / SR
    return np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)


def cracks(force):
    rng = np.random.default_rng(11)
    for k in range(3):
        out = np.zeros(int(SR * 0.45))
        at = 0.02
        # Two or three taps from inside, each a crack with a knock under it.
        for j in range(2 + k % 2):
            c = click(rng, 0.05, 2200 + 400 * j, 7500, 0.006 + 0.002 * rng.random()) \
                + 0.35 * body(0.05, 1050 + 180 * k + 90 * j, 0.008)
            s = int(SR * at)
            out[s:s + len(c)] += c * (0.7 + 0.3 * rng.random())
            at += 0.09 + 0.07 * rng.random()
        write("egg_crack_%d.ogg" % k, level(out, 0.7), force)
    # The shell gives way: a longer split, then the halves and crumbs falling apart.
    out = np.zeros(int(SR * 0.9))
    split = click(rng, 0.12, 1500, 8000, 0.02) + 0.5 * body(0.12, 900, 0.015)
    out[: len(split)] += split
    at = 0.13
    for j in range(6):
        c = click(rng, 0.03, 3000, 9000, 0.004) * (0.6 - j * 0.07)
        s = int(SR * at)
        out[s:s + len(c)] += c
        at += 0.04 + 0.08 * rng.random()
    write("egg_hatch.ogg", level(out, 0.8), force)


def main():
    force = "--force" in sys.argv
    os.makedirs(ROOT, exist_ok=True)
    chicks(force)
    cracks(force)


if __name__ == "__main__":
    main()
