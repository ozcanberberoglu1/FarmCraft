#!/usr/bin/env python3
"""Builds the fishing contest's sounds (FishingContest) into art/audio/sfx/contest/.

Run from the project root:  python3 tools/build_contest_audio.py   [--force]
Needs numpy and soundfile (pip install numpy soundfile).

Synthesised here (no source recording; project-owned):
  sfx/contest/whistle.ogg    the referee's whistle that ends the contest at 17:00: two short
                             blasts and a long one, a pea whistle's trilled tone (the war horn
                             that stood here before frightened the owner: "a whistle that
                             feels like the end" was asked for)
Cut from Mixkit previews (Mixkit Sound Effects Free License: free for commercial use in
games, no attribution required; see art/audio/CREDITS.md), trimmed, faded, mono and
matched in loudness:
  sfx/contest/applause.ogg   the crowd's applause after it ("Medium size crowd applause", 485)
  sfx/contest/fanfare.ogg    the winner announced ("Successful horns fanfare", 722)
Downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
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
CEILING = 0.89

# Output -> (Mixkit id, start s, end s, fade in s, fade out s, target RMS dBFS).
CUTS = {
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


# The whistle: the sample rate, the blasts (seconds blown, seconds of pause after), the
# tone (Hz; lower than a football referee's so it is clear, not piercing) and its level.
WHISTLE_RATE = 44100
WHISTLE_BLASTS = [(0.2, 0.13), (0.2, 0.16), (1.05, 0.0)]
WHISTLE_HZ = 2750.0
WHISTLE_RMS_DB = -20.0


def blast(dur, rng):
    """One blow of a pea whistle: the tone scooping up as the breath comes and sagging as
    it goes, the pea's flutter in loudness and a little in pitch, breath hiss round it."""
    sr = WHISTLE_RATE
    n = int(dur * sr)
    t = np.arange(n) / sr
    # The breath's pressure: quick up, held (easing off a little on a long blow), quick down.
    press = np.minimum(1.0, t / 0.03) * np.minimum(1.0, (dur - t) / 0.06)
    press = np.clip(press, 0.0, 1.0) ** 0.8 * (1.0 - 0.12 * t / max(dur, 1e-6))
    # The pea goes round faster the harder he blows.
    rate = 30.0 + 9.0 * press + rng.normal(0.0, 0.6, n).cumsum() * 0.02
    flutter = np.sin(2 * np.pi * np.cumsum(rate) / sr)
    f = WHISTLE_HZ * (0.955 + 0.045 * press) * (1.0 + 0.007 * flutter)
    phase = 2 * np.pi * np.cumsum(f) / sr
    tone = np.sin(phase) + 0.16 * np.sin(2 * phase + 0.4) + 0.05 * np.sin(3 * phase)
    # (A second chamber a little higher: the slow beat a two-tone whistle has.)
    tone += 0.35 * np.sin(phase * 1.045)
    hiss = rng.normal(0.0, 1.0, n)
    hiss = np.convolve(hiss, np.ones(5) / 5.0, mode="same") - np.convolve(hiss, np.ones(40) / 40.0, mode="same")
    return (tone * (0.62 + 0.38 * flutter) + 0.14 * hiss) * press


def whistle():
    sr = WHISTLE_RATE
    rng = np.random.default_rng(17)
    parts = [np.zeros(int(0.02 * sr))]
    for dur, pause in WHISTLE_BLASTS:
        parts += [blast(dur, rng), np.zeros(int(pause * sr))]
    x = np.concatenate(parts + [np.zeros(int(0.45 * sr))])
    # Out of doors: the far bank answers once, faintly, a moment later.
    echo = int(0.19 * sr)
    x[echo:] += 0.11 * np.convolve(x, np.ones(9) / 9.0, mode="same")[:-echo]
    k = int(0.3 * sr)
    x[len(x) - k:] *= np.linspace(1.0, 0.0, k)
    rms = np.sqrt(np.mean(x[np.abs(x) > 1e-4] ** 2))
    x *= 10 ** (WHISTLE_RMS_DB / 20.0) / rms
    x *= min(1.0, CEILING / np.max(np.abs(x)))
    out = os.path.join(ROOT, "sfx/contest/whistle.ogg")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sf.write(out, x.astype(np.float32), sr, format="OGG", subtype="VORBIS")
    print("sfx/contest/whistle.ogg", "%.2fs" % (len(x) / sr))


def main():
    whistle()
    for rel, (sid, a, b, fi, fo, rms_db) in CUTS.items():
        # A cut that is there is left alone (nothing is fetched again); --force rebuilds.
        if os.path.exists(os.path.join(ROOT, rel)) and "--force" not in sys.argv:
            continue
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
