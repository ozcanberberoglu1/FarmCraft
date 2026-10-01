#!/usr/bin/env python3
"""Builds the fishing contest's sounds (FishingContest) into art/audio/sfx/contest/.

Run from the project root:  python3 tools/build_contest_audio.py
Needs numpy and soundfile (pip install numpy soundfile).

Cut from Mixkit previews (Mixkit Sound Effects Free License: free for commercial use in
games, no attribution required; see art/audio/CREDITS.md), trimmed, faded, mono and
matched in loudness:
  sfx/contest/horn.ogg       the horn that ends the contest at 17:00 ("Warfare horn", 2289)
  sfx/contest/applause.ogg   the crowd's applause after it ("Medium size crowd applause", 485)
  sfx/contest/fanfare.ogg    the winner announced ("Successful horns fanfare", 722)
Downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
"""
import io
import os
import tempfile
import urllib.request

import numpy as np
import soundfile as sf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
CEILING = 0.89

# Output -> (Mixkit id, start s, end s, fade in s, fade out s, target RMS dBFS).
CUTS = {
    "sfx/contest/horn.ogg": (2289, 0.0, 4.95, 0.02, 1.2, -16.0),
    "sfx/contest/applause.ogg": (485, 0.0, 11.9, 0.4, 2.5, -20.0),
    "sfx/contest/fanfare.ogg": (722, 0.0, 3.16, 0.0, 0.6, -18.0),
}


def source(sid):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "contest_%d.mp3" % sid)
    if not os.path.exists(path):
        url = "https://assets.mixkit.co/active_storage/sfx/%d/%d-preview.mp3" % (sid, sid)
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    d, sr = sf.read(path)
    if d.ndim > 1:
        d = d.mean(axis=1)
    return d, sr


def main():
    for rel, (sid, a, b, fi, fo, rms_db) in CUTS.items():
        d, sr = source(sid)
        d = d[int(a * sr):int(b * sr)].copy()
        n = len(d)
        if fi > 0:
            k = int(fi * sr)
            d[:k] *= np.linspace(0.0, 1.0, k)
        if fo > 0:
            k = int(fo * sr)
            d[n - k:] *= np.linspace(1.0, 0.0, k) ** 1.5
        rms = np.sqrt(np.mean(d ** 2)) + 1e-9
        d *= 10 ** (rms_db / 20.0) / rms
        peak = np.max(np.abs(d))
        if peak > CEILING:
            d *= CEILING / peak
        out = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sf.write(out, d.astype(np.float32), sr, format="OGG", subtype="VORBIS")
        print(rel, "%.2fs" % (n / sr))


if __name__ == "__main__":
    main()
