#!/usr/bin/env python3
"""Builds the food table, trophy fish and fainting sounds into art/audio/sfx/camp/.

Run from the project root:  python3 tools/build_food_audio.py [--force]
Needs numpy, scipy and soundfile (as tools/build_camp_audio.py, whose helpers it uses).

Every sound is cut from a Mixkit recording (Mixkit Sound Effects Free License: free
for commercial use in games, no attribution needed; see art/audio/CREDITS.md):
  - chop_*.ogg      the knife coming down on the board (134 Chopping food on the table,
                    136 Cutting hard vegetables with knife)
  - slice.ogg       the blade drawn through (2152 Quick knife slice cutting)
  - meat_hit.ogg    the knife through meat and joint (2159 Meat hit sound)
  - trophy.ogg      the fanfare of a trophy fish (600 Achievement bell)
The downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
Existing outputs are skipped unless --force is given.
"""
import os
import sys
import urllib.request


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_camp_audio as bca  # noqa: E402

SOURCES = {"chopping": 134, "cutting_veg": 136, "slice": 2152, "meat_hit": 2159, "trophy": 600}
SR = bca.SR


def fetch(key):
    sid = SOURCES[key]
    os.makedirs(bca.CACHE, exist_ok=True)
    path = os.path.join(bca.CACHE, f"mixkit_{sid}.mp3")
    if not os.path.exists(path):
        url = f"https://assets.mixkit.co/active_storage/sfx/{sid}/{sid}-preview.mp3"
        req = urllib.request.Request(url, headers=bca.HEADERS)
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    return path


def load(key):
    bca.SOURCES[key] = SOURCES[key]
    bca.fetch = fetch
    return bca.load(key)


def chops(x, count, length=0.34):
    """The `count` cleanest knife hits of a chopping recording, each with a short tail."""
    out = []
    for p in bca.pops(bca.filt(x, "highpass", 90), count, length, 0.3):
        out.append(p)
    return out


def build(force=False):
    def want(name):
        return force or not os.path.exists(os.path.join(bca.ROOT, name))

    if want("chop_0.ogg"):
        takes = chops(load("chopping"), 3) + chops(load("cutting_veg"), 2)
        for i, t in enumerate(takes):
            bca.save(f"chop_{i}.ogg", bca.level(t, -20.0))
    if want("slice.ogg"):
        x = bca.filt(load("slice"), "highpass", 150)
        bca.save("slice.ogg", bca.level(bca.ramp(bca.trimmed(x, 0.005, 0.7), 0.003, 0.2), -21.0))
    if want("meat_hit.ogg"):
        x = bca.filt(load("meat_hit"), "highpass", 60)
        bca.save("meat_hit.ogg", bca.level(bca.ramp(bca.trimmed(x, 0.005, 0.6), 0.002, 0.2), -19.0))
    if want("trophy.ogg"):
        x = load("trophy")
        bca.save("trophy.ogg", bca.level(bca.ramp(bca.trimmed(x, 0.005, 2.3), 0.003, 0.6), -18.0))


if __name__ == "__main__":
    build("--force" in sys.argv)
