#!/usr/bin/env python3
"""Builds the carnival night's sounds (Carnival, TownCarnival) into art/audio/.

Run from the project root:  python3 tools/build_carnival_audio.py   (tools/fetch_audio.py runs it too)
Needs numpy and soundfile (pip install numpy soundfile).

Every file is cut from a CC0 recording on Freesound (its high-quality preview downloads
without an account; see art/audio/CREDITS.md), trimmed, faded and matched in loudness:
  music/carnival_band_organ.ogg      a carousel's band organ playing one tune (CHallSmith)
  ambience/carnival_crowd.ogg        a fairground crowd's murmur, looped by Audio (kyles)
  sfx/carnival/firework_1..3.ogg     bursts: one with the town's echo (jakubp), two clean (unfa)
  sfx/carnival/crackle_1.ogg         the crackle of a glitter shell (LukaCafuka)
The Mixkit fair tunes (music/carnival_*.mp3) come straight from tools/fetch_audio.py.
Downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
Existing outputs are skipped unless --force is given.
"""
import io
import os
import sys
import tempfile
import urllib.request

import numpy as np
import soundfile as sf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
FREESOUND = "https://cdn.freesound.org/previews/"
CEILING = 0.89

# Source key -> Freesound preview (all CC0).
SOURCES = {
    "band_organ": "870/870752_18412227-hq.mp3",  # CHallSmith, "Large Band Organ at Carousel"
    "crowd": "629/629887_612689-hq.mp3",  # kyles, crowd outside a park, "could be fairground"
    "firework_echo": "552/552699_3921235-hq.mp3",  # jakubp.jp, single firework with city reverb
    "firework_clean": "613/613672_1038806-hq.mp3",  # unfa, outdoor clean explosions (NYE 2021)
    "crackle": "750/750682_16236894-hq.mp3",  # LukaCafuka, firework crackle
}

# Output (under art/audio) -> (source, start s, end s, fade in s, fade out s, target RMS dBFS).
CUTS = {
    # The first tune of the organ, up to the pause before the next one.
    "music/carnival_band_organ.ogg": ("band_organ", 0.0, 143.0, 0.8, 5.0, -17.0),
    "ambience/carnival_crowd.ogg": ("crowd", 4.0, 124.0, 0.3, 0.3, -24.0),
    "sfx/carnival/firework_1.ogg": ("firework_echo", 0.0, 5.5, 0.0, 1.8, None),
    "sfx/carnival/firework_2.ogg": ("firework_clean", 0.72, 3.15, 0.01, 1.2, None),
    "sfx/carnival/firework_3.ogg": ("firework_clean", 3.22, 6.1, 0.01, 1.2, None),
    "sfx/carnival/crackle_1.ogg": ("crackle", 0.0, 1.65, 0.0, 0.5, None),
}


def source(key):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "carnival_" + os.path.basename(SOURCES[key]))
    if not os.path.exists(path):
        req = urllib.request.Request(FREESOUND + SOURCES[key], headers=HEADERS)
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    return sf.read(path, always_2d=True)


def cut(key, start, end, fade_in, fade_out, rms_db):
    x, sr = source(key)
    x = x[int(start * sr):int(end * sr)].copy()
    n = len(x)
    if fade_in > 0:
        k = int(fade_in * sr)
        x[:k] *= np.linspace(0.0, 1.0, k)[:, None]
    if fade_out > 0:
        k = int(fade_out * sr)
        x[n - k:] *= (np.linspace(1.0, 0.0, k) ** 1.5)[:, None]
    if rms_db is not None:
        rms = np.sqrt(np.mean(x ** 2)) + 1e-9
        x *= 10 ** (rms_db / 20.0) / rms
    peak = np.max(np.abs(x))
    if peak > CEILING:
        x *= CEILING / peak
    return x, sr


def build(force=False):
    made = 0
    for rel, spec in CUTS.items():
        out = os.path.join(ROOT, rel)
        if os.path.exists(out) and not force:
            continue
        x, sr = cut(*spec)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        # libsndfile's Vorbis encoder crashes on long buffers written at once: in blocks.
        x = np.ascontiguousarray(x, dtype=np.float32)
        with sf.SoundFile(out, "w", sr, x.shape[1], format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(x), 8192):
                f.write(x[i:i + 8192])
        made += 1
        print(f"{rel}: {len(x) / sr:.1f} s, {os.path.getsize(out) / 1e6:.2f} MB")
    return made


if __name__ == "__main__":
    build("--force" in sys.argv)
