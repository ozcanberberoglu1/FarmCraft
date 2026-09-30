#!/usr/bin/env python3
"""Builds Karamel's (Zeynep's dog's) sounds into art/audio/sfx/animals/.

Run from the project root:  python3 tools/build_dog_audio.py [--force]
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile).

Cut, cleaned and levelled from these recordings (none needs attribution; see
art/audio/CREDITS.md):
  - dog_bark_*.ogg   a medium-large dog's single barks: Mixkit 1 "Dog barking twice" (both
                     barks), "Dog Bark" by aunrea (Freesound 495658, CC0, two of its barks),
                     "Single Dog Bark" by kwahmah_02 (Freesound 277058, CC0)
  - dog_pant_*.ogg   happy panting: Mixkit 58 "Medium size dog walking pant" (two takes),
                     "Dog Panting Loop" by qubodup (Freesound 827433, CC0, looped twice)
  - dog_whine_*.ogg  a soft whine, content or asking: "Malinois Dog Whining" by qubodup
                     (Freesound 752093, CC0, two takes), Mixkit 467 "Dog sad whimper"
  - dog_eat_*.ogg    eating from a bowl, crunching kibble and lapping: "Dog eating dry
                     kibble" by artemditkovsky (Freesound 860329, CC0), "Lab mix eating
                     kible" by Rolly-SFX (Freesound 856229, CC0), "Dog Eating Very Wet Food"
                     by qubodup (Freesound 741034, CC0), the loudest stretches of each
Mixkit sounds: Mixkit Sound Effects Free License (free for commercial use in games, no
attribution). Freesound: the 'hq' previews, which download without an account.
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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_camp_audio import SR, filt, level, ramp  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio", "sfx", "animals")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
FREESOUND = "https://cdn.freesound.org/previews/"
MIXKIT = "https://assets.mixkit.co/active_storage/sfx/%d/%d-preview.mp3"
SOURCES = {
    "barking_twice": MIXKIT % (1, 1),
    "walking_pant": MIXKIT % (58, 58),
    "sad_whimper": MIXKIT % (467, 467),
    "aunrea_bark": FREESOUND + "495/495658_7932944-hq.mp3",
    "single_bark": FREESOUND + "277/277058_4486188-hq.mp3",
    "panting_loop": FREESOUND + "827/827433_71257-hq.mp3",
    "malinois_whine": FREESOUND + "752/752093_71257-hq.mp3",
    "dry_kibble": FREESOUND + "860/860329_9079786-hq.mp3",
    "lab_kibble": FREESOUND + "856/856229_6303715-hq.mp3",
    "wet_food": FREESOUND + "741/741034_71257-hq.mp3",
}


def fetch(key):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "dog_" + key + ".mp3")
    if not os.path.exists(path):
        req = urllib.request.Request(SOURCES[key], headers=HEADERS)
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


def cut(x, t0, t1):
    return x[int(t0 * SR):int(t1 * SR)].copy()


def envelope(x, win=0.02):
    n = max(int(win * SR), 1)
    return np.sqrt(np.convolve(x ** 2, np.ones(n) / n, mode="same"))


def trimmed(x, threshold=0.06, pre=0.012, post=0.08):
    """`x` from just before it first reaches `threshold` of its peak loudness to just
    after it last does (silence and room tone around a bark left out)."""
    env = envelope(x, 0.01)
    on = np.nonzero(env > env.max() * threshold)[0]
    if len(on) == 0:
        return x
    a = max(int(on[0] - pre * SR), 0)
    b = min(int(on[-1] + post * SR), len(x))
    return x[a:b].copy()


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


def save(name, x, force):
    path = os.path.join(OUT, name + ".ogg")
    if os.path.exists(path) and not force:
        return
    sf.write(path, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote", path, f"{len(x) / SR:.2f} s")


def main():
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    # Barks: each bark alone, rumble and hiss off, a short tail.
    barks = []
    twice = load("barking_twice")
    barks += [cut(twice, 0.0, 0.8), cut(twice, 0.8, 1.62)]
    aunrea = load("aunrea_bark")
    barks += [cut(aunrea, 0.05, 1.35), cut(aunrea, 1.35, 2.8)]
    barks.append(load("single_bark"))
    for k, b in enumerate(barks):
        y = filt(filt(trimmed(b), "highpass", 110), "lowpass", 9000)
        save(f"dog_bark_{k}", level(ramp(y, 0.004, 0.06), -15.0, crest_db=12.0), force)
    # Panting: breaths at a steady pace.
    pant = load("walking_pant")
    loop = load("panting_loop")
    takes = [cut(pant, 0.1, 3.3), cut(pant, 3.5, 6.8), np.concatenate([loop, loop, loop])]
    for k, y in enumerate(takes):
        y = filt(y, "highpass", 150)
        save(f"dog_pant_{k}", level(ramp(y, 0.08, 0.3), -24.0), force)
    # Whines: short and soft.
    whine = load("malinois_whine")
    whimper = load("sad_whimper")
    takes = [cut(whine, 0.85, 2.3), cut(whine, 2.3, 3.86), cut(whimper, 1.6, 4.05)]
    for k, y in enumerate(takes):
        y = filt(filt(trimmed(y, 0.04, 0.03, 0.15), "highpass", 250), "lowpass", 8000)
        save(f"dog_whine_{k}", level(ramp(y, 0.03, 0.2), -22.0), force)
    # Eating: the busiest stretches of crunching and lapping, 1.6 s each.
    k = 0
    for key, count in (("dry_kibble", 2), ("lab_kibble", 1), ("wet_food", 2)):
        x = filt(load(key), "highpass", 120)
        for s in loud_spots(x, count, 1.6, 3.0):
            y = x[s:s + int(1.6 * SR)].copy()
            save(f"dog_eat_{k}", level(ramp(y, 0.05, 0.25), -22.0), force)
            k += 1


if __name__ == "__main__":
    main()
